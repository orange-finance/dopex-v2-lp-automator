import hre from 'hardhat'

export function ensureForkNetwork() {
  if (!['hardhat', 'berachain_bartio'].includes(hre.network.name)) {
    throw new Error('This test must be run on a hardhat network')
  }

  if (!hre.config.networks.hardhat.forking?.enabled) {
    throw new Error('This test must be run on a forked network')
  }
}
