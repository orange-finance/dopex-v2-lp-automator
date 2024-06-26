import { V1_1Parameters } from '../schema'

const weth_usdc: V1_1Parameters = {
  id: 'Pancake-WETH-USDC',
  pool: '0x77368F2329567d04154e1E751A681F3E24caAA95',
  router: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  handler: '0x9ae336B61D7d2e19a47607f163A3fB0e46306b7b',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
  asset: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', // WETH,
  counterAsset: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // USDC
  symbol: 'osykpcsWETH-USDC',
  minDepositAssets: '0.005', // 0.005 WETH
  unit: 18,
  assetUsdFeed: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612', // ETH /USD
  counterAssetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC / USD
  admin: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  strategist: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  depositFeePips: '1000',
  quoterType: 'chainlink',
}

export default weth_usdc
