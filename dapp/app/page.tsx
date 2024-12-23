"use client"

import { Providers } from "@/components/providers"
import SwapInterface from "@/components/swap"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { ConnectButton } from "@rainbow-me/rainbowkit"
import { default as StakeInterface } from "@/components/stake"
import { default as SimpleBorrowInterface } from "@/components/simple-borrow"
import { default as DepositInterface } from "@/components/deposit"
import { mockTokens } from "@/mocks"

export default function Cathedral() {
  return (
    <Providers>
      <div className="min-h-screen bg-gray-50">
        <header className="border-b bg-white">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex h-16 items-center justify-between">
              <span className="text-2xl font-bold text-[#FF004D]">Mezo</span>
              <ConnectButton />
            </div>
          </div>
        </header>
        <main>
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <Tabs defaultValue="borrow" className="mt-4">
              <TabsList className="grid w-full grid-cols-4">
                <TabsTrigger value="borrow">Borrow</TabsTrigger>
                <TabsTrigger value="stake">Stake</TabsTrigger>
                <TabsTrigger value="swap">Swap</TabsTrigger>
                <TabsTrigger value="deposit">Deposit</TabsTrigger>
              </TabsList>
              <TabsContent value="swap">
                <SwapInterface tokens={mockTokens} />
              </TabsContent>
              <TabsContent value="stake">
                <StakeInterface />
              </TabsContent>
              <TabsContent value="borrow">
                <SimpleBorrowInterface />
              </TabsContent>
              <TabsContent value="deposit">
                <DepositInterface />
              </TabsContent>
            </Tabs>
          </div>
          <a
            id="bazaar"
            className="fixed rotate-[270deg] right-0 top-1/2 -translate-y-1/2 translate-x-[25%] bg-slate-300 hover:bg-slate-200 py-1 px-2"
            href="/bazaar"
          >
            Bazaar
          </a>
        </main>
      </div>
    </Providers>
  )
}
