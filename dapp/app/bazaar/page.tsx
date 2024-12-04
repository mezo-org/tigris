"use client"

import React, { useState } from 'react'
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { default as ConnectButton } from "@/components/connect-wallet"
import { default as IncentivizeInterface } from "@/components/incentivize"
import { default as SwapInterface } from "@/components/swap"
import { default as LiquidityInterface } from "@/components/liquidity"
import { default as LockInterface } from '@/components/lock'
import { default as VoteInterface } from "@/components/vote"
import { default as BorrowInterface } from "@/components/borrow"
import { mockLocks, mockPools, mockTokens } from '@/mocks'
import { Providers } from "@/components/providers"

export default function Bazaar() {
  return (
    <Providers>
      <div className="min-h-screen bg-[rgb(36,20,27)]">
        <header className="border-b bg-[rgb(195,66,87)]">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex h-16 items-center justify-between">
              <span className="text-2xl font-bold text-white">MEZODROME</span>
              <ConnectButton />
            </div>
          </div>
        </header>
        <main>
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <Tabs defaultValue="liquidity" className="mt-4">
              <TabsList className="grid w-full grid-cols-5">
                <TabsTrigger value="liquidity">Liquidity</TabsTrigger>
                <TabsTrigger value="stake">Stake</TabsTrigger>
                <TabsTrigger value="borrow">Borrow</TabsTrigger>
                <TabsTrigger value="vote">Vote</TabsTrigger>
                <TabsTrigger value="incentivize">Incentivize</TabsTrigger>
              </TabsList>
              <TabsContent value="liquidity">
                <LiquidityInterface pools={mockPools} tokens={mockTokens} />
              </TabsContent>
             <TabsContent value="stake">
                <LockInterface locks={mockLocks} />
              </TabsContent>
              <TabsContent value="borrow">
                <BorrowInterface />
              </TabsContent>
              <TabsContent value="vote">
                <VoteInterface />
              </TabsContent>
              <TabsContent value="incentivize">
                <IncentivizeInterface pools={mockPools} />
              </TabsContent>
            </Tabs>
          </div>
        </main>
      </div>
      <a id="bazaar" className="fixed rotate-[270deg] left-0 top-1/2 -translate-y-1/2 translate-x-[-25%] bg-slate-300 hover:bg-slate-200 py-1 px-2" href="/">Finance</a>
    </Providers>
  )
}
