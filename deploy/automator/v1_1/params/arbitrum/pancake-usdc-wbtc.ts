import { V1_1Parameters } from '../schema'

const usdc_wbtc: V1_1Parameters = {
  id: 'Pancake-USDC-WBTC',
  pool: '0xa3eB2D7388ba454423F574fcdA5Cf7425D04EC68', // WBTC/USDC
  router: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  handler: '0x9ae336B61D7d2e19a47607f163A3fB0e46306b7b',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
  asset: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // USDC
  counterAsset: '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f', // WBTC
  symbol: 'osykpcsUSDC-WBTC',
  minDepositAssets: '10', // 10 USDC
  unit: 6,
  assetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC / USD
  counterAssetUsdFeed: '0xd0C7101eACbB49F3deCcCc166d238410D6D46d57', // WBTC /USD
  admin: '0x38E4157345Bd2c8Cf7Dbe4B0C75302c2038AB7Ec',
  strategist: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  depositFeePips: '1000',
  quoterType: 'chainlink',
}

export default usdc_wbtc
