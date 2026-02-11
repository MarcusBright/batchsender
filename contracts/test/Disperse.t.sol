// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Disperse.sol";
import "../src/mocks/MockERC20.sol";

/// @dev Malicious contract that attempts reentrancy on disperseNative
contract ReentrantReceiver {
    Disperse public target;
    uint256 public attackCount;
    bool public reentered;

    constructor(Disperse _target) {
        target = _target;
    }

    receive() external payable {
        // Attempt reentrancy only once to avoid infinite loop
        if (attackCount == 0) {
            attackCount++;
            address[] memory recipients = new address[](1);
            recipients[0] = address(this);
            uint256[] memory values = new uint256[](1);
            values[0] = 0.1 ether;
            // Reentrancy attempt: even if this succeeds, Disperse has no state to corrupt
            try target.disperseNative{value: 0.1 ether}(recipients, values) {
                reentered = true;
            } catch {
                reentered = false;
            }
        }
    }
}

/// @dev Contract that rejects ETH transfers
contract RejectingReceiver {
    // No receive() or fallback(), will reject ETH
}

contract DisperseTest is Test {
    Disperse public disperse;
    MockERC20 public token;

    address public alice;
    address public bob;
    address public charlie;

    // Events from Disperse contract
    event DisperseNative(
        address indexed sender,
        uint256 totalAmount,
        uint256 recipientCount
    );
    event DisperseToken(
        address indexed token,
        address indexed sender,
        uint256 totalAmount,
        uint256 recipientCount
    );

    function setUp() public {
        disperse = new Disperse();
        token = new MockERC20("Test Token", "TEST", 1000000 ether);

        // Create test addresses with labels for better debugging
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
    }

    /*//////////////////////////////////////////////////////////////
                        DISPERSE NATIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function testDisperseNative() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory values = new uint256[](3);
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;

        uint256 totalValue = 6 ether;

        vm.expectEmit(true, false, false, true);
        emit DisperseNative(address(this), totalValue, 3);

        disperse.disperseNative{value: totalValue}(recipients, values);

        assertEq(alice.balance, 1 ether, "Alice balance incorrect");
        assertEq(bob.balance, 2 ether, "Bob balance incorrect");
        assertEq(charlie.balance, 3 ether, "Charlie balance incorrect");
    }

    function testDisperseNativeWithExcess() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;

        uint256 senderBalanceBefore = address(this).balance;
        disperse.disperseNative{value: 5 ether}(recipients, values);

        assertEq(alice.balance, 1 ether, "Alice balance incorrect");
        assertEq(bob.balance, 2 ether, "Bob balance incorrect");
        assertEq(address(this).balance, senderBalanceBefore - 3 ether, "Excess not refunded correctly");
    }

    function testDisperseNativeSingleRecipient() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory values = new uint256[](1);
        values[0] = 5 ether;

        disperse.disperseNative{value: 5 ether}(recipients, values);

        assertEq(alice.balance, 5 ether, "Alice balance incorrect");
    }

    function testDisperseNativeDuplicateRecipients() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = alice;
        recipients[2] = bob;

        uint256[] memory values = new uint256[](3);
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;

        disperse.disperseNative{value: 6 ether}(recipients, values);

        assertEq(alice.balance, 3 ether, "Alice should receive sum of both transfers");
        assertEq(bob.balance, 3 ether, "Bob balance incorrect");
    }

    function testRevertDisperseNativeEmptyArrays() public {
        address[] memory recipients = new address[](0);
        uint256[] memory values = new uint256[](0);

        vm.expectRevert(Disperse.EmptyRecipients.selector);
        disperse.disperseNative{value: 1 ether}(recipients, values);
    }

    function testRevertDisperseNativeLengthMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory values = new uint256[](3);
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;

        vm.expectRevert(Disperse.LengthMismatch.selector);
        disperse.disperseNative{value: 6 ether}(recipients, values);
    }

    function testRevertDisperseNativeZeroAddress() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = address(0);

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;

        vm.expectRevert(Disperse.ZeroAddress.selector);
        disperse.disperseNative{value: 3 ether}(recipients, values);
    }

    function testRevertDisperseNativeInsufficientValue() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;

        // msg.value (1 ether) < total (3 ether)
        vm.expectRevert(Disperse.InsufficientValue.selector);
        disperse.disperseNative{value: 1 ether}(recipients, values);
    }

    function testRevertDisperseNativeZeroValue() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        // msg.value = 0
        vm.expectRevert(Disperse.InsufficientValue.selector);
        disperse.disperseNative{value: 0}(recipients, values);
    }

    function testRevertDisperseNativeRecipientRejects() public {
        RejectingReceiver rejector = new RejectingReceiver();

        address[] memory recipients = new address[](1);
        recipients[0] = address(rejector);

        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        vm.expectRevert(Disperse.TransferFailed.selector);
        disperse.disperseNative{value: 1 ether}(recipients, values);
    }

    function testDisperseNativeReentrantRecipient() public {
        ReentrantReceiver reentrant = new ReentrantReceiver(disperse);
        vm.deal(address(reentrant), 1 ether);

        address[] memory recipients = new address[](2);
        recipients[0] = address(reentrant);
        recipients[1] = alice;

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;

        uint256 aliceBefore = alice.balance;

        // Should succeed even with reentrant receiver (contract uses msg.value - total for refund)
        disperse.disperseNative{value: 3 ether}(recipients, values);

        assertEq(alice.balance - aliceBefore, 2 ether, "Alice balance incorrect after reentrant call");
        // ReentrantReceiver attempted reentrancy and it succeeded (stateless contract)
        assertTrue(reentrant.reentered(), "Reentrancy should have succeeded");
        assertEq(reentrant.attackCount(), 1, "Attack count should be 1");
    }

    function testDisperseNativeLargeBatch() public {
        uint256 count = 100;
        address[] memory recipients = new address[](count);
        uint256[] memory values = new uint256[](count);

        uint256 total = 0;
        for (uint256 i = 0; i < count; i++) {
            recipients[i] = address(uint160(i + 1000));
            values[i] = 0.01 ether;
            total += 0.01 ether;
        }

        disperse.disperseNative{value: total}(recipients, values);

        for (uint256 i = 0; i < count; i++) {
            assertEq(recipients[i].balance, 0.01 ether);
        }
    }

    function testFuzz_DisperseNative(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 1 wei, 100 ether);
        amount2 = bound(amount2, 1 wei, 100 ether);

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory values = new uint256[](2);
        values[0] = amount1;
        values[1] = amount2;

        uint256 total = amount1 + amount2;
        vm.deal(address(this), total);

        disperse.disperseNative{value: total}(recipients, values);

        assertEq(alice.balance, amount1);
        assertEq(bob.balance, amount2);
    }

    /*//////////////////////////////////////////////////////////////
                        DISPERSE TOKEN TESTS
    //////////////////////////////////////////////////////////////*/

    function testDisperseToken() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory values = new uint256[](3);
        values[0] = 100 ether;
        values[1] = 200 ether;
        values[2] = 300 ether;

        uint256 total = 600 ether;
        token.approve(address(disperse), total);

        vm.expectEmit(true, true, false, true);
        emit DisperseToken(address(token), address(this), total, 3);

        disperse.disperseToken(IERC20(address(token)), recipients, values);

        assertEq(token.balanceOf(alice), 100 ether, "Alice token balance incorrect");
        assertEq(token.balanceOf(bob), 200 ether, "Bob token balance incorrect");
        assertEq(token.balanceOf(charlie), 300 ether, "Charlie token balance incorrect");
        assertEq(token.balanceOf(address(disperse)), 0, "Contract should not hold tokens");
    }

    function testDisperseTokenSimple() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory values = new uint256[](3);
        values[0] = 100 ether;
        values[1] = 200 ether;
        values[2] = 300 ether;

        uint256 total = 600 ether;
        token.approve(address(disperse), total);

        disperse.disperseTokenSimple(IERC20(address(token)), recipients, values);

        assertEq(token.balanceOf(alice), 100 ether, "Alice token balance incorrect");
        assertEq(token.balanceOf(bob), 200 ether, "Bob token balance incorrect");
        assertEq(token.balanceOf(charlie), 300 ether, "Charlie token balance incorrect");
    }

    function testDisperseTokenSingleRecipient() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory values = new uint256[](1);
        values[0] = 500 ether;

        token.approve(address(disperse), 500 ether);
        disperse.disperseToken(IERC20(address(token)), recipients, values);

        assertEq(token.balanceOf(alice), 500 ether, "Alice token balance incorrect");
    }

    function testDisperseTokenDuplicateRecipients() public {
        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = alice;
        recipients[2] = bob;

        uint256[] memory values = new uint256[](3);
        values[0] = 100 ether;
        values[1] = 200 ether;
        values[2] = 300 ether;

        token.approve(address(disperse), 600 ether);
        disperse.disperseToken(IERC20(address(token)), recipients, values);

        assertEq(token.balanceOf(alice), 300 ether, "Alice should receive sum of both transfers");
        assertEq(token.balanceOf(bob), 300 ether, "Bob token balance incorrect");
    }

    function testDisperseTokenLargeBatch() public {
        uint256 count = 100;
        address[] memory recipients = new address[](count);
        uint256[] memory values = new uint256[](count);

        uint256 total = 0;
        for (uint256 i = 0; i < count; i++) {
            recipients[i] = address(uint160(i + 1000));
            values[i] = 1 ether;
            total += 1 ether;
        }

        token.approve(address(disperse), total);
        disperse.disperseToken(IERC20(address(token)), recipients, values);

        for (uint256 i = 0; i < count; i++) {
            assertEq(token.balanceOf(recipients[i]), 1 ether);
        }
        assertEq(token.balanceOf(address(disperse)), 0, "Contract should not hold tokens");
    }

    function testRevertDisperseTokenEmptyArrays() public {
        address[] memory recipients = new address[](0);
        uint256[] memory values = new uint256[](0);

        vm.expectRevert(Disperse.EmptyRecipients.selector);
        disperse.disperseToken(IERC20(address(token)), recipients, values);
    }

    function testRevertDisperseTokenSimpleEmptyArrays() public {
        address[] memory recipients = new address[](0);
        uint256[] memory values = new uint256[](0);

        vm.expectRevert(Disperse.EmptyRecipients.selector);
        disperse.disperseTokenSimple(IERC20(address(token)), recipients, values);
    }

    function testRevertDisperseTokenLengthMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory values = new uint256[](3);
        values[0] = 100 ether;
        values[1] = 200 ether;
        values[2] = 300 ether;

        token.approve(address(disperse), 600 ether);

        vm.expectRevert(Disperse.LengthMismatch.selector);
        disperse.disperseToken(IERC20(address(token)), recipients, values);
    }

    function testRevertDisperseTokenZeroAddress() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = address(0);

        uint256[] memory values = new uint256[](2);
        values[0] = 100 ether;
        values[1] = 200 ether;

        token.approve(address(disperse), 300 ether);

        vm.expectRevert(Disperse.ZeroAddress.selector);
        disperse.disperseToken(IERC20(address(token)), recipients, values);
    }

    function testRevertDisperseTokenSimpleZeroAddress() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = address(0);

        uint256[] memory values = new uint256[](2);
        values[0] = 100 ether;
        values[1] = 200 ether;

        token.approve(address(disperse), 300 ether);

        vm.expectRevert(Disperse.ZeroAddress.selector);
        disperse.disperseTokenSimple(IERC20(address(token)), recipients, values);
    }

    function testRevertDisperseTokenWithoutApproval() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory values = new uint256[](1);
        values[0] = 100 ether;

        vm.expectRevert();
        disperse.disperseToken(IERC20(address(token)), recipients, values);
    }

    function testRevertDisperseTokenSimpleWithoutApproval() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory values = new uint256[](1);
        values[0] = 100 ether;

        vm.expectRevert();
        disperse.disperseTokenSimple(IERC20(address(token)), recipients, values);
    }

    function testRevertDisperseTokenInsufficientBalance() public {
        address[] memory recipients = new address[](1);
        recipients[0] = alice;

        uint256[] memory values = new uint256[](1);
        values[0] = 2000000 ether; // More than initial supply

        token.approve(address(disperse), type(uint256).max);

        vm.expectRevert();
        disperse.disperseToken(IERC20(address(token)), recipients, values);
    }

    function testFuzz_DisperseToken(uint256 amount1, uint256 amount2) public {
        amount1 = bound(amount1, 1 wei, 400000 ether);
        amount2 = bound(amount2, 1 wei, 400000 ether);

        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        uint256[] memory values = new uint256[](2);
        values[0] = amount1;
        values[1] = amount2;

        uint256 total = amount1 + amount2;
        token.approve(address(disperse), total);

        disperse.disperseToken(IERC20(address(token)), recipients, values);

        assertEq(token.balanceOf(alice), amount1);
        assertEq(token.balanceOf(bob), amount2);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Required to receive native token refunds
    receive() external payable {}
}
