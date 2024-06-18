import { z } from 'zod'

export const Parameters = z.object({
  admin: z.string(),
  trustedProviders: z.object({
    kyberswap: z.string(),
  }),
})

export type Parameters = z.infer<typeof Parameters>
