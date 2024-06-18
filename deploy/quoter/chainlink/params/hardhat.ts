import { Parameters } from './schema'

const parameters: Parameters = {
  admin: '0x38E4157345Bd2c8Cf7Dbe4B0C75302c2038AB7Ec',
  l2SequencerUptimeFeed: '0xFdB631F5EE196F0ed6FAa767959853A9F217697D',
  stalenessThresholds: [
    {
      feed: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612',
      threshold: 86400,
    },
    {
      feed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3',
      threshold: 86400,
    },
    {
      feed: '0xd0C7101eACbB49F3deCcCc166d238410D6D46d57',
      threshold: 86400,
    },
    {
      feed: '0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6',
      threshold: 86400,
    },
  ],
}

export default parameters
