import { DeployFunction, Deployment } from 'hardhat-deploy/types'
import { OrangeStrykeLPAutomatorV1_1 } from '../../../typechain-types'
import { V1_1Parameters } from './params/schema'

const PAIR = process.env.PAIR

const func: DeployFunction = async function (hre) {
  if (!PAIR) throw new Error('PAIR is not set')
  const env = hre.network.name
  const { deployments, getNamedAccounts } = hre
  const { deploy, execute } = deployments

  const { deployer } = await getNamedAccounts()

  const paramsPath = `./params/${env}/${PAIR}`

  const params = V1_1Parameters.parse(
    await import(paramsPath).then((m) => m.default),
  )

  let quoter: Deployment
  switch (params.quoterType) {
    case 'chainlink':
      quoter = await deployments.get('ChainlinkQuoter')
      break
    case 'twap':
      quoter = await deployments.get('UniswapV3TWAPQuoter')
      break
    default:
      throw new Error('Invalid quoter type')
  }

  const init: OrangeStrykeLPAutomatorV1_1.InitArgsStruct = {
    name: params.symbol,
    symbol: params.symbol,
    admin: deployer,
    manager: params.manager,
    handler: params.handler,
    handlerHook: params.hook,
    pool: params.pool,
    router: params.router,
    asset: params.asset,
    quoter: quoter.address,
    assetUsdFeed: params.assetUsdFeed,
    counterAssetUsdFeed: params.counterAssetUsdFeed,
    minDepositAssets: hre.ethers.parseUnits(
      params.minDepositAssets,
      params.unit,
    ),
  }

  // check if implementation is upgrade-safe
  await hre.upgrades.validateImplementation(
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV1_1'),
  )

  const { address, implementation, newlyDeployed } = await deploy(params.id, {
    contract: 'OrangeStrykeLPAutomatorV1_1',
    from: deployer,
    proxy: {
      proxyContract: 'UUPS',
      upgradeIndex: 0, // first version
      implementationName: `${params.id}V1_1_Implementation`,
      execute: {
        init: {
          methodName: 'initialize',
          args: [init],
        },
      },
    },
    log: true,
  })

  // if already deployed, skip
  if (!newlyDeployed) return

  // for future upgrade, export new deployment to OpenZeppelin upgrades plugin
  await hre.upgrades.forceImport(
    address,
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV1_1'),
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
    'setDepositCap',
    '115792089237316195423570985008687907853269984665640564039457584007913129639935',
  )

  await execute(
    params.id,
    {
      from: deployer,
    },
    'setOwner',
    params.admin,
    true,
  )

  await execute(
    params.id,
    {
      from: deployer,
      log: true,
    },
    'setStrategist',
    params.strategist,
    true,
  )

  await execute(
    params.id,
    {
      from: deployer,
      log: true,
    },
    'setDepositFeePips',
    params.admin,
    params.depositFeePips,
  )

  if (env !== 'hardhat') {
    await hre.tenderly.verify({
      name: 'OrangeStrykeLPAutomatorV1_1',
      address: implementation!,
    })
  }
}

func.tags = ['v1_1-vault']

export default func
