import hre from 'hardhat'

const v2 = '0xe1B68841E764Cc31be1Eb1e59d156a4ED1217c2C'

async function main() {
  if (hre.network.name != 'hardhat')
    throw new Error('Only for the hardhat fork environment')

  const bcv2_1 = await hre.upgrades.upgradeProxy(
    v2,
    await hre.ethers.getContractFactory(
      'BackwardCompatibleOrangeStrykeLPAutomatorV2_1',
    ),
    {
      kind: 'uups',
      call: {
        fn: 'initializeV2_1',
        args: ['0xbeF87B530713F047C2640149825bc6c973f5A22a'], // pool adapter
      },
      unsafeAllow: ['delegatecall'],
    },
  )

  console.log(`bcv2_1 upgrade success: ${bcv2_1.target}`)

  const vaultStorages = {
    asset: await bcv2_1.asset(),
    counterAsset: await bcv2_1.counterAsset(),
    minDepositAssets: await bcv2_1.minDepositAssets(),
    depositCap: await bcv2_1.depositCap(),
    depositFeePips: await bcv2_1.depositFeePips(),
    depositFeeRecipient: await bcv2_1.depositFeeRecipient(),
    isOwner: await bcv2_1.isOwner('0x12D1A136250131E37A607B0b78F6F109BF6a9fa3'),
    isStrategist: await bcv2_1.isStrategist(
      '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
    ),
    activeTicks: await bcv2_1.getActiveTicks(),
    decimals: await bcv2_1.decimals(),
    manager: await bcv2_1.manager(),
    handler: await bcv2_1.handler(),
    handlerHook: await bcv2_1.handlerHook(),
    quoter: await bcv2_1.quoter(),
    assetUsdFeed: await bcv2_1.assetUsdFeed(),
    counterAssetUsdFeed: await bcv2_1.counterAssetUsdFeed(),
    pool: await bcv2_1.pool(),
    router: await bcv2_1.router(),
    poolTickSpacing: await bcv2_1.poolTickSpacing(),
    balancer: await bcv2_1.balancer(),
    swapInputDelta: await bcv2_1.swapInputDelta(),
    poolAdapter: await bcv2_1.poolAdapter(),
  }

  Object.defineProperty(BigInt.prototype, 'toJSON', {
    get() {
      'use strict'
      return () => String(this)
    },
  })

  console.log('storages: ', JSON.stringify(vaultStorages, null, 2))
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
