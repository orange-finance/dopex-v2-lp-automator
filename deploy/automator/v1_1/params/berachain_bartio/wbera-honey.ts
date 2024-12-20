import { V1_1Parameters } from '../schema'

const wbera_honey: V1_1Parameters = {
  id: 'WBERA-HONEY',
  pool: '0x8a960A6e5f224D0a88BaD10463bDAD161b68C144',
  router: '0x66e8f0cf851ce9be42a2f133a8851bc6b70b9ebd',
  handler: '0x670c817C2C57B78E746f977741C36a663a216C52',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xB6c298A1ba27808D6B618f5CAaAB290f0180513b',
  asset: '0x7507c1dc16935B82698e4C63f2746A2fCf994dF8', // WBERA,
  counterAsset: '0x0E4aaF1351de4c0264C5c7056Ef3777b41BD8e03', // HONEY
  symbol: 'osyk-WBERA-HONEY',
  minDepositAssets: '0.0011', // 0.0011 WBERA
  unit: 18,
  assetUsdFeed: '0x0000000000000000000000000000000000000001', // dummy address
  counterAssetUsdFeed: '0x0000000000000000000000000000000000000002', // dummy address
  admin: '0xb0c757bC94704246Ce0552b5Ccc1A547c0633914',
  strategist: '0xb0c757bC94704246Ce0552b5Ccc1A547c0633914',
  depositFeePips: '1000',
  quoterType: 'twap',
}

export default wbera_honey
