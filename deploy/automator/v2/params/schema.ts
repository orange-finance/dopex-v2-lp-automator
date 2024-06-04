import { z } from 'zod'

export const V2Parameters = z.object({
  id: z.string(),
  balancer: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  admin: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
})

export type V2Parameters = z.infer<typeof V2Parameters>
