import { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre) {
  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const { address } = await deploy('ReserveProxy', {
    contract: 'ReserveProxy',
    from: deployer,
    log: true,
  })

  if (hre.network.name !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'ReserveProxy',
      address,
    })
  }
}

func.tags = ['periphery', 'reserve-proxy']

export default func
