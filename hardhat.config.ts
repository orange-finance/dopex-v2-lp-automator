import { HardhatUserConfig, subtask } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import '@nomicfoundation/hardhat-foundry'
import 'hardhat-deploy'
import * as tenderly from '@tenderly/hardhat-tenderly'
import '@openzeppelin/hardhat-upgrades'
import 'dotenv/config'
import path from 'path'
import glob from 'glob'
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from 'hardhat/builtin-tasks/task-names'

tenderly.setup({
  automaticVerifications: false,
})

const { ARB_RPC_URL, DEV_ACCOUNT, PROD_ACCOUNT } = process.env

function viaIR(version: string, runs: number) {
  return {
    version,
    settings: {
      optimizer: {
        enabled: true,
        runs,
      },
      viaIR: true,
    },
  }
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
    overrides: {
      'contracts/v2/OrangeStrykeLPAutomatorV2.sol': viaIR('0.8.19', 200),
      'contracts/v2/BackwardCompatibleOrangeStrykeLPAutomatorV2.sol': viaIR(
        '0.8.19',
        200,
      ),
      'contracts/v2_1/OrangeStrykeLPAutomatorV2_1.sol': viaIR('0.8.19', 200),
      'contracts/v2_1/BackwardCompatibleOrangeStrykeLPAutomatorV2_1.sol': viaIR(
        '0.8.19',
        200,
      ),
    },
  },
  namedAccounts: {
    deployer: 0,
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
    arbitrum: {
      url: ARB_RPC_URL,
      chainId: 42161,
      accounts: [PROD_ACCOUNT || ''],
    },
    arbitrum_test: {
      url: ARB_RPC_URL,
      chainId: 42161,
      accounts: [DEV_ACCOUNT || ''],
    },
    arbitrum_dev: {
      url: ARB_RPC_URL,
      chainId: 42161,
      accounts: [DEV_ACCOUNT || ''],
    },
  },
  paths: {
    tests: './test-hardhat',
  },
  tenderly: {
    username: process.env.TENDERLY_USERNAME ?? '',
    project: process.env.TENDERLY_PROJECT ?? '',
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBSCAN_API_KEY ?? '',
    },
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
