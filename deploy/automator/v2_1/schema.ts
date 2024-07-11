import { z } from 'zod'

export const V2_1Parameters = z.object({
  id: z.string(),
  poolAdapter: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  admin: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
})

export type V2_1Parameters = z.infer<typeof V2_1Parameters>
