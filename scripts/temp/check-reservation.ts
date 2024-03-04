import hre from 'hardhat'
import { FullMath, SqrtPriceMath, TickMath, tickToPrice } from '@uniswap/v3-sdk'
import JSBI from 'jsbi'

const PRECISION = JSBI.BigInt('100000000000000000000000000000000') // 1e32

async function main() {
  const vault = await hre.ethers.getContractAt(
    'OrangeDopexV2LPAutomator',
    '0x65Fb7fa8731710b435999cB7d036D689097548e8',
  )

  const hdlV2 = await hre.ethers.getContractAt(
    'IUniswapV3SingleTickLiquidityHandlerV2',
    '0x29BbF7EbB9C5146c98851e76A5529985E4052116',
  )

  const pool = await hre.ethers.getContractAt(
    'IUniswapV3Pool',
    '0xC6962004f452bE9203591991D15f6b388e09E8D0',
  )

  const ticks = await vault.getActiveTicks()

  console.log('tick length:', ticks.length)

  const encoder = hre.ethers.AbiCoder.defaultAbiCoder()

  const { sqrtPriceX96: sqrt } = await pool.slot0()
  const sqrtPriceX96 = JSBI.BigInt(sqrt.toString())

  let usdcTotal = JSBI.BigInt(0)

  const tis = await Promise.all(
    ticks.map(async (tick) => {
      const cd = encoder.encode(
        ['address', 'address', 'int24', 'int24'],
        [
          '0xC6962004f452bE9203591991D15f6b388e09E8D0',
          '0x0000000000000000000000000000000000000000',
          tick,
          tick + 10n,
        ],
      )
      const tid = await hdlV2.getHandlerIdentifier(cd)

      const res = await hdlV2.tokenIds(tid)

      const usdcPrice = FullMath.mulDivRoundingUp(
        JSBI.multiply(sqrtPriceX96, sqrtPriceX96),
        PRECISION,
        JSBI.BigInt(2 ** 192),
      )

      const sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(Number(tick))
      const sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(Number(tick + 10n))

      const { amount0: amountWeth, amount1: amountUsdc } =
        getAmountsForLiquidity(
          sqrtPriceX96,
          sqrtRatioAX96,
          sqrtRatioBX96,
          JSBI.BigInt(res.reservedLiquidity.toString()),
        )

      const wethInUsdc = FullMath.mulDivRoundingUp(
        amountWeth,
        usdcPrice,
        PRECISION,
      )

      const usdcValue = JSBI.add(amountUsdc, wethInUsdc)

      usdcTotal = JSBI.add(usdcTotal, usdcValue)

      return {
        tokenId: hre.ethers.toBeHex(tid),
        tickLower: tick.toString(),
        totalSupply: res.totalSupply.toString(),
        totalLiquidity: res.totalLiquidity.toString(),
        liquidityUsed: res.liquidityUsed.toString(),
        reservedLiquidity: res.reservedLiquidity.toString(),
        usdcValue: usdcValue.toString(),
      }
    }),
  )

  console.log('usdcTotal:', usdcTotal.toString())

  console.log('tokenIdInfo:')
  tis.map((ti) => console.log(JSON.stringify(ti, null, 2)))
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})

function getAmountsForLiquidity(
  sqrtRatioX96: JSBI,
  sqrtRatioAX96: JSBI,
  sqrtRatioBX96: JSBI,
  liquidity: JSBI,
) {
  if (JSBI.greaterThan(sqrtRatioAX96, sqrtRatioBX96)) {
    ;[sqrtRatioAX96, sqrtRatioBX96] = [sqrtRatioBX96, sqrtRatioAX96]
  }

  let amount0 = JSBI.BigInt(0)
  let amount1 = JSBI.BigInt(0)

  if (JSBI.lessThanOrEqual(sqrtRatioX96, sqrtRatioAX96)) {
    amount0 = SqrtPriceMath.getAmount0Delta(
      sqrtRatioAX96,
      sqrtRatioBX96,
      liquidity,
      false,
    )
  } else if (JSBI.lessThan(sqrtRatioX96, sqrtRatioBX96)) {
    amount0 = SqrtPriceMath.getAmount0Delta(
      sqrtRatioX96,
      sqrtRatioBX96,
      liquidity,
      false,
    )
    amount1 = SqrtPriceMath.getAmount1Delta(
      sqrtRatioAX96,
      sqrtRatioX96,
      liquidity,
      false,
    )
  } else {
    amount1 = SqrtPriceMath.getAmount1Delta(
      sqrtRatioAX96,
      sqrtRatioBX96,
      liquidity,
      false,
    )
  }
  return { amount0, amount1 }
}
