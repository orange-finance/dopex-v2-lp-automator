import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import '@nomicfoundation/hardhat-foundry'

import { vars } from 'hardhat/config'

const MAINNET_DEPLOYER = vars.get('MAINNET_DEPLOYER')
const ARB_URL = vars.get('ARB_URL')
const ETHERSCAN_API_KEY = vars.get('ETHERSCAN_API_KEY')

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
    arb: {
      url: ARB_URL,
      accounts: [MAINNET_DEPLOYER],
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
}

export default config
