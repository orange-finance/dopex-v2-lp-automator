import { V1_1Parameters } from '../schema'

const weth_usdc: V1_1Parameters = {
  id: 'Sushi-WETH-USDC',
  pool: '0xf3Eb87C1F6020982173C908E7eB31aA66c1f0296',
  router: '0x8A21F6768C1f8075791D08546Dadf6daA0bE820c', // Sushi Router
  handler: '0x89ED51a5C586C3E1634A2de5542d037a74FcDA38', // Sushi Handler
  hook: '0x0000000000000000000000000000000000000000', // No hook
  manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc', // Global Manager
  asset: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', // WETH,
  counterAsset: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831', // USDC
  symbol: 'osyksushiWETH-USDC',
  minDepositAssets: '0.005', // 0.005 WETH
  unit: 18,
  assetUsdFeed: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612', // ETH /USD
  counterAssetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC / USD
  admin: '0x38E4157345Bd2c8Cf7Dbe4B0C75302c2038AB7Ec',
  strategist: '0xb0c757bC94704246Ce0552b5Ccc1A547c0633914',
  depositFeePips: '1000',
  quoterType: 'chainlink',
}

export default weth_usdc
