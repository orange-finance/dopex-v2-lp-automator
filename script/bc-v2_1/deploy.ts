import hre from 'hardhat'
import { OrangeStrykeLPAutomatorV1_1 } from '../../typechain-types'

async function main() {
  if (hre.network.name != 'arbitrum_test' && hre.network.name != 'hardhat')
    throw new Error('Only for the arbitrum_test environment')

  // v1 deploy
  const init: OrangeStrykeLPAutomatorV1_1.InitArgsStruct = {
    name: 'odpxWETH-USDC',
    symbol: 'odpxWETH-USDC',
    admin: '0xb0c757bC94704246Ce0552b5Ccc1A547c0633914',
    manager: '0xE4bA6740aF4c666325D49B3112E4758371386aDc',
    handler: '0x29BbF7EbB9C5146c98851e76A5529985E4052116',
    handlerHook: '0x0000000000000000000000000000000000000000',
    pool: '0xC6962004f452bE9203591991D15f6b388e09E8D0',
    router: '0xE592427A0AEce92De3Edee1F18E0157C05861564',
    asset: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
    quoter: '0x18404De1887654A246e855892B71dFD11e927342',
    assetUsdFeed: '0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612',
    counterAssetUsdFeed: '0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3',
    minDepositAssets: hre.ethers.parseUnits('0.0015', 18),
  }

  const v1 = await hre.upgrades.deployProxy(
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV1_1'),
    [init],
    {
      kind: 'uups',
    },
  )

  console.log('v1 deployed at:', v1.target)

  await v1.setDepositCap(hre.ethers.MaxUint256)
  await v1.setStrategist('0x12D1A136250131E37A607B0b78F6F109BF6a9fa3', true)
  await v1.setDepositFeePips(
    '0x12D1A136250131E37A607B0b78F6F109BF6a9fa3',
    '1000',
  )

  // v2 upgrade
  const v2 = await hre.upgrades.upgradeProxy(
    v1.target,
    await hre.ethers.getContractFactory('OrangeStrykeLPAutomatorV2'),
    {
      kind: 'uups',
      call: {
        fn: 'initializeV2',
        args: ['0xBA12222222228d8Ba445958a75a0704d566BF2C8'], // balancer address
      },
    },
  )

  await v2.setProxyWhitelist('0x3d7B10b11bc939D0730540bF93E1C4172298f845', true)

  const bcV2 = await hre.upgrades.upgradeProxy(
    v2.target,
    await hre.ethers.getContractFactory(
      'BackwardCompatibleOrangeStrykeLPAutomatorV2',
    ),
    {
      kind: 'uups',
      unsafeAllow: ['delegatecall'],
    },
  )

  console.log('v2 upgrade success')

  const bcV2_1 = await hre.upgrades.upgradeProxy(
    v2.target,
    await hre.ethers.getContractFactory(
      'BackwardCompatibleOrangeStrykeLPAutomatorV2_1',
    ),
    {
      kind: 'uups',
      call: {
        fn: 'initializeV2_1',
        args: ['0xbeF87B530713F047C2640149825bc6c973f5A22a'], // pool adapter
      },
      unsafeAllow: ['delegatecall'],
    },
  )

  console.log('v2_1 upgrade success')
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
