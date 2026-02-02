# AGENTS.md

This file provides context for AI coding agents working on this project.

## Project Overview

This is a CREATE3 Factory contract that enables deterministic contract deployment across multiple EVM chains. Contracts deployed via this factory will have the same address on all supported chains, regardless of constructor arguments.

## Key Concepts

### CREATE3 vs CREATE2 vs CREATE

| Method | Address Depends On | Use Case |
|--------|-------------------|----------|
| CREATE | deployer address + nonce | Standard deployment |
| CREATE2 | deployer + salt + bytecode hash | Deterministic, but bytecode-dependent |
| CREATE3 | factory + salt + caller | Deterministic, bytecode-independent |

### How This Factory is Deployed

This factory uses **CREATE2** (not CREATE) for deployment to ensure the same factory address across all chains without nonce synchronization:

```solidity
// Deploy.s.sol
bytes32 salt = keccak256("intmax");
factory = new CREATE3Factory{salt: salt}();
```

The factory address is determined by:
- Deployer address (from PRIVATE_KEY)
- Salt ("intmax")
- Factory bytecode

### Bytecode Determinism

To ensure identical bytecode across different compilation environments:

```toml
# foundry.toml
bytecode_hash = "none"
cbor_metadata = false
```

These settings disable compiler metadata embedding.

## Project Structure

```
create3-factory/
├── src/
│   ├── CREATE3Factory.sol      # Main factory contract
│   ├── ICREATE3Factory.sol     # Interface
│   └── CREATE3Factory.flattened # Flattened for verification
├── script/
│   └── Deploy.s.sol            # Foundry deployment script
├── deploy/
│   └── deploy.sh               # Shell script wrapper
├── deployments/                # Deployment records (JSON)
├── lib/                        # Git submodules (solmate, forge-std)
├── foundry.toml                # Foundry configuration
└── .env.example                # Environment variables template
```

## Supported Chains

| Mainnet | Testnet |
|---------|---------|
| Ethereum | Sepolia |
| Arbitrum | Arbitrum Sepolia |
| Base | Base Sepolia |
| BSC | BSC Testnet |
| Scroll | Scroll Sepolia |

## Development Workflow

### Setup

```bash
# Install dependencies
forge install

# Copy and configure environment
cp .env.example .env
# Edit .env with your values
```

### Build

```bash
forge build
```

### Deploy

```bash
# Deploy to a specific network
./deploy/deploy.sh <network>

# Example
./deploy/deploy.sh sepolia
```

## Important Technical Details

### Factory Address Calculation

The CREATE3Factory address is calculated as:
```
address = keccak256(0xff ++ deployer ++ salt ++ keccak256(bytecode))[12:]
```

### User Contract Address Calculation

When users call `factory.deploy(salt, creationCode)`:
```
finalSalt = keccak256(msg.sender ++ userSalt)
address = f(factoryAddress, finalSalt)  // Independent of creationCode
```

### Security Notes

- The salt in Deploy.s.sol ("intmax") does not need to be secret
- Security relies on the deployer's private key, not the salt
- Each caller (msg.sender) has their own address namespace

## Environment Variables

Required in `.env`:

```bash
PRIVATE_KEY=           # Deployer private key

# RPC URLs
RPC_URL_MAINNET=
RPC_URL_ARBITRUM=
RPC_URL_BASE=
RPC_URL_BSC=
RPC_URL_SCROLL=
RPC_URL_SEPOLIA=
RPC_URL_ARBITRUM_SEPOLIA=
RPC_URL_BASE_SEPOLIA=
RPC_URL_BSC_TESTNET=
RPC_URL_SCROLL_SEPOLIA=

# Etherscan API Keys (for verification)
ETHERSCAN_KEY=
ARBISCAN_KEY=
BASESCAN_API_KEY=
BSCSCAN_KEY=
SCROLLSCAN_API_KEY=
```

## Solidity Version

This project uses Solidity 0.8.33 with strict version pinning for bytecode determinism.
