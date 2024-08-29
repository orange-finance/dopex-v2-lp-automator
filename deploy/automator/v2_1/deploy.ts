import { DeployFunction } from 'hardhat-deploy/types'
import { V2_1Parameters } from './schema'
import { network } from 'hardhat'

const PAIR = process.env.PAIR

// For redeploying the vault with new implementation (when testing / QA environment),
// You need to delete deployment json of Proxy and Metadata first.
// e.g. WETH-USDC_Proxy.json, WETH-USDC.json
const func: DeployFunction = async function (hre) {
  if (!PAIR) throw new Error('PAIR is not set')
  const env = hre.network.name
  const { deployments, getNamedAccounts } = hre
  const { deploy, execute } = deployments

  const { deployer } = await getNamedAccounts()

  const paramsPath = `./params/${env}/${PAIR}`

  const params = V2_1Parameters.parse(
    await import(paramsPath).then((m) => m.default),
  )

  const vaultDeployed = await deployments.get(params.id)

  // check the new implementation is upgrade safe
  await hre.upgrades.validateUpgrade(
    vaultDeployed.address,
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV2_1'),
    {
      kind: 'uups',
    },
  )

  const { address, implementation, newlyDeployed } = await deploy(params.id, {
    contract: 'OrangeStrykeLPAutomatorV2_1',
    from: deployer,
    proxy: {
      proxyContract: 'UUPS',
      upgradeIndex: 2, // v2 to v2_1
      implementationName: `${params.id}V2_1_Implementation`,
      execute: {
        methodName: 'initializeV2_1',
        args: [params.poolAdapter],
      },
    },
    log: true,
  })

  // if already deployed, skip
  if (!newlyDeployed) return

  // for future upgrade, export upgrade to OpenZeppelin upgrades plugin
  await hre.upgrades.forceImport(
    address,
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV2_1'),
    {
      kind: 'uups',
    },
  )

  // configurations
  if (network.name === 'prod' && deployer !== params.admin) {
    // set new owner
    await execute(
      params.id,
      {
        from: deployer,
        log: true,
      },
      'setOwner',
      params.admin,
      true,
    )

    // renounce ownership
    await execute(
      params.id,
      {
        from: deployer,
        log: true,
      },
      'setOwner',
      deployer,
      false,
    )
  }

  if (env !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'OrangeStrykeLPAutomatorV2_1',
      address: implementation!,
    })
  }
}

func.tags = ['v2_1-vault']
// func.dependencies = ['base', 'v2-vault']

export default func
