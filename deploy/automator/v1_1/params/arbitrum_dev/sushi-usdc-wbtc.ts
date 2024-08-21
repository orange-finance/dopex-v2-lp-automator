import { V1_1Parameters } from '../schema'

const usdc_wbtc: V1_1Parameters = {
  id: 'Sushi-USDC-WBTC',
  pool: '0x699f628A8A1DE0f28cf9181C1F8ED848eBB0BBdF', // WBTC/USDC
  router: '0x8A21F6768C1f8075791D08546Dadf6daA0bE820c',
  handler: '0x89ED51a5C586C3E1634A2de5542d037a74FcDA38',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
  asset: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // USDC
  counterAsset: '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f', // WBTC
  symbol: 'osyksushiUSDC-WBTC',
  minDepositAssets: '10', // 10 USDC
  unit: 6,
  assetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC / USD
  counterAssetUsdFeed: '0xd0C7101eACbB49F3deCcCc166d238410D6D46d57', // WBTC /USD
  admin: '0x38E4157345Bd2c8Cf7Dbe4B0C75302c2038AB7Ec',
  strategist: '0xb0c757bC94704246Ce0552b5Ccc1A547c0633914',
  depositFeePips: '1000',
  quoterType: 'chainlink',
}

export default usdc_wbtc
