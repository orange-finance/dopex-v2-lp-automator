import hre from 'hardhat'
import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

// FIXME: gas estimation is broken
export default buildModule('Automator_Arbitrum', (m) => {
  const admin = m.getAccount(0)
  const usdce = m.getParameter('USDC.e')
  const pool = m.getParameter('UniswapV3-WETH-USDC.e')
  const router = m.getParameter('SwapRouter')
  const handler = m.getParameter('UniswapV3SingleTickLiquidityHandler')
  const manager = m.getParameter('DopexV2PositionManager')

  const roleStrategist = hre.ethers.keccak256(
    hre.ethers.toUtf8Bytes('STRATEGIST_ROLE')
  )

  const wethUsdce = m.contract(
    'Automator',
    [
      admin,
      manager,
      handler,
      router,
      pool,
      usdce,
      hre.ethers.parseUnits('10', 6), // 10 USDC
    ],
    {
      id: 'Automator_UniswapV3_WETH_USDCE',
    }
  )

  m.call(wethUsdce, 'setDepositCap', [hre.ethers.parseUnits('100000', 6)]) // 100k USDC
  m.call(wethUsdce, 'grantRole', [
    roleStrategist,
    '0xd31583735e47206e9af728EF4f44f62B20db4b27',
  ])

  return { wethUsdce }
})
