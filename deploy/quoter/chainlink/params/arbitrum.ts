import { Parameters } from './schema'

const parameters: Parameters = {
  admin: '0x7baA2913d04fd73a4C5633553EDC17Da18495f9d',
  l2SequencerUptimeFeed: '0xFdB631F5EE196F0ed6FAa767959853A9F217697D',
  stalenessThresholds: [
    {
      feed: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612', // ETH/USD
      threshold: 86400,
    },
    {
      feed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3', // USDC/USD
      threshold: 86400,
    },
    {
      feed: '0xd0C7101eACbB49F3deCcCc166d238410D6D46d57', // WBTC/USD
      threshold: 86400,
    },
    {
      feed: '0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6', // ARB/USD
      threshold: 86400,
    },
  ],
}

export default parameters
