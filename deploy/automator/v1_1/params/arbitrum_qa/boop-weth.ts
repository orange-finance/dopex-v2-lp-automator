import { V1_1Parameters } from '../schema'

const boop_weth: V1_1Parameters = {
  id: 'BOOP-WETH',
  pool: '0xe24F62341D84D11078188d83cA3be118193D6389',
  router: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  handler: '0x29BbF7EbB9C5146c98851e76A5529985E4052116',
  hook: '0x0000000000000000000000000000000000000000',
  manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
  asset: '0x13A7DeDb7169a17bE92B0E3C7C2315B46f4772B3', // BOOP
  counterAsset: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', // WETH,
  symbol: 'odpxBOOP-WETH',
  minDepositAssets: '1', // 1 BOOP
  unit: 18,
  assetUsdFeed: '0x0000000000000000000000000000000000000001', // dummy address
  counterAssetUsdFeed: '0x0000000000000000000000000000000000000002', // dummy address
  admin: '0x38E4157345Bd2c8Cf7Dbe4B0C75302c2038AB7Ec',
  strategist: '0xb0c757bC94704246Ce0552b5Ccc1A547c0633914',
  depositFeePips: '1000',
  quoterType: 'twap',
}

export default boop_weth
