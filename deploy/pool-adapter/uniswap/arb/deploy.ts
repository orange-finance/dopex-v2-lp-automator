import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre) {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address: wethUsdc500 } = await deploy(
    'UniswapV3PoolAdapter_WETH_USDC_500',
    {
      contract: 'UniswapV3PoolAdapter',
      args: ['0xC6962004f452bE9203591991D15f6b388e09E8D0'],
      from: deployer,
      log: true,
    },
  )

  const { address: usdcWbtc500 } = await deploy(
    'UniswapV3PoolAdapter_USDC_WBTC_500',
    {
      contract: 'UniswapV3PoolAdapter',
      args: ['0x0E4831319A50228B9e450861297aB92dee15B44F'],
      from: deployer,
      log: true,
    },
  )

  const { address: usdcArb500 } = await deploy(
    'UniswapV3PoolAdapter_USDC_ARB_500',
    {
      contract: 'UniswapV3PoolAdapter',
      args: ['0xb0f6cA40411360c03d41C5fFc5F179b8403CdcF8'],
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
