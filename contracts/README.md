# Disperse Contract

A Solidity smart contract for batch transferring ETH and ERC20 tokens to multiple recipients in a single transaction.

## Features

- **disperseNative**: Batch transfer native ETH to multiple recipients
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
forge script script/Deploy.s.sol:DeployDisperse --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Deploy to mainnet
forge script script/Deploy.s.sol:DeployDisperse --rpc-url $MAINNET_RPC_URL --broadcast --verify
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

disperse.disperseNative{value: 6 ether}(recipients, values);
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

## CREATE2 Deployment (Multi-chain Same Address)

To deploy the contract with the **same address on all EVM chains**, use CREATE2 deployment:

### How it works

CREATE2 address is determined by: `deployer_address + salt + bytecode`

- **Deployer**: Arachnid's Deterministic Deployment Proxy (`0x4e59b44847b379578588920cA78FbF26c0B4956C`)
- **Salt**: `keccak256("rockx.disperse.v1")` (configurable in `script/DeployCreate2.s.sol`)
- **Bytecode**: Must use identical compiler version and settings

### Prerequisites

1. The deterministic deployer must exist on the target chain (pre-deployed on most EVM chains)
2. Same `foundry.toml` compiler settings across deployments
3. Same salt value

### Preview Address

```bash
# Preview the CREATE2 address without deploying
make preview-create2 RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
```

### Deploy to Multiple Chains

```bash
# Configure .env with RPC URLs for each chain
source .env

# Deploy to Sepolia
make deploy-create2-sepolia

# Deploy to Mainnet  
make deploy-create2-mainnet

# Deploy to BSC
make deploy-create2-bsc

# Deploy to Polygon
make deploy-create2-polygon

# Deploy to Arbitrum
make deploy-create2-arbitrum

# Deploy to Optimism
make deploy-create2-optimism

# Or deploy to any chain with custom RPC
make deploy-create2 RPC_URL=<your_rpc_url>
```

### Verify Same Address

After deploying to multiple chains, verify the contract is at the same address:

```bash
# Check bytecode on each chain
cast code <DEPLOYED_ADDRESS> --rpc-url <RPC_URL_1>
cast code <DEPLOYED_ADDRESS> --rpc-url <RPC_URL_2>
```

## License

MIT
