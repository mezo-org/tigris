'use client'

import { default as DEX } from '@/components/dex'
import { Providers } from '@/components/providers'

export default function Home() {
  return (
    <Providers>
      <DEX />
      <a id="bazaar" className="fixed rotate-[270deg] left-0 top-1/2 -translate-y-1/2 translate-x-[-25%] bg-slate-300 hover:bg-slate-200 py-1 px-2" href="/">Finance</a>
    </Providers>
  )
}
