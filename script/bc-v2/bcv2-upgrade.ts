import hre from 'hardhat'

const v2 = '0xe1B68841E764Cc31be1Eb1e59d156a4ED1217c2C'

async function main() {
  // if (hre.network.name != 'qa' && hre.network.name != 'hardhat')
  //   throw new Error('Only for the qa environment')

  const bcv2 = await hre.upgrades.upgradeProxy(
    v2,
    await hre.ethers.getContractFactory(
      'BackwardCompatibleOrangeStrykeLPAutomatorV2',
    ),
    {
      kind: 'uups',
      unsafeAllow: ['delegatecall'],
    },
  )

  console.log(`bcv2 upgrade success: ${bcv2.target}`)

  const vaultStorages = {
    asset: await bcv2.asset(),
    counterAsset: await bcv2.counterAsset(),
    minDepositAssets: await bcv2.minDepositAssets(),
    depositCap: await bcv2.depositCap(),
    depositFeePips: await bcv2.depositFeePips(),
    depositFeeRecipient: await bcv2.depositFeeRecipient(),
    isOwner: await bcv2.isOwner('0x12D1A136250131E37A607B0b78F6F109BF6a9fa3'),
    isStrategist: await bcv2.isStrategist(
      '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
    ),
    activeTicks: await bcv2.getActiveTicks(),
    decimals: await bcv2.decimals(),
    manager: await bcv2.manager(),
    handler: await bcv2.handler(),
    handlerHook: await bcv2.handlerHook(),
    quoter: await bcv2.quoter(),
    assetUsdFeed: await bcv2.assetUsdFeed(),
    counterAssetUsdFeed: await bcv2.counterAssetUsdFeed(),
    pool: await bcv2.pool(),
    router: await bcv2.router(),
    poolTickSpacing: await bcv2.poolTickSpacing(),
    balancer: await bcv2.balancer(),
    swapInputDelta: await bcv2.swapInputDelta(),
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
