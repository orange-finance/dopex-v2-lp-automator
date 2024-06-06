import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre) {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address } = await deploy('StrykeVaultInspector', {
    contract: 'StrykeVaultInspector',
    from: deployer,
    log: true,
  })

  if (hre.network.name !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'StrykeVaultInspector',
      address,
    })
  }
}

func.tags = ['periphery', 'base', 'inspector']

export default func
