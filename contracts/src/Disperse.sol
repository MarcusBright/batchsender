// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/**
 * @title Disperse
 * @author BatchSender
 * @notice A contract for batch transferring native tokens and ERC20 tokens to multiple recipients
 * @dev Supports both native token and ERC20 token batch transfers with security checks.
 *      This contract is stateless and holds no funds between transactions.
 *      For non-standard ERC20 tokens (e.g. USDT that does not return bool), use SafeERC20 wrapper externally.
 */
contract Disperse {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LengthMismatch();
    error EmptyRecipients();
    error ZeroAddress();
    error InsufficientValue();
    error TransferFailed();
    error RefundFailed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when native tokens are dispersed
    /// @param sender The address that initiated the disperse
    /// @param totalAmount The total amount of native tokens dispersed
    /// @param recipientCount The number of recipients
    event DisperseNative(
        address indexed sender,
        uint256 totalAmount,
        uint256 recipientCount
    );

    /// @notice Emitted when ERC20 tokens are dispersed
    /// @param token The ERC20 token address
    /// @param sender The address that initiated the disperse
    /// @param totalAmount The total amount of tokens dispersed
    /// @param recipientCount The number of recipients
    event DisperseToken(
        address indexed token,
        address indexed sender,
        uint256 totalAmount,
        uint256 recipientCount
    );

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Batch transfer native tokens to multiple recipients using low-level call
     * @dev Refunds excess native tokens back to the sender.
     *      Reentrancy note: this contract is stateless and does not store any balances,
     *      so reentrancy via malicious recipient has no impact on contract state.
     * @param recipients Array of recipient addresses (must not contain address(0))
     * @param values Array of native token amounts to send to each recipient
     */
    function disperseNative(
        address[] calldata recipients,
        uint256[] calldata values
    ) external payable {
        uint256 len = recipients.length;
        if (len != values.length) revert LengthMismatch();
        if (len == 0) revert EmptyRecipients();

        // Pre-calculate total to validate msg.value
        uint256 total = 0;
        for (uint256 i = 0; i < len; ) {
            total += values[i];
            unchecked { ++i; }
        }
        if (msg.value < total) revert InsufficientValue();

        // Distribute native tokens
        for (uint256 i = 0; i < len; ) {
            address recipient = recipients[i];
            if (recipient == address(0)) revert ZeroAddress();

            (bool success, ) = recipient.call{value: values[i]}("");
            if (!success) revert TransferFailed();

            unchecked { ++i; }
        }

        // Refund excess native tokens
        // Use msg.value - total instead of address(this).balance to prevent
        // reentrancy attack where inner calls drain funds via inflated refund
        uint256 refund = msg.value - total;
        if (refund > 0) {
            (bool success, ) = msg.sender.call{value: refund}("");
            if (!success) revert RefundFailed();
        }

        emit DisperseNative(msg.sender, total, len);
    }

    /**
     * @notice Batch transfer ERC20 tokens to multiple recipients
     * @dev This function first transfers all tokens to the contract, then distributes them.
     *      WARNING: Not compatible with fee-on-transfer tokens. Use disperseTokenSimple instead.
     *      WARNING: Not compatible with non-standard ERC20 tokens that do not return bool (e.g. USDT).
     * @param token The ERC20 token contract address
     * @param recipients Array of recipient addresses (must not contain address(0))
     * @param values Array of token amounts to send to each recipient
     */
    function disperseToken(
        IERC20 token,
        address[] calldata recipients,
        uint256[] calldata values
    ) external {
        uint256 len = recipients.length;
        if (len != values.length) revert LengthMismatch();
        if (len == 0) revert EmptyRecipients();

        uint256 total = 0;
        for (uint256 i = 0; i < len; ) {
            if (recipients[i] == address(0)) revert ZeroAddress();
            total += values[i];
            unchecked { ++i; }
        }

        // Transfer tokens to this contract first
        bool success = token.transferFrom(msg.sender, address(this), total);
        if (!success) revert TransferFailed();

        // Distribute tokens to recipients
        for (uint256 i = 0; i < len; ) {
            success = token.transfer(recipients[i], values[i]);
            if (!success) revert TransferFailed();
            unchecked { ++i; }
        }

        emit DisperseToken(address(token), msg.sender, total, len);
    }

    /**
     * @notice Batch transfer ERC20 tokens directly from sender to recipients
     * @dev This function transfers tokens directly from sender to each recipient.
     *      Recommended for fee-on-transfer tokens as it avoids intermediate holding.
     *      WARNING: Not compatible with non-standard ERC20 tokens that do not return bool (e.g. USDT).
     * @param token The ERC20 token contract address
     * @param recipients Array of recipient addresses (must not contain address(0))
     * @param values Array of token amounts to send to each recipient
     */
    function disperseTokenSimple(
        IERC20 token,
        address[] calldata recipients,
        uint256[] calldata values
    ) external {
        uint256 len = recipients.length;
        if (len != values.length) revert LengthMismatch();
        if (len == 0) revert EmptyRecipients();

        uint256 total = 0;
        for (uint256 i = 0; i < len; ) {
            address recipient = recipients[i];
            uint256 value = values[i];

            if (recipient == address(0)) revert ZeroAddress();

            bool success = token.transferFrom(msg.sender, recipient, value);
            if (!success) revert TransferFailed();

            total += value;

            unchecked { ++i; }
        }

        emit DisperseToken(address(token), msg.sender, total, len);
    }
}
