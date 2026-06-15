#!/bin/bash

# load env variables
source .env

deploy() {
	NETWORK=$1

	# get deployer address
	DEPLOYER_ADDRESS=$(cast wallet address "$PRIVATE_KEY")
	echo "Deployer address: $DEPLOYER_ADDRESS"

	# get RPC URL for the network
	RPC_KEY="RPC_URL_$(echo "$NETWORK" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
	RPC_URL="${!RPC_KEY}"

	if [[ -z "$RPC_URL" ]]; then
		echo "❌ Error: RPC URL not found for network: $NETWORK"
		echo "   Please set $RPC_KEY in your .env file"
		exit 1
	fi

	# get balance
	BALANCE=$(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$RPC_URL")
	echo "Balance: $(echo "scale=6;$BALANCE / 1000000000000000000" | bc) ETH"
	echo ""

	# deploy
	echo "Deploying to $NETWORK..."
	RAW_RETURN_DATA=$(forge script script/Deploy.s.sol --rpc-url "$RPC_URL" --broadcast --json 2>&1)
	RETURN_CODE=$?

	if [[ $RETURN_CODE -ne 0 ]]; then
		echo "❌ Error: deployment was not successful"
		echo "$RAW_RETURN_DATA"
		exit 1
	fi

	# extract factory address
	CLEAN_RETURN_DATA=$(echo "$RAW_RETURN_DATA" | grep -o '{.*}' | tail -1)
	FACTORY_ADDRESS=$(echo "$CLEAN_RETURN_DATA" | jq -r '.returns.factory.value // (.transactions[]? | select(.contractName == "CREATE3Factory") | .contractAddress) // empty' 2>/dev/null)

	if [[ -z "$FACTORY_ADDRESS" || "$FACTORY_ADDRESS" == "null" ]]; then
		echo "⚠️  Could not parse factory address from output"
		echo "Please check the broadcast folder for the deployed address"
	else
		echo "✅ Successfully deployed to address: $FACTORY_ADDRESS"

		# save to deployments
		saveContract "$NETWORK" "CREATE3Factory" "$FACTORY_ADDRESS"
	fi

	echo ""
	echo "To verify the contract, run:"
	case "$NETWORK" in
	kaia)
		echo "  forge verify-contract $FACTORY_ADDRESS src/CREATE3Factory.sol:CREATE3Factory --rpc-url \$RPC_URL_KAIA --verifier-url https://compiler-api-v2.kaiascan.io/mainnet/forge-verify --chain-id 8217 --retries 1"
		;;
	kairos)
		echo "  forge verify-contract $FACTORY_ADDRESS src/CREATE3Factory.sol:CREATE3Factory --rpc-url \$RPC_URL_KAIROS --verifier-url https://compiler-api-v2.kaiascan.io/kairos/forge-verify --chain-id 1001 --retries 1"
		;;
	*)
		echo "  forge verify-contract $FACTORY_ADDRESS src/CREATE3Factory.sol:CREATE3Factory --rpc-url \$RPC_URL_$(echo "$NETWORK" | tr '[:lower:]' '[:upper:]' | tr '-' '_') --etherscan-api-key <API_KEY> --watch"
		;;
	esac
}

saveContract() {
	NETWORK=$1
	CONTRACT=$2
	ADDRESS=$3

	ADDRESSES_FILE=./deployments/$NETWORK.json

	# create an empty json if it does not exist
	if [[ ! -e $ADDRESSES_FILE ]]; then
		echo "{}" >"$ADDRESSES_FILE"
	fi
	result=$(cat "$ADDRESSES_FILE" | jq -r ". + {\"$CONTRACT\": \"$ADDRESS\"}")
	printf %s "$result" >"$ADDRESSES_FILE"
	echo "📝 Saved to $ADDRESSES_FILE"
}

# check if network argument is provided
if [[ -z "$1" ]]; then
	echo "Usage: ./deploy/deploy.sh <network>"
	echo ""
	echo "Available networks:"
	echo "  Mainnet: mainnet, arbitrum, base, polygon, bsc, scroll, kaia"
	echo "  Testnet: sepolia, arbitrum-sepolia, base-sepolia, polygon-amoy, bsc-testnet, scroll-sepolia, kairos"
	exit 1
fi

deploy "$1"
