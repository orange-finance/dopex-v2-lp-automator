import hre from 'hardhat'
import { OrangeStrykeLPAutomatorV1_1 } from '@/typechain-types'

async function main() {
  if (hre.network.name != 'qa' && hre.network.name != 'hardhat')
    throw new Error('Only for the qa environment')

  // v1 deploy
  const init: OrangeStrykeLPAutomatorV1_1.InitArgsStruct = {
    name: 'odpxWETH-USDC',
    symbol: 'odpxWETH-USDC',
    admin: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
    manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
    handler: '0x29BbF7EbB9C5146c98851e76A5529985E4052116',
    handlerHook: '0x0000000000000000000000000000000000000000',
    pool: '0xC6962004f452bE9203591991D15f6b388e09E8D0',
    router: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
    asset: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
    quoter: '0x18404De1887654A246e855892B71dFD11e927342',
    assetUsdFeed: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612',
    counterAssetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3',
    minDepositAssets: hre.ethers.parseUnits('0.005', 18),
  }

  const v1 = await hre.upgrades.deployProxy(
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV1_1'),
    [init],
    {
      kind: 'uups',
    },
  )

  console.log('v1 deployed at:', v1.target)

  await v1.setDepositCap(hre.ethers.MaxUint256)
  await v1.setStrategist('0x12D1A136250131E37A607B0b78F6F109BF6a9fa3', true)
  await v1.setDepositFeePips(
    '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
    '1000',
  )

  // v2 upgrade
  const v2 = await hre.upgrades.upgradeProxy(
    v1.target,
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV2'),
    {
      kind: 'uups',
      call: {
        fn: 'initializeV2',
        args: ['0xBA12222222228d8Ba445958a75a0704d566BF2C8'], // balancer address
      },
    },
  )

  await v2.setProxyWhitelist('0x6F9DD9b2BE02949cc5Bc55B15816b27066150459', true)

  console.log(`v2 upgrade success: ${v2.target}`)

  const bcv2 = await hre.upgrades.upgradeProxy(
    v2.target,
    await hre.ethers.getContractFactory(
      'BackwardCompatibleOrangeStrykeLPAutomatorV2',
    ),
    {
      unsafeAllow: ['delegatecall'],
    },
  )

  console.log(`bcv2 upgrade success: ${bcv2.target}`)

  const vaultStorages = {
    asset: await v2.asset(),
    counterAsset: await v2.counterAsset(),
    minDepositAssets: await v2.minDepositAssets(),
    depositCap: await v2.depositCap(),
    depositFeePips: await v2.depositFeePips(),
    depositFeeRecipient: await v2.depositFeeRecipient(),
    isOwner: await v2.isOwner('0x12D1A136250131E37A607B0b78F6F109BF6a9fa3'),
    isStrategist: await v2.isStrategist(
      '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
    ),
    activeTicks: await v2.getActiveTicks(),
    decimals: await v2.decimals(),
    manager: await v2.manager(),
    handler: await v2.handler(),
    handlerHook: await v2.handlerHook(),
    quoter: await v2.quoter(),
    assetUsdFeed: await v2.assetUsdFeed(),
    counterAssetUsdFeed: await v2.counterAssetUsdFeed(),
    pool: await v2.pool(),
    router: await v2.router(),
    poolTickSpacing: await v2.poolTickSpacing(),
    balancer: await v2.balancer(),
    swapInputDelta: await v2.swapInputDelta(),
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
