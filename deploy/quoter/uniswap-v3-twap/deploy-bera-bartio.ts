import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

function pairId(
  hre: HardhatRuntimeEnvironment,
  tokenA: string,
  tokenB: string,
) {
  const ta = hre.ethers.toBigInt(tokenA)
  const tb = hre.ethers.toBigInt(tokenB)
  if (ta < tb) [tokenA, tokenB] = [tokenB, tokenA]

  return hre.ethers.keccak256(
    hre.ethers.AbiCoder.defaultAbiCoder().encode(
      ['address', 'address'],
      [tokenA, tokenB],
    ),
  )
}

const func: DeployFunction = async function (hre) {
  const ORACLE = '0x0A4d3aEE7eE3628bC96d57715ccD034De312e884'
  const TWAP_CONFIG = {
    'honey-usdc': {
      pairId: pairId(
        hre,
        '0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e03', // HONEY
        '0xd6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c', // USDC
      ),
      pool: '0x64F18443596880Df5237411591Afe7Ae69f9e9B9',
      duration: 600, // 10 minutes
    },
    'wbera-honey': {
      pairId: pairId(
        hre,
        '0x7507c1dc16935B82698e4C63f2746A2fCf994dF8', // WBERA
        '0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e03', // HONEY
      ),
      pool: '0x8a960A6e5f224D0a88BaD10463bDAD161b68C144',
      duration: 600, // 10 minutes
    },
  }

  const { deployments, getNamedAccounts } = hre
  const { deploy, execute } = deployments

  const { deployer } = await getNamedAccounts()

  const { address, newlyDeployed } = await deploy('UniswapV3TWAPQuoter', {
    contract: 'UniswapV3TWAPQuoter',
    args: [ORACLE],
    from: deployer,
    log: true,
  })

  for (const [key, value] of Object.entries(TWAP_CONFIG)) {
    await execute(
      'UniswapV3TWAPQuoter',
      {
        from: deployer,
        log: true,
      },
      'setTWAPConfig',
      value.pairId,
      {
        pool: value.pool,
        duration: value.duration,
      },
    )
  }
}

func.tags = ['base_bartio', 'twap-quoter_bartio']

export default func
