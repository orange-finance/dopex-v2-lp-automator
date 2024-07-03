import { V1_1Parameters } from '../schema'

const usdc_arb: V1_1Parameters = {
  id: 'USDC-ARB',
  pool: '0xb0f6cA40411360c03d41C5fFc5F179b8403CdcF8',
  router: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  handler: '0x29BbF7EbB9C5146c98851e76A5529985E4052116',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
  asset: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // USDC
  counterAsset: '0x912CE59144191C1204E64559FE8253a0e49E6548', // ARB
  symbol: 'odpxUSDC-ARB',
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
