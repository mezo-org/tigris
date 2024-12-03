import React, { useState } from 'react'
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { default as ConnectButton } from "@/components/connect-wallet"
import { default as ProtectedButton } from "@/components/protected-button"
import { Pool, Lock } from "./types"
import { PoolLabel } from "./labels"
import { default as IncentivizeInterface } from "./incentivize"
import { default as SwapInterface } from "./swap"
import { default as LiquidityInterface } from "./liquidity"

const mockTokens = [
  {
    address: '0x...1',
    symbol: 'BTC',
    name: 'Bitcoin',
    decimals: 8,
    logoURI: 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(`
                                                                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
                                                                      <rect width="24" height="24" fill="white"/>
                                                                      <circle cx="12" cy="12" r="11" fill="#F7931A"/>
                                                                      <path d="M16 10.5c.2-1.4-1-2.2-2.2-2.7l.4-1.8-1-.3-.4 1.8-.8-.2.4-1.8-1-.3-.4 1.8-2.1-.5-.3 1.1s.8.2.8.2c.4.1.5.4.5.6l-.5 2.2-.1.3-.8 3.2c0 .2-.2.4-.5.3 0 0-.8-.2-.8-.2l-.5 1.2 2 .5-.4 1.8 1 .3.4-1.8.8.2-.4 1.8 1 .3.4-1.8c1.7.3 3 .2 3.5-1.4.4-1.3 0-2.1-.9-2.6.6-.1 1.1-.5 1.2-1.4zm-2.1 3c-.3 1.1-2.1.5-2.7.4l.5-1.9c.6.1 2.5.4 2.2 1.5zm.3-2.9c-.3 1-1.6.5-2.1.4l.4-1.7c.5.1 1.9.3 1.7 1.3z" fill="white"/>
                                                                      </svg>
                                                                      `)
  },
  {
    address: '0x...2',
    symbol: 'mUSD',
    name: 'Mezo USD',
    decimals: 18,
    logoURI: 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <rect width="24" height="24" fill="white"/>
        <circle cx="12" cy="12" r="11" fill="#FF004D"/>
        <path d="M13.5 7.5c1-.8 2.5-1.4 2.5-1.4v2c-.4.2-1.1.5-1.5.8-.7.5-1 1.2-1 2.1 0 .9.4 1.5 1.1 1.9.4.2 1 .4 1.4.5v2c-.9-.2-1.8-.6-2.5-1.1v1.1h-1v-1.1c-.7.5-1.6.9-2.5 1.1v-2c.4-.1.9-.3 1.4-.5.7-.4 1.1-1 1.1-1.9 0-.9-.3-1.6-1-2.1-.4-.3-1-.6-1.5-.8v-2s1.5.6 2.5 1.4V6.5h1v1zm-1 3.9c.3.2.4.5.4.9s-.1.7-.4.9c-.2.1-.4.2-.6.3-.2-.1-.4-.2-.6-.3-.3-.2-.4-.5-.4-.9s.1-.7.4-.9c.2-.1.4-.2.6-.3.2.1.4.2.6.3z" fill="white"/>
      </svg>
    `)
  },
  {
    address: '0x...3',
    symbol: 'HUH',
    name: 'HUH Token',
    decimals: 18,
    logoURI: 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <rect width="24" height="24" fill="white"/>
        <circle cx="12" cy="12" r="11" fill="#6B7280"/>
        <path d="M7 8c0.5-0.5 1.5-0.5 2 0s0.5 1.5 0 2s-1.5 0.5-2 0s-0.5-1.5 0-2z" fill="white"/>
        <path d="M15 8c0.5-0.5 1.5-0.5 2 0s0.5 1.5 0 2s-1.5 0.5-2 0s-0.5-1.5 0-2z" fill="white"/>
        <path d="M12 14c3 0 4 2 4 2l-8 0c0 0 1-2 4-2z" fill="white"/>
        <circle cx="18" cy="18" r="3" fill="#FF6B6B"/>
        <text x="18" y="19" text-anchor="middle" fill="white" style="font-family: system-ui; font-weight: bold; font-size: 4px;">?</text>
      </svg>
    `)
  },
  {
    address: '0x...4',
    symbol: 'LOLA',
    name: 'LOLA',
    decimals: 18,
    logoURI: 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <rect width="24" height="24" fill="white"/>
        <circle cx="12" cy="12" r="11" fill="#000000"/>
        <path d="M12 6L17 18H7L12 6z" fill="white"/>
      </svg>
    `)
  },
  {
    address: '0x...5',
    symbol: 'T',
    name: 'Threshold',
    decimals: 18,
    logoURI: 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <rect width="24" height="24" fill="white"/>
        <circle cx="12" cy="12" r="11" fill="#1CD8D2"/>
        <path d="M8 8h8v2h-3v7h-2v-7h-3v-2z" fill="white"/>
      </svg>
    `)
  },
  {
    address: '0x...6',
    symbol: 'thUSD',
    name: 'Threshold USD',
    decimals: 18,
    logoURI: 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <rect width="24" height="24" fill="white"/>
        <circle cx="12" cy="12" r="11" fill="#1CD8D2"/>
        <path d="M7 9h10v1.5h-4v6h-2v-6h-4v-1.5z" fill="white"/>
        <path d="M12.5 13.5c1-.8 2-1.2 2-1.2v1.5c-.3.2-.8.4-1.2.6-.5.4-.8.9-.8 1.6 0 .7.3 1.2.9 1.5.3.2.7.3 1.1.4v1.5c-.7-.2-1.4-.5-2-.9v.9h-.8v-.9c-.6.4-1.3.7-2 .9v-1.5c.3-.1.7-.2 1.1-.4.5-.3.9-.8.9-1.5 0-.7-.3-1.2-.8-1.6-.4-.2-.9-.4-1.2-.6v-1.5s1 .4 2 1.2v-1.1h.8v1.1z" fill="white"/>
      </svg>
    `)
  },
  {
    address: '0x...7',
    symbol: 'solvBTC',
    name: 'Solvent BTC',
    decimals: 8,
    logoURI: 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <rect width="24" height="24" fill="white"/>
        <circle cx="12" cy="12" r="11" fill="#0066FF"/>
        <path d="M16 10.5c.2-1.4-1-2.2-2.2-2.7l.4-1.8-1-.3-.4 1.8-.8-.2.4-1.8-1-.3-.4 1.8-2.1-.5-.3 1.1s.8.2.8.2c.4.1.5.4.5.6l-.5 2.2-.1.3-.8 3.2c0 .2-.2.4-.5.3 0 0-.8-.2-.8-.2l-.5 1.2 2 .5-.4 1.8 1 .3.4-1.8.8.2-.4 1.8 1 .3.4-1.8c1.7.3 3 .2 3.5-1.4.4-1.3 0-2.1-.9-2.6.6-.1 1.1-.5 1.2-1.4zm-2.1 3c-.3 1.1-2.1.5-2.7.4l.5-1.9c.6.1 2.5.4 2.2 1.5zm.3-2.9c-.3 1-1.6.5-2.1.4l.4-1.7c.5.1 1.9.3 1.7 1.3z" fill="white"/>
      </svg>
    `)
  },
]

