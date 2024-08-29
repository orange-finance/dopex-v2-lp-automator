import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre) {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address: wethUsdc500 } = await deploy(
    'SushiPoolAdapter_WETH_USDC_500',
    {
      contract: 'UniswapV3PoolAdapter',
      args: ['0xf3Eb87C1F6020982173C908E7eB31aA66c1f0296'],
      from: deployer,
      log: true,
    },
  )

  const { address: usdcWbtc500 } = await deploy(
    'SushiPoolAdapter_USDC_WBTC_500',
    {
      contract: 'UniswapV3PoolAdapter',
      args: ['0x699f628a8a1de0f28cf9181c1f8ed848ebb0bbdf'],
      from: deployer,
      log: true,
    },
  )

  const { address: usdcArb500 } = await deploy(
    'SushiPoolAdapter_USDC_ARB_500',
    {
      contract: 'UniswapV3PoolAdapter',
      args: ['0xfa1cC0caE7779B214B1112322A2d1Cf0B511C3bC'],
      from: deployer,
      log: true,
    },
  )

  if (hre.network.name !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'UniswapV3PoolAdapter',
      address: wethUsdc500,
    })
    await hre.tenderly.verify({
      name: 'UniswapV3PoolAdapter',
      address: usdcWbtc500,
    })
    await hre.tenderly.verify({
      name: 'UniswapV3PoolAdapter',
      address: usdcArb500,
    })
  }
}

func.tags = ['pool-adapter-arb']

export default func
