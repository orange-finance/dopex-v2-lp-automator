import hre from 'hardhat'

const v2 = '0x708790D732c5886D56b0cBBEd7b60ABF47848FaA'
const poolAdapter = '0x01248FD85f37B926933e72814EBAE2177f92ef83'

async function main() {
  await hre.upgrades.forceImport(
    v2,
    await hre.ethers.getContractFactory(
      'BackwardCompatibleOrangeStrykeLPAutomatorV2',
    ),
    {
      kind: 'uups',
    },
  )
  const v2_1 = await hre.upgrades
    .upgradeProxy(
      v2,
      await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV2_1'),
      {
        kind: 'uups',
        call: {
          fn: 'initializeV2_1',
          args: [poolAdapter],
        },
        unsafeAllow: ['delegatecall'],
      },
    )
    .then((c) => c.waitForDeployment())

  console.log(`v2_1 upgrade success: ${v2_1.target}`)

  const vaultStorages = {
    asset: await v2_1.asset(),
    counterAsset: await v2_1.counterAsset(),
    minDepositAssets: await v2_1.minDepositAssets(),
    depositCap: await v2_1.depositCap(),
    depositFeePips: await v2_1.depositFeePips(),
    depositFeeRecipient: await v2_1.depositFeeRecipient(),
    isOwner: await v2_1.isOwner('0x12D1A136250131E37A607B0b78F6F109BF6a9fa3'),
    isStrategist: await v2_1.isStrategist(
      '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
    ),
    activeTicks: await v2_1.getActiveTicks(),
    decimals: await v2_1.decimals(),
    manager: await v2_1.manager(),
    handler: await v2_1.handler(),
    handlerHook: await v2_1.handlerHook(),
    quoter: await v2_1.quoter(),
    assetUsdFeed: await v2_1.assetUsdFeed(),
    counterAssetUsdFeed: await v2_1.counterAssetUsdFeed(),
    pool: await v2_1.pool(),
    router: await v2_1.router(),
    poolTickSpacing: await v2_1.poolTickSpacing(),
    balancer: await v2_1.balancer(),
    swapInputDelta: await v2_1.swapInputDelta(),
    poolAdapter: await v2_1.poolAdapter(),
  }

  Object.defineProperty(BigInt.prototype, 'toJSON', {
    get() {
      'use strict'
      return () => String(this)
    },
  })

  console.log('storages: ', JSON.stringify(vaultStorages, null, 2))
  console.log('totalAssets: ', await v2_1.totalAssets())
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
