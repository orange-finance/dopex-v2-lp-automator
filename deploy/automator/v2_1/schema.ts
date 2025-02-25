import { z } from 'zod'

export const V2_1Parameters = z.object({
  id: z.string(),
  poolAdapterId: z.string(),
  // poolFee: z.union([z.literal('500'), z.literal('3000'), z.literal('10000')]),
  admin: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
})

export type V2_1Parameters = z.infer<typeof V2_1Parameters>