const mockPools: Pool[] = [
  {
    id: 'btc-musd-stable',
    token0: mockTokens.find(t => t.symbol === 'BTC')!,
    token1: mockTokens.find(t => t.symbol === 'mUSD')!,
    isStable: true,
    fee: 0.01,
    volume24h: 1000000,
    tvl: 5000000,
    baseAPY: 12.5,
    matsAPY: 8.3,
    votes: 1500,
    lpBalance: 0.5,
    hasIncentives: true,
  },
  {
    id: 'btc-musd-volatile',
    token0: mockTokens.find(t => t.symbol === 'BTC')!,
    token1: mockTokens.find(t => t.symbol === 'mUSD')!,
    isStable: false,
    fee: 0.03,
    volume24h: 2000000,
    tvl: 3000000,
    baseAPY: 15.5,
    matsAPY: 10.3,
    votes: 2500,
    lpBalance: 0,
    hasIncentives: false,
  },
  {
    id: 'huh-btc',
    token0: mockTokens.find(t => t.symbol === 'HUH')!,
    token1: mockTokens.find(t => t.symbol === 'BTC')!,
    isStable: false,
    fee: 0.03,
    volume24h: 500000,
    tvl: 1000000,
    baseAPY: 25.5,
    matsAPY: 15.3,
    votes: 800,
    lpBalance: 0.1,
    hasIncentives: true,
  },
  {
    id: 'huh-musd',
    token0: mockTokens.find(t => t.symbol === 'HUH')!,
    token1: mockTokens.find(t => t.symbol === 'mUSD')!,
    isStable: false,
    fee: 0.03,
    volume24h: 300000,
    tvl: 800000,
    baseAPY: 30.5,
    matsAPY: 20.3,
    votes: 600,
    lpBalance: 0,
    hasIncentives: true,
  },
  {
    id: 'thusd-musd',
    token0: mockTokens.find(t => t.symbol === 'thUSD')!,
    token1: mockTokens.find(t => t.symbol === 'mUSD')!,
    isStable: true,
    fee: 0.01,
    volume24h: 1500000,
    tvl: 4000000,
    baseAPY: 8.5,
    matsAPY: 5.3,
    votes: 1200,
    lpBalance: 0,
    hasIncentives: false,
  },
  {
    id: 'solvbtc-btc',
    token0: mockTokens.find(t => t.symbol === 'solvBTC')!,
    token1: mockTokens.find(t => t.symbol === 'BTC')!,
    isStable: true,
    fee: 0.01,
    volume24h: 800000,
    tvl: 2500000,
    baseAPY: 10.5,
    matsAPY: 7.3,
    votes: 900,
    lpBalance: 0.2,
    hasIncentives: true,
  },
  {
    id: 'lola-btc',
    token0: mockTokens.find(t => t.symbol === 'LOLA')!,
    token1: mockTokens.find(t => t.symbol === 'BTC')!,
    isStable: false,
    fee: 0.03,
    volume24h: 400000,
    tvl: 1200000,
    baseAPY: 20.5,
    matsAPY: 12.3,
    votes: 700,
    lpBalance: 0,
    hasIncentives: false,
  },
  {
    id: 't-btc',
    token0: mockTokens.find(t => t.symbol === 'T')!,
    token1: mockTokens.find(t => t.symbol === 'BTC')!,
    isStable: false,
    fee: 0.03,
    volume24h: 600000,
    tvl: 1500000,
    baseAPY: 18.5,
    matsAPY: 11.3,
    votes: 1000,
    lpBalance: 0.3,
    hasIncentives: true,
  },
]

