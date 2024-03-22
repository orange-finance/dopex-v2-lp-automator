import { HardhatUserConfig, subtask } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import '@nomicfoundation/hardhat-foundry'
import '@openzeppelin/hardhat-upgrades'
import dotenv from 'dotenv'
import path from 'path'
import glob from 'glob'
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names'

dotenv.config()

const { ARB_RPC_URL, DEV_ACCOUNT } = process.env

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
    hardhat: {
      forking: {
        url: ARB_RPC_URL || '',
        blockNumber: 187834525,
        enabled: true,
      },
      accounts: [
        {
          balance: '10000000000000000000000', // 10,000 ETH
          privateKey: DEV_ACCOUNT || '',
        },
      ],
    },
    arb: {
      url: ARB_RPC_URL,
      chainId: 42161,
      accounts: [DEV_ACCOUNT || ''],
    },
  },
  paths: {
    tests: './test-hardhat',
  },
}

subtask(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS).setAction(
  async (_, hre, runSuper) => {
    const paths = await runSuper()
    const contractsPath = path.join(
      hre.config.paths.root,
      'test-hardhat',
      '**',
      '*.sol',
    )
    const others = glob.sync(contractsPath)

    return [...paths, ...others]
  },
)

export default config
