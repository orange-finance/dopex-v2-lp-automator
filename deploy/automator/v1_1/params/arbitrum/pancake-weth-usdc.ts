import { V1_1Parameters } from '../schema'

const weth_usdc: V1_1Parameters = {
  id: 'Pancake-WETH-USDC',
  pool: '0x1e58460e7333251f71Fb240b981B0e5F6A31bF24',
  router: '0x1b81D678ffb9C0263b24A97847620C99d213eB14',
  handler: '0x23aD242c41b965DB6343ec4A9890fcF80da1c314',
  hook: '0x1f3E50774ebbFF1C2a8F21B52D27AD4d5584246f',
  manager: '0x5eE223AcD61E744458b4d1bB1e24F64F243Cf28E',
  asset: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', // WETH,
  counterAsset: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // USDC
  symbol: 'osykpcsWETH-USDC',
  minDepositAssets: '0.005', // 0.005 WETH
  unit: 18,
  assetUsdFeed: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612', // ETH /USD
  counterAssetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC / USD
  strategist: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  depositFeePips: '1000',
  quoterType: 'chainlink',
}

export default weth_usdc
