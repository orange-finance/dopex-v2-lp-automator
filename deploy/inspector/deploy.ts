import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre) {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address: v1 } = await deploy('StrykeVaultInspector', {
    contract: 'StrykeVaultInspector',
    from: deployer,
    log: true,
  })

  const { address: v2 } = await deploy('StrykeVaultInspectorV2', {
    contract: 'StrykeVaultInspectorV2',
    from: deployer,
    log: true,
  })

  if (!['hardhat', 'berachain_bartio'].includes(hre.network.name)) {
    await hre.tenderly.verify({
      name: 'StrykeVaultInspector',
      address: v1,
    })

    await hre.tenderly.verify({
      name: 'StrykeVaultInspectorV2',
      address: v2,
    })
  }
}

func.tags = ['periphery', 'inspector']

export default func
