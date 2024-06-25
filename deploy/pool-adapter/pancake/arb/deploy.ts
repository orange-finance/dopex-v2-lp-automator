import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre) {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address: wethUsdc500 } = await deploy(
    'PancakeV3PoolAdapter_WETH_USDC_500',
    {
      contract: 'PancakeV3PoolAdapter',
      args: ['0xd9e2a1a61B6E61b275cEc326465d417e52C1b95c'],
      from: deployer,
      log: true,
    },
  )

  const { address: arbUsdc500 } = await deploy(
    'PancakeV3PoolAdapter_ARB_USDC_500',
    {
      contract: 'PancakeV3PoolAdapter',
      args: ['0x9fFCA51D23Ac7F7df82da414865Ef1055E5aFCc3'],
      from: deployer,
      log: true,
    },
  )

  const { address: wbtcUsdc500 } = await deploy(
    'PancakeV3PoolAdapter_WBTC_USDC_500',
    {
      contract: 'PancakeV3PoolAdapter',
      args: ['0x843aC8dc6D34AEB07a56812b8b36429eE46BDd07'],
      from: deployer,
      log: true,
    },
  )

  if (hre.network.name !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'PancakeV3PoolAdapter_WETH_USDC_500',
      address: wethUsdc500,
    })

    await hre.tenderly.verify({
      name: 'PancakeV3PoolAdapter_ARB_USDC_500',
      address: arbUsdc500,
    })

    await hre.tenderly.verify({
      name: 'PancakeV3PoolAdapter_WBTC_USDC_500',
      address: wbtcUsdc500,
    })
  }
}

func.tags = ['pool-adapter-arb']

export default func
