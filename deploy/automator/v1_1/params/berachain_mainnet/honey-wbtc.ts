import { V1_1Parameters } from '../schema'

const honey_wbtc: V1_1Parameters = {
  id: 'HONEY-WBTC',
  pool: '0x545Bea6Ea7F8fD8dCC5C9A6802a8ebF3DbFc1C6E',
  router: '0xEd158C4b336A6FCb5B193A5570e3a571f6cbe690',
  handler: '0xf6314300b42B7D88c153348921a95d3CA95E74Bd',
  hook: '0x694cDB4080de3EE8BEc53445fe7E8FAc9C82fd5D',
  manager: '0x78d96C07B16d8f911c4cD14EE10601921E4fb8aF',
  asset: '0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce', // HONEY,
  counterAsset: '0x0555E30da8f98308EdB960aa94C0Db47230d2B9c', // WBTC
  symbol: 'osyk-HONEY-WBTC',
  minDepositAssets: '0.1', // 0.1 HONEY
  unit: 18,
  assetUsdFeed: '0x0000000000000000000000000000000000000001', // dummy address
  counterAssetUsdFeed: '0x0000000000000000000000000000000000000002', // dummy address
  strategist: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  depositFeePips: '10000', // 1%
  quoterType: 'twap',
}

export default honey_wbtc
