# Include .env file if exists
-include .env

.PHONY: all build clean test install deploy-sepolia deploy-mainnet flatten

all: clean install build test

# Install dependencies
install:
	git submodule update --init --recursive

# Install forge-std if submodule not initialized
install-forge-std:
	forge install foundry-rs/forge-std@v1.5.0 --no-commit

# Build the project
build:
	forge build

# Clean build artifacts
clean:
	forge clean

# Run tests
test:
	forge test

# Run tests with verbosity
test-v:
	forge test -vvvv

# Run tests with gas report
test-gas:
	forge test --gas-report

# Format code
format:
	forge fmt

# Generate gas snapshot
snapshot:
	forge snapshot

# Deploy to Sepolia
deploy-sepolia:
	forge script -vvvv \
		--account $(DEPLOYER) \
		--sender $(DEPLOYER_ADDRESS) \
		-f $(SEPOLIA_RPC_URL) \
		--broadcast \
		--verify \
		script/Deploy.s.sol:DeployDisperse

# Deploy to Mainnet
deploy-mainnet:
	forge script -vvvv \
		--account $(DEPLOYER) \
		--sender $(DEPLOYER_ADDRESS) \
		-f $(MAINNET_RPC_URL) \
		--broadcast \
		--verify \
		script/Deploy.s.sol:DeployDisperse

# Verify contract
verify:
	forge verify-contract $(CONTRACT_ADDRESS) src/Disperse.sol:Disperse --chain-id $(CHAIN_ID) --etherscan-api-key $(ETHERSCAN_API_KEY)

# Flatten contracts for verification
flatten:
	@mkdir -p flattened
	forge flatten src/Disperse.sol > flattened/Disperse.flattened.sol
	@echo "Flattened contract saved to flattened/Disperse.flattened.sol"

# ============== CREATE2 Deployment (Same address across all chains) ==============

# Preview CREATE2 deployment address (no transaction)
preview-create2:
	forge script script/DeployCreate2.s.sol:DeployCreate2 --sig "preview()" -f $(RPC_URL)

# Deploy to any chain using CREATE2 (deterministic address)
# Usage: make deploy-create2 RPC_URL=<rpc_url>
deploy-create2:
	forge script -vvvv \
		--account $(DEPLOYER) \
		--sender $(DEPLOYER_ADDRESS) \
		-f $(RPC_URL) \
		--broadcast \
		script/DeployCreate2.s.sol:DeployCreate2

# Deploy to Sepolia using CREATE2
deploy-create2-sepolia:
	forge script -vvvv \
		--account $(DEPLOYER) \
		--sender $(DEPLOYER_ADDRESS) \
		-f $(SEPOLIA_RPC_URL) \
		--broadcast \
		script/DeployCreate2.s.sol:DeployCreate2

# Deploy to Mainnet using CREATE2
deploy-create2-mainnet:
	forge script -vvvv \
		--account $(DEPLOYER) \
		--sender $(DEPLOYER_ADDRESS) \
		-f $(MAINNET_RPC_URL) \
		--broadcast \
		script/DeployCreate2.s.sol:DeployCreate2

# Deploy to BSC using CREATE2
deploy-create2-bsc:
	forge script -vvvv \
		--account $(DEPLOYER) \
		--sender $(DEPLOYER_ADDRESS) \
		-f $(BSC_RPC_URL) \
		--broadcast \
		script/DeployCreate2.s.sol:DeployCreate2

# Deploy to Polygon using CREATE2
deploy-create2-polygon:
	forge script -vvvv \
		--account $(DEPLOYER) \
		--sender $(DEPLOYER_ADDRESS) \
		-f $(POLYGON_RPC_URL) \
		--broadcast \
		script/DeployCreate2.s.sol:DeployCreate2

# Deploy to Arbitrum using CREATE2
deploy-create2-arbitrum:
	forge script -vvvv \
		--account $(DEPLOYER) \
		--sender $(DEPLOYER_ADDRESS) \
		-f $(ARBITRUM_RPC_URL) \
		--broadcast \
		script/DeployCreate2.s.sol:DeployCreate2

# Deploy to Optimism using CREATE2
deploy-create2-optimism:
	forge script -vvvv \
		--account $(DEPLOYER) \
		--sender $(DEPLOYER_ADDRESS) \
		-f $(OPTIMISM_RPC_URL) \
		--broadcast \
		script/DeployCreate2.s.sol:DeployCreate2
