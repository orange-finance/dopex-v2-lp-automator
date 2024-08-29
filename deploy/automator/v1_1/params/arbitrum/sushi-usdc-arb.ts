import { V1_1Parameters } from '../schema'

const usdc_arb: V1_1Parameters = {
  id: 'Sushi-USDC-ARB',
  pool: '0xfa1cC0caE7779B214B1112322A2d1Cf0B511C3bC',
  router: '0x8A21F6768C1f8075791D08546Dadf6daA0bE820c',
  handler: '0x89ed51a5c586c3e1634a2de5542d037a74fcda38',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
  asset: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // USDC
  counterAsset: '0x912CE59144191C1204E64559FE8253a0e49E6548', // ARB
  symbol: 'osykpcsUSDC-ARB',
  minDepositAssets: '10', // 10 USDC
  unit: 6,
  assetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC / USD
  counterAssetUsdFeed: '0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6', // ARB /USD
  admin: '0x38E4157345Bd2c8Cf7Dbe4B0C75302c2038AB7Ec',
  strategist: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  depositFeePips: '1000',
  quoterType: 'chainlink',
}

export default usdc_arb
