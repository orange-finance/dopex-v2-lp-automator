import { program } from 'commander'
import axios from 'axios'
import { parseUnits, encodeAbiParameters } from 'viem'

program.requiredOption('-i, --in-token <token>', 'token to swap')
program.requiredOption('-o, --out-token <token>', 'token to receive')
program.requiredOption('-u, --unit <unit>', 'unit of token', 'wei')
program.requiredOption('-a, --amount <amount>', 'amount of token to swap')
program.requiredOption('-s --sender <address>', 'sender address')
program.parse()

const TOKENS = {
  weth: {
    address: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
  },
  usdc: {
    address: '0xaf88d065e77c8cC2239327C5EDb3A432268e5831',
  },
}

async function kyberswap() {
  const { inToken, outToken, amount, sender, unit } = program.opts()

  const it = TOKENS[inToken]
  const ot = TOKENS[outToken]

  if (!it || !ot) throw new Error('Invalid token')

  const client = axios.create({
    baseURL: 'https://aggregator-api.kyberswap.com/arbitrum/api/v1',
    headers: {
      'Content-Type': 'application/json',
    },
  })

  const amountIn = getAmountIn(amount, unit)

  // get swap routes
  const { data: rs } = await client.get('/routes', {
    params: {
      tokenIn: it.address,
      tokenOut: ot.address,
      amountIn: amountIn.toString(),
    },
  })

  // get encoded function data
  const body = {
    routeSummary: rs.data.routeSummary,
    sender: sender,
    recipient: sender,
    slippageTolerance: 10, // 0.1%
  }

  const { data: rbd } = await client.post('/route/build', body)

  const encoded = encodeAbiParameters(
    [{ type: 'address' }, { type: 'bytes' }],
    [rbd.data.routerAddress, rbd.data.data],
  )

  console.log(encoded)
}

function getAmountIn(amount, unit) {
  if (unit === 'wei') return BigInt(amount)

  return parseUnits(amount, unit)
}

kyberswap().catch((e) => {
  if (e instanceof Error) {
    console.error(e.name)
    console.error(e.message)
    console.error(e.stack)

    process.exit(1)
  }

  console.error(e)
  process.exit(1)
})
