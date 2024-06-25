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

  if (hre.network.name !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'UniswapV3PoolAdapter',
      address: wethUsdc500,
    })
  }
}

func.tags = ['pool-adapter-arb']

export default func
