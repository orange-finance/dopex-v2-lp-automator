import hre from 'hardhat'

const tokens = {
  WETH: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
  USDC: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
}

const pools = {
  WETH_USDC: '0xC6962004f452bE9203591991D15f6b388e09E8D0',
}

const feeds = {
  ETH_USD: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612',
  USDC_USD: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3',
  L2_SEQUENCER_UPTIME: '0xFdB631F5EE196F0ed6FAa767959853A9F217697D',
}

const stryke = {
  MANAGER: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
  HANDLER_V2: '0x29BbF7EbB9C5146c98851e76A5529985E4052116',
}

export async function baseSetupFixture() {
  const ChainlinkQuoter = await hre.ethers.getContractFactory('ChainlinkQuoter')
  const chainlinkQuoter = await ChainlinkQuoter.deploy(
    feeds.L2_SEQUENCER_UPTIME,
  ).then((c) => c.waitForDeployment())

  const StrykeVaultInspector = await hre.ethers.getContractFactory(
    'StrykeVaultInspector',
  )
  const strykeVaultInspector = await StrykeVaultInspector.deploy().then((c) =>
    c.waitForDeployment(),
  )

  return {
    chainlinkQuoter,
    strykeVaultInspector,
    stryke,
    uniswapRouter: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
    tokens,
    pools,
    feeds,
  }
}
