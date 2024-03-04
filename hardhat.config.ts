import { HardhatUserConfig, vars } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import '@nomicfoundation/hardhat-foundry'

const MAINNET_DEPLOYER = vars.get('ORANGE_MAINNET_DEPLOYER')
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
