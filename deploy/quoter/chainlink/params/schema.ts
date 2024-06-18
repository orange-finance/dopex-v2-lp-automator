import { z } from 'zod'

export const Parameters = z.object({
  admin: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  l2SequencerUptimeFeed: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  stalenessThresholds: z.array(
    z.object({
      feed: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
      threshold: z.number(),
    }),
  ),
})

export type Parameters = z.infer<typeof Parameters>
