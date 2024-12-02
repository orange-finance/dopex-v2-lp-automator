#!/usr/bin/env bash

set -e

network="berachain_bartio"

# npx hardhat deploy --network $network --tags base-berachain_bartio
# npx hardhat deploy --network $network --tags periphery
PAIR=HONEY-USDC npx hardhat deploy --network $network --tags v1_1-vault
PAIR=HONEY-USDC npx hardhat deploy --network $network --tags v2-vault
PAIR=HONEY-USDC npx hardhat deploy --network $network --tags v2_1-vault

npx hardhat etherscan-verify --network $network
