import { z } from 'zod'

export const V1_1Parameters = z.object({
  id: z.string(),
  pool: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  router: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  handler: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  hook: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  manager: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  asset: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  counterAsset: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  symbol: z.string(),
  minDepositAssets: z.string(),
  unit: z.number(),
  assetUsdFeed: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  counterAssetUsdFeed: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  admin: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  strategist: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  depositFeePips: z.string(),
  quoterType: z.enum(['chainlink', 'twap']),
})

export type V1_1Parameters = z.infer<typeof V1_1Parameters>
