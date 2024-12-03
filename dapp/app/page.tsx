'use client'

import { default as DEX } from '@/components/dex'
import { Providers } from '@/components/providers'

export default function Home() {
  return (
    <Providers>
      <DEX />
    </Providers>
  )
}
