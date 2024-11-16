#!/bin/bash

# Load environment variables
source .env

# Check if environment variables are set
if [ -z "$PRIVATE_KEY" ] || [ -z "$BASE_SEPOLIA_RPC_URL" ] || [ -z "$BASE_SEPOLIA_TOKEN_ADDRESS" ]; then
    echo "Error: Required environment variables are not set"
    echo "Please ensure PRIVATE_KEY, BASE_SEPOLIA_RPC_URL and BASE_SEPOLIA_TOKEN_ADDRESS are set in .env file"
    exit 1
fi

# Build the contracts
forge build


#deployement on base sepolia
# Deploy the contract using Forge create
DEPLOYED_ADDRESS=$(forge create --rpc-url $BASE_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    src/Deposit.sol:NanoChai \
    --constructor-args $BASE_SEPOLIA_TOKEN_ADDRESS | grep "Deployed to" | awk '{print $3}')

# Verify the contract separately
forge verify-contract $DEPLOYED_ADDRESS src/Deposit.sol:NanoChai \
    --chain 84532 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" $BASE_SEPOLIA_TOKEN_ADDRESS)

echo "Contract deployed to: $DEPLOYED_ADDRESS and verified on Base Sepolia" !

#deployement on morphl2
DEPLOYED_ADDRESS_MORPHL2=$(forge create --rpc-url $MORPH_RPC_URL \
    --private-key $PRIVATE_KEY \
    src/Deposit.sol:NanoChai \
    --constructor-args $MORPH_TOKEN_ADDRESS | grep "Deployed to" | awk '{print $3}') 


# echo "Contract deployed to: $DEPLOYED_ADDRESS_MORPHL2 on Morphl2" !

#deployement on scroll sepolia
DEPLOYED_ADDRESS_SCROLL=$(forge create --rpc-url $SCROLL_RPC_URL \
    --private-key $PRIVATE_KEY \
    src/Deposit.sol:NanoChai \
    --constructor-args $SCROLL_TOKEN_ADDRESS | grep "Deployed to" | awk '{print $3}') 

echo "Contract deployed to: $DEPLOYED_ADDRESS_SCROLL on Scroll Sepolia" !


#deployement on polygon amoy
DEPLOYED_ADDRESS_POLYGON=$(forge create --rpc-url $POLYGON_RPC_URL \
    --private-key $PRIVATE_KEY \
    src/Deposit.sol:NanoChai \
    --constructor-args $POLYGON_TOKEN_ADDRESS | grep "Deployed to" | awk '{print $3}') 

echo "Contract deployed to: $DEPLOYED_ADDRESS_POLYGON on Polygon Amoy" !

#deployement on kinto
DEPLOYED_ADDRESS_KINTO=$(forge create --rpc-url $KINTO_RPC_URL \
    --private-key $PRIVATE_KEY \
    src/Deposit.sol:NanoChai \
    --constructor-args $KINTO_TOKEN_ADDRESS | grep "Deployed to" | awk '{print $3}') 

echo "Contract deployed to: $DEPLOYED_ADDRESS_KINTO on Kinto" !

#deployement on mantle
DEPLOYED_ADDRESS_MANTLE=$(forge create --rpc-url $MANTLE_RPC_URL \
    --private-key $PRIVATE_KEY \
    src/Deposit.sol:NanoChai \
    --constructor-args $MANTLE_TOKEN_ADDRESS | grep "Deployed to" | awk '{print $3}') 

echo "Contract deployed to: $DEPLOYED_ADDRESS_MANTLE on Mantle" !

#deployement on arbitrum sepolia
DEPLOYED_ADDRESS_ARBITRUM=$(forge create --rpc-url $ARBITRUM_RPC_URL \
    --private-key $PRIVATE_KEY \
    src/Deposit.sol:NanoChai \
    --constructor-args $ARBITRUM_TOKEN_ADDRESS | grep "Deployed to" | awk '{print $3}') 

echo "Contract deployed to: $DEPLOYED_ADDRESS_ARBITRUM on Arbitrum Sepolia" !

