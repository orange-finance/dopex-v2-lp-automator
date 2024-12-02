import { DeployFunction } from 'hardhat-deploy/types'
import { V2Parameters } from './params/schema'
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

  const params = V2Parameters.parse(
    await import(paramsPath).then((m) => m.default),
  )

  const proxy =
    network.name === 'berachain_bartio'
      ? { address: '0x0000000000000000000000000000000000000001' } // dummy address for berachain bartio
      : await deployments.get('OrangeKyberswapProxy')

  const vaultDeployed = await deployments.get(params.id)

  // check the new implementation is upgrade safe
  await hre.upgrades.validateUpgrade(
    vaultDeployed.address,
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV2'),
    {
      kind: 'uups',
    },
  )

  const { address, implementation, newlyDeployed } = await deploy(params.id, {
    contract: 'OrangeStrykeLPAutomatorV2',
    from: deployer,
    proxy: {
      proxyContract: 'UUPS',
      upgradeIndex: 1, // v1 to v2
      implementationName: `${params.id}V2_Implementation`,
      execute: {
        methodName: 'initializeV2',
        args: [params.balancer],
      },
    },
    log: true,
  })

  // if already deployed, skip
  if (!newlyDeployed) return

  // for future upgrade, export upgrade to OpenZeppelin upgrades plugin
  await hre.upgrades.forceImport(
    address,
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV2'),
    {
      kind: 'uups',
    },
  )

  // configurations
  await execute(
    params.id,
    {
      from: deployer,
      log: true,
    },
    'setProxyWhitelist',
    proxy.address,
    true,
  )

  if (env !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'OrangeStrykeLPAutomatorV2',
      address: implementation!,
    })
  }
}

func.tags = ['v2-vault']

export default func
