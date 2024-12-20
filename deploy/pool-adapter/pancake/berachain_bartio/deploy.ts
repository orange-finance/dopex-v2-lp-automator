import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre) {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  await deploy('PancakeV3PoolAdapter_HONEY-USDC_500', {
    contract: 'PancakeV3PoolAdapter',
    args: ['0x64F18443596880Df5237411591Afe7Ae69f9e9B9'],
    from: deployer,
    log: true,
  })
  await deploy('PancakeV3PoolAdapter_WBERA-HONEY_3000', {
    contract: 'PancakeV3PoolAdapter',
    args: ['0x8a960A6e5f224D0a88BaD10463bDAD161b68C144'],
    from: deployer,
    log: true,
  })
}

func.tags = ['base-berachain_bartio']

export default func
