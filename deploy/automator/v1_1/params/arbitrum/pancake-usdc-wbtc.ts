import { V1_1Parameters } from '../schema'

const usdc_wbtc: V1_1Parameters = {
  id: 'Pancake-USDC-WBTC',
  pool: '0xCD1bEE81404125128Fad59Cc30f2E8E9f92F6f93', // WBTC/USDC
  router: '0x1b81D678ffb9C0263b24A97847620C99d213eB14',
  handler: '0x23aD242c41b965DB6343ec4A9890fcF80da1c314',
  hook: '0x1f3E50774ebbFF1C2a8F21B52D27AD4d5584246f',
  manager: '0x5eE223AcD61E744458b4d1bB1e24F64F243Cf28E',
  asset: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // USDC
  counterAsset: '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f', // WBTC
  symbol: 'osykpcsUSDC-WBTC',
  minDepositAssets: '10', // 10 USDC
  unit: 6,
  assetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC / USD
  counterAssetUsdFeed: '0xd0C7101eACbB49F3deCcCc166d238410D6D46d57', // WBTC /USD
  strategist: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  depositFeePips: '1000',
  quoterType: 'chainlink',
}

export default usdc_wbtc
