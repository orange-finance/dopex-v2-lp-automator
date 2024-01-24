import { HardhatUserConfig, task } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import '@nomicfoundation/hardhat-foundry'

import { vars } from 'hardhat/config'
import './tasks/00.deploy-quoter'
import './tasks/01.deploy-automator'
import './tasks/02.deploy-strategy'
import './tasks/99.verify-deployment'

const MAINNET_DEPLOYER = vars.get('MAINNET_DEPLOYER')
const ARB_URL = vars.get('ARB_URL')
const ARBISCAN_API_KEY = vars.get('ARBISCAN_API_KEY')

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
    apiKey: ARBISCAN_API_KEY,
  },
}

export default config
