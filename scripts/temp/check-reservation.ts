import hre from 'hardhat'
async function main() {
  const vault = await hre.ethers.getContractAt(
    'OrangeDopexV2LPAutomator',
    '0x65Fb7fa8731710b435999cB7d036D689097548e8',
  )

  const hdlV2 = await hre.ethers.getContractAt(
    'IUniswapV3SingleTickLiquidityHandlerV2',
    '0x29BbF7EbB9C5146c98851e76A5529985E4052116',
  )

  const ticks = await vault.getActiveTicks()

  const encoder = hre.ethers.AbiCoder.defaultAbiCoder()

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

      return {
        tokenId: hre.ethers.toBeHex(tid),
        tickLower: tick.toString(),
        totalSupply: res.totalSupply.toString(),
        totalLiquidity: res.totalLiquidity.toString(),
        liquidityUsed: res.liquidityUsed.toString(),
        reservedLiquidity: res.reservedLiquidity.toString(),
      }
    }),
  )

  tis.map((ti) => console.log(JSON.stringify(ti, null, 2)))
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
