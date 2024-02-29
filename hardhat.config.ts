import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox-viem'
import '@nomicfoundation/hardhat-foundry'
import * as tenderly from '@tenderly/hardhat-tenderly'
import dotenv from 'dotenv'

dotenv.config()
tenderly.setup()

const {
  TENDERLY_ACCESS_KEY,
  TENDERLY_PROJECT,
  TENDERLY_USERNAME,
  DEVNET_RPC_URL,
  DEV_ACCOUNT,
} = process.env

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.19',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    devnet: {
      url: DEVNET_RPC_URL,
      chainId: 42161,
      accounts: [DEV_ACCOUNT || ''],
    },
  },
  tenderly: {
    project: TENDERLY_PROJECT || '',
    username: TENDERLY_USERNAME || '',
    accessKey: TENDERLY_ACCESS_KEY,
  },
}

export default config
