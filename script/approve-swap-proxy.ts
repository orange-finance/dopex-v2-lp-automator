import { deployments, getNamedAccounts } from 'hardhat'
import readline from 'readline/promises'

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
})

async function main() {
  const proxy = await rl.question('Enter the proxy address: ')

  const { deployer } = await getNamedAccounts()

  const vaults = [
    'WETH-USDC',
    'USDC-WBTC',
    'USDC-ARB',
    'BOOP-WETH',
    'Pancake-WETH-USDC',
    'Pancake-WETH-USDC',
    'Pancake-USDC-WBTC',
  ]

  for (const vault of vaults) {
    await deployments.execute(
      vault,
      { from: deployer, log: true },
      'setProxyWhitelist',
      proxy,
      true,
    )
  }
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
