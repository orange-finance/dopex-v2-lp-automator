#!/usr/bin/env bash

set -e

network="arbitrum"

# npx hardhat deploy --network $network --tags base_arbitrum
# npx hardhat deploy --network $network --tags periphery
PAIR=Pancake-WETH-USDC npx hardhat deploy --network $network --tags v1_1-vault
PAIR=Pancake-WETH-USDC npx hardhat deploy --network $network --tags v2-vault
PAIR=Pancake-WETH-USDC npx hardhat deploy --network $network --tags v2_1-vault
PAIR=Pancake-USDC-ARB npx hardhat deploy --network $network --tags v1_1-vault
PAIR=Pancake-USDC-ARB npx hardhat deploy --network $network --tags v2-vault
PAIR=Pancake-USDC-ARB npx hardhat deploy --network $network --tags v2_1-vault
PAIR=Pancake-USDC-WBTC npx hardhat deploy --network $network --tags v1_1-vault
PAIR=Pancake-USDC-WBTC npx hardhat deploy --network $network --tags v2-vault
PAIR=Pancake-USDC-WBTC npx hardhat deploy --network $network --tags v2_1-vault

npx hardhat etherscan-verify --network $network
