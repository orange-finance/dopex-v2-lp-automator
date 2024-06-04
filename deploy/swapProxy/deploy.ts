import { DeployFunction } from 'hardhat-deploy/types'
import { Parameters } from './params/schema'

const func: DeployFunction = async function (hre) {
  const env = hre.network.name

  const { deployments, getNamedAccounts } = hre
  const { deploy } = deployments
  const { deployer } = await getNamedAccounts()

  const paramsPath = `./params/${env}`
  const params = Parameters.parse(
    await import(paramsPath).then((m) => m.default),
  )

  const { address, newlyDeployed } = await deploy('OrangeKyberswapProxy', {
    from: deployer,
    log: true,
  })

  if (newlyDeployed) {
    const proxy = await hre.ethers.getContractAt(
      'OrangeKyberswapProxy',
      address,
    )
    await proxy.setTrustedProvider(params.trustedProviders.kyberswap, true)

    if (params.admin != deployer) await proxy.setOwner(params.admin)
  }

  if (env !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'OrangeKyberswapProxy',
      address,
    })
  }
}

func.tags = ['swapProxy', 'base']

export default func
