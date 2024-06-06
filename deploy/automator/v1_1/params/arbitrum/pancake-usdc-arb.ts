import { V1_1Parameters } from '../schema'

const usdc_arb: V1_1Parameters = {
  id: 'Pancake-USDC-ARB',
  pool: '0x9fFCA51D23Ac7F7df82da414865Ef1055E5aFCc3',
  router: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  handler: '0x9ae336B61D7d2e19a47607f163A3fB0e46306b7b',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
  asset: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // USDC
  counterAsset: '0x912CE59144191C1204E64559FE8253a0e49E6548', // ARB
  symbol: 'osykpcsUSDC-ARB',
  minDepositAssets: '10', // 10 USDC
  unit: 6,
  assetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC / USD
  counterAssetUsdFeed: '0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6', // ARB /USD
  admin: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  strategist: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  depositFeePips: '1000',
  quoterType: 'chainlink',
}

export default usdc_arb
