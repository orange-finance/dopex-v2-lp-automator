import { DeployFunction } from 'hardhat-deploy/types'
import { Parameters } from './params/schema'

const func: DeployFunction = async function (hre) {
  const { deployments, getNamedAccounts, network } = hre
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const params = Parameters.parse(
    await import(`./params/${network.name}.ts`).then((m) => m.default),
  )

  const { address, newlyDeployed } = await deploy('ChainlinkQuoter', {
    contract: 'ChainlinkQuoter',
    from: deployer,
    args: [params.l2SequencerUptimeFeed],
    log: true,
  })

  if (newlyDeployed) {
    const quoter = await hre.ethers.getContractAt('ChainlinkQuoter', address)

    for (const { feed, threshold } of params.stalenessThresholds) {
      await quoter.setStalenessThreshold(feed, threshold)
    }

    // Transfer ownership to admin
    if (network.name === 'prod') await quoter.transferOwnership(params.admin)
  }

  if (network.name !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'ChainlinkQuoter',
      address,
    })
  }
}

func.tags = ['chainlink-quoter', 'base_arbitrum']

export default func
