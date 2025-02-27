#!/usr/bin/env bash

set -e

network="berachain_mainnet"

npx hardhat deploy --network $network --tags base-berachain_mainnet
npx hardhat deploy --network $network --tags periphery

PAIR=WETH-HONEY npx hardhat deploy --network $network --tags v1_1-vault
PAIR=WETH-HONEY npx hardhat deploy --network $network --tags v2-vault
PAIR=WETH-HONEY npx hardhat deploy --network $network --tags v2_1-vault

PAIR=HONEY-WBTC npx hardhat deploy --network $network --tags v1_1-vault
PAIR=HONEY-WBTC npx hardhat deploy --network $network --tags v2-vault
PAIR=HONEY-WBTC npx hardhat deploy --network $network --tags v2_1-vault

PAIR=WBERA-HONEY npx hardhat deploy --network $network --tags v1_1-vault
PAIR=WBERA-HONEY npx hardhat deploy --network $network --tags v2-vault
PAIR=WBERA-HONEY npx hardhat deploy --network $network --tags v2_1-vault

npx hardhat etherscan-verify --network $network
