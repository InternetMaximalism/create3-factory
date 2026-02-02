# CREATE3 Factory

Factory contract for easily deploying contracts to the same address on multiple chains, using CREATE3.

This was forked from https://github.com/lifinance/create3-factory (originally from https://github.com/ZeframLou/create3-factory)

## Why?

Deploying a contract to multiple chains with the same address is annoying. One usually would create a new Ethereum account, seed it with enough tokens to pay for gas on every chain, and then deploy the contract naively. This relies on the fact that the new account's nonce is synced on all the chains, therefore resulting in the same contract address.
However, deployment is often a complex process that involves several transactions (e.g. for initialization), which means it's easy for nonces to fall out of sync and make it forever impossible to deploy the contract at the desired address.

One could use a `CREATE2` factory that deterministically deploys contracts to an address that's unrelated to the deployer's nonce, but the address is still related to the hash of the contract's creation code. This means if you wanted to use different constructor parameters on different chains, the deployed contracts will have different addresses.

A `CREATE3` factory offers the best solution: the address of the deployed contract is determined by only the deployer address and the salt. This makes it far easier to deploy contracts to multiple chains at the same addresses.

## How This Factory is Deployed

This factory uses **CREATE2** for deployment to ensure the same factory address across all chains without nonce synchronization:

```solidity
bytes32 salt = keccak256("intmax");
factory = new CREATE3Factory{salt: salt}();
```

The factory address is determined by:
- Deployer address (from PRIVATE_KEY)
- Salt ("intmax")
- Factory bytecode (deterministic via `bytecode_hash = "none"` in foundry.toml)

**Nonce does not affect the address**, so you can deploy to new chains at any time.

## Supported Chains

| Mainnet | Testnet |
|---------|---------|
| Ethereum | Sepolia |
| Arbitrum | Arbitrum Sepolia |
| Base | Base Sepolia |
| BSC | BSC Testnet |
| Scroll | Scroll Sepolia |

## Deployments

For a list of all deployments and their respective addresses of the `CREATE3Factory` please check folder `deployments/`

## Usage

Call `CREATE3Factory::deploy()` to deploy a contract and `CREATE3Factory::getDeployed()` to predict the deployment address, it's as simple as it gets.

A few notes:

- The salt provided is hashed together with the deployer address (i.e. msg.sender) to form the final salt, such that each deployer has its own namespace of deployed addresses.
- The deployed contract should be aware that `msg.sender` in the constructor will be the temporary proxy contract used by `CREATE3` rather than the deployer, so common patterns like `Ownable` should be modified to accomodate for this.

## Installation

To install with [Foundry](https://github.com/foundry-rs/foundry):

```
forge install InternetMaximalism/create3-factory
```

## Local development

This project uses [Foundry](https://github.com/foundry-rs/foundry) as the development framework.

### Dependencies

```bash
forge install
```

### Compilation

```bash
forge build
```

### Deployment

1. Copy `.env.example` to `.env` and fill in the values:

```bash
cp .env.example .env
```

2. Set up your environment variables:

```bash
PRIVATE_KEY=<your-deployer-private-key>
RPC_URL_SEPOLIA=<rpc-url>
ETHERSCAN_KEY=<api-key>
# ... other networks as needed
```

3. Deploy using the shell script:

```bash
./deploy/deploy.sh <network>

# Examples:
./deploy/deploy.sh sepolia
./deploy/deploy.sh arbitrum-sepolia
./deploy/deploy.sh base-sepolia
```

4. Or deploy directly with forge:

```bash
source .env
forge script script/Deploy.s.sol --rpc-url $RPC_URL_SEPOLIA --broadcast -vvv
```

### Verification

After deployment, verify the contract:

```bash
forge verify-contract <DEPLOYED_ADDRESS> src/CREATE3Factory.sol:CREATE3Factory \
  --rpc-url $RPC_URL_SEPOLIA \
  --etherscan-api-key $ETHERSCAN_KEY \
  --watch
```