const mockLocks: Lock[] = [
  {
    id: 'veBTC-1',
    amount: 1.5,
    endTime: Date.now() + 365 * 24 * 60 * 60 * 1000,
    votingPower: 1.5,
    estimatedAPR: 15.5,
  },
]

const LockInterface = () => {
  const [amount, setAmount] = useState('')
  const [duration, setDuration] = useState('52')
  const maxDuration = 208 // 4 years in weeks

  return (
    <div className="max-w-4xl mx-auto mt-8 space-y-6">
      <div className="grid grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Create New Lock</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-1">Amount (BTC)</label>
              <Input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.0"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">Lock Duration (weeks)</label>
              <Input
                type="range"
                min="1"
                max={maxDuration}
                value={duration}
                onChange={(e) => setDuration(e.target.value)}
              />
              <div className="mt-1 text-sm text-gray-500">
                {duration} weeks ({(Number(duration) / 52).toFixed(1)} years)
              </div>
            </div>
            <ProtectedButton className="w-full">Create Lock</ProtectedButton>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Your Voting Power</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold mb-2">
              {mockLocks.reduce((acc, lock) => acc + lock.votingPower, 0)} veBTC
            </div>
            <div className="text-sm text-gray-500">
              Total locked value: {mockLocks.reduce((acc, lock) => acc + lock.amount, 0)} BTC
            </div>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Active Locks</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left border-b">
                  <th className="pb-2">Lock ID</th>
                  <th className="pb-2">Amount</th>
                  <th className="pb-2">Time Remaining</th>
                  <th className="pb-2">Voting Power</th>
                  <th className="pb-2">Est. APR</th>
                </tr>
              </thead>
              <tbody>
                {mockLocks.map(lock => (
                  <tr key={lock.id} className="border-b">
                    <td className="py-3">{lock.id}</td>
                    <td className="py-3">{lock.amount} BTC</td>
                    <td className="py-3">
                      {Math.ceil((lock.endTime - Date.now()) / (1000 * 60 * 60 * 24))} days
                    </td>
                    <td className="py-3">{lock.votingPower} veBTC</td>
                    <td className="py-3">{lock.estimatedAPR}%</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

const VoteInterface = () => {
  const [filter, setFilter] = useState<'all' | 'balance' | 'incentives'>('all')
  const [poolTypeFilter, setPoolTypeFilter] = useState<'all' | 'stable' | 'volatile'>('all')
  const [showVotedOnly, setShowVotedOnly] = useState(false)

  const totalVotingPower = mockLocks.reduce((acc, lock) => acc + lock.votingPower, 0)

  const filteredPools = mockPools.filter(pool => {
    if (poolTypeFilter !== 'all' && pool.isStable !== (poolTypeFilter === 'stable')) return false
    if (filter === 'balance' && !pool.lpBalance) return false
    if (filter === 'incentives' && !pool.hasIncentives) return false
    if (showVotedOnly && !pool.votes) return false
    return true
  })

  return (
    <div className="max-w-4xl mx-auto mt-8 space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Your Voting Power</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-3xl font-bold">{totalVotingPower} veBTC</div>
        </CardContent>
      </Card>

      <div className="flex justify-between items-center">
        <div className="space-x-2">
          <Button
            variant={poolTypeFilter === 'all' ? "default" : "outline"}
            onClick={() => setPoolTypeFilter('all')}
          >
            All
          </Button>
          <Button
            variant={poolTypeFilter === 'stable' ? "default" : "outline"}
            onClick={() => setPoolTypeFilter('stable')}
          >
            Stable
          </Button>
          <Button
            variant={poolTypeFilter === 'volatile' ? "default" : "outline"}
            onClick={() => setPoolTypeFilter('volatile')}
          >
            Volatile
          </Button>
        </div>

        <div className="space-x-2">
          <Select value={filter} onValueChange={(value: any) => setFilter(value)}>
            <SelectTrigger className="w-[180px]">
              <SelectValue placeholder="Filter pools" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Pools</SelectItem>
              <SelectItem value="balance">My Pools</SelectItem>
              <SelectItem value="incentives">With Incentives</SelectItem>
            </SelectContent>
          </Select>
          <label className="inline-flex items-center">
            <input
              type="checkbox"
              className="rounded border-gray-300"
              checked={showVotedOnly}
              onChange={(e) => setShowVotedOnly(e.target.checked)}
            />
            <span className="ml-2">Voted Only</span>
          </label>
        </div>
      </div>

      <Card>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left border-b">
                  <th className="pb-2 w-[300px]">Pool</th>
                  <th className="pb-2">TVL</th>
                  <th className="pb-2">Your LP</th>
                  <th className="pb-2">Votes</th>
                  <th className="pb-2">Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredPools.map(pool => (
                  <tr key={pool.id} className="border-b">
                    <td className="py-3">
                      <PoolLabel pool={pool} />
                    </td>
                    <td className="py-3">${pool.tvl.toLocaleString()}</td>
                    <td className="py-3">{pool.lpBalance ? `${pool.lpBalance} LP` : '-'}</td>
                    <td className="py-3">{pool.votes.toLocaleString()} veBTC</td>
                    <td className="py-3">
                      <ProtectedButton size="sm">Vote</ProtectedButton>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

const App = () => {
  return (
    <div className="min-h-screen bg-gray-50">
      <header className="border-b bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex h-16 items-center justify-between">
            <span className="text-2xl font-bold text-blue-600">MEZODROME</span>
            <ConnectButton />
          </div>
        </div>
      </header>
      <main>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <Tabs defaultValue="swap" className="mt-4">
            <TabsList className="grid w-full grid-cols-5">
              <TabsTrigger value="swap">Swap</TabsTrigger>
              <TabsTrigger value="liquidity">Liquidity</TabsTrigger>
              <TabsTrigger value="vote">Vote</TabsTrigger>
              <TabsTrigger value="lock">Lock</TabsTrigger>
              <TabsTrigger value="incentivize">Incentivize</TabsTrigger>
            </TabsList>
            <TabsContent value="swap">
              <SwapInterface tokens={mockTokens} />
            </TabsContent>
            <TabsContent value="liquidity">
              <LiquidityInterface pools={mockPools} tokens={mockTokens} />
            </TabsContent>
            <TabsContent value="vote">
              <VoteInterface />
            </TabsContent>
            <TabsContent value="lock">
              <LockInterface />
            </TabsContent>
            <TabsContent value="incentivize">
              <IncentivizeInterface pools={mockPools} />
            </TabsContent>
          </Tabs>
        </div>
      </main>
    </div>
  )
}

export default App
