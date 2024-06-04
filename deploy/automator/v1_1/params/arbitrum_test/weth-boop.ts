import { V1_1Parameters } from '../schema'

const weth_boop: V1_1Parameters = {
  id: 'WETH-BOOP',
  pool: '0xe24F62341D84D11078188d83cA3be118193D6389',
  router: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  handler: '0x29BbF7EbB9C5146c98851e76A5529985E4052116',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
  asset: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', // WETH,
  counterAsset: '0x13A7DeDb7169a17bE92B0E3C7C2315B46f4772B3', // BOOP
  symbol: 'odpxWETH-BOOP',
  minDepositAssets: '0.005', // 0.005 WETH
  unit: 18,
  assetUsdFeed: '0x0000000000000000000000000000000000000001', // dummy address
  counterAssetUsdFeed: '0x0000000000000000000000000000000000000002', // dummy address
  admin: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  strategist: '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
  depositFeePips: '1000',
  quoterType: 'twap',
}

export default weth_boop
