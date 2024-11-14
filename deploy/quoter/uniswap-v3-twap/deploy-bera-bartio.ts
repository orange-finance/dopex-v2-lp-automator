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
  }

  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address, newlyDeployed } = await deploy('UniswapV3TWAPQuoter', {
    contract: 'UniswapV3TWAPQuoter',
    args: [ORACLE],
    from: deployer,
    log: true,
  })

  if (newlyDeployed) {
    const quoter = await hre.ethers.getContractAt(
      'UniswapV3TWAPQuoter',
      address,
    )

    await quoter.setTWAPConfig(TWAP_CONFIG['honey-usdc'].pairId, {
      pool: TWAP_CONFIG['honey-usdc'].pool,
      duration: TWAP_CONFIG['honey-usdc'].duration,
    })
  }
}

func.tags = ['base-berachain_bartio', 'twap-quoter']

export default func
