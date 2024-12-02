import { V1_1Parameters } from '../schema'

const honey_usdc: V1_1Parameters = {
  id: 'HONEY-USDC',
  pool: '0x64f18443596880df5237411591afe7ae69f9e9b9',
  router: '0x66e8f0cf851ce9be42a2f133a8851bc6b70b9ebd',
  handler: '0x670c817C2C57B78E746f977741C36a663a216C52',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xB6c298A1ba27808D6B618f5CAaAB290f0180513b',
  asset: '0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e03', // HONEY,
  counterAsset: '0xd6D83aF58a19Cd14eF3CF6fe848C9A4d21e5727c', // USDC
  symbol: 'osyk-HONEY-USDC',
  minDepositAssets: '0.002', // 10 HONEY
  unit: 18,
  assetUsdFeed: '0x0000000000000000000000000000000000000001', // dummy address
  counterAssetUsdFeed: '0x0000000000000000000000000000000000000002', // dummy address
  admin: '0xb0c757bC94704246Ce0552b5Ccc1A547c0633914',
  strategist: '0xb0c757bC94704246Ce0552b5Ccc1A547c0633914',
  depositFeePips: '1000',
  quoterType: 'twap',
}

export default honey_usdc
