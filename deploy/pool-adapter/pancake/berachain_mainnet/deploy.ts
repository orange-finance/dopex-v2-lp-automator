import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre) {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  await deploy('PoolAdapter_Kodiak-WETH-HONEY_3000', {
    contract: 'PancakeV3PoolAdapter',
    args: ['0x9EB897D400f245E151daFD4c81176397D7798C9c'],
    from: deployer,
    log: true,
  })
  await deploy('PoolAdapter_Kodiak-WBTC-HONEY_3000', {
    contract: 'PancakeV3PoolAdapter',
    args: ['0x545Bea6Ea7F8fD8dCC5C9A6802a8ebF3DbFc1C6E'],
    from: deployer,
    log: true,
  })
  await deploy('PoolAdapter_Kodiak-WBERA-HONEY_3000', {
    contract: 'PancakeV3PoolAdapter',
    args: ['0x1127f801Cb3ab7BDF8923272949AA7Dba94B5805'],
    from: deployer,
    log: true,
  })
}

func.tags = ['base-berachain_mainnet']

export default func
