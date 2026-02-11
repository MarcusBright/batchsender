# Disperse Contract

A Solidity smart contract for batch transferring ETH and ERC20 tokens to multiple recipients in a single transaction.

## Features

- **disperseEther**: Batch transfer native ETH to multiple recipients
- **disperseToken**: Batch transfer ERC20 tokens (transfers to contract first, then distributes)
- **disperseTokenSimple**: Batch transfer ERC20 tokens directly from sender to recipients

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

## Installation

1. Clone the repository and navigate to the contracts directory:

```bash
cd contracts
```

2. Install dependencies using git submodules:

```bash
git submodule update --init --recursive
```

Or add forge-std manually:

```bash
forge install foundry-rs/forge-std@v1.5.0 --no-commit
```

## Build

```bash
forge build
```

## Test

```bash
forge test
```

Run tests with verbosity:

```bash
forge test -vvvv
```

## Deploy

1. Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
```

2. Source the environment variables:

```bash
source .env
```

3. Deploy to a network:

```bash
# Deploy to Sepolia testnet
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Deploy to mainnet
forge script script/Deploy.s.sol:DeployScript --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

## Usage

### Disperse ETH

```solidity
address[] memory recipients = new address[](3);
recipients[0] = 0x...;
recipients[1] = 0x...;
recipients[2] = 0x...;

uint256[] memory values = new uint256[](3);
values[0] = 1 ether;
values[1] = 2 ether;
values[2] = 3 ether;

disperse.disperseEther{value: 6 ether}(recipients, values);
```

### Disperse ERC20 Tokens

```solidity
// First approve the Disperse contract
token.approve(address(disperse), totalAmount);

// Then disperse
disperse.disperseToken(token, recipients, values);
// or
disperse.disperseTokenSimple(token, recipients, values);
```

## Contract Addresses

| Network | Address |
|---------|---------|
| Mainnet | TBD |
| Sepolia | TBD |

## License

MIT
