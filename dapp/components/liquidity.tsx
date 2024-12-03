import React, { useEffect, useMemo, useState } from 'react'
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Dialog, DialogContent, DialogTrigger } from "@/components/ui/dialog"
import { Plus } from "lucide-react"
import { default as ProtectedButton } from "@/components/protected-button"
import { Token, Pool } from "./types"
import { PoolLabel, TokenIcon, TokenOption, StabilityBadge } from "./labels"

const AddLiquidityForm = ({ pools, tokens } : { pools: Pool[], tokens: Token[] }) => {
  const [token0, setToken0] = useState<Token | null>(null)
  const [token1, setToken1] = useState<Token | null>(null)
  const [poolName, setPoolName] = useState('')
  const [isStable, setIsStable] = useState(false)
  const [fee, setFee] = useState('')

  // Reset pool settings when tokens change
  useEffect(() => {
    if (token0 && token1) {
      setPoolName(`${token0.symbol}-${token1.symbol} Pool`)
    }
  }, [token0, token1])

  // Find existing pools for selected tokens
  const existingPools = useMemo(() => {
    if (!token0 || !token1) return []
    return pools.filter(pool =>
      (pool.token0.address === token0.address && pool.token1.address === token1.address) ||
      (pool.token0.address === token1.address && pool.token1.address === token0.address)
    )
  }, [token0, token1])

  // Fee options based on pool type
  const feeOptions = isStable
    ? [
        { value: '0.0001', label: '0.01%' },
        { value: '0.0005', label: '0.05%' },
        { value: '0.001', label: '0.1%' },
      ]
    : [
        { value: '0.001', label: '0.1%' },
        { value: '0.0025', label: '0.25%' },
        { value: '0.005', label: '0.5%' },
        { value: '0.01', label: '1%' },
      ]

  // Step 1: Token Selection
  if (!token0 || !token1) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Add Liquidity</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Token 1</label>
            <Select
              value={token0?.address}
              onValueChange={(value) => {
                const newToken = tokens.find(t => t.address === value)
                setToken0(newToken || null)
                if (newToken && token1 && newToken.address === token1.address) {
                  setToken1(null)
                }
              }}
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select first token">
                  {token0 && <TokenOption token={token0} />}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {tokens.map(token => (
                  <SelectItem
                    key={token.address}
                    value={token.address}
                    className="py-2"
                    disabled={token1?.address === token.address}
                  >
                    <TokenOption token={token} />
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Token 2</label>
            <Select
              value={token1?.address}
              onValueChange={(value) => {
                const newToken = tokens.find(t => t.address === value)
                setToken1(newToken || null)
                if (newToken && token0 && newToken.address === token0.address) {
                  setToken0(null)
                }
              }}
            >
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select second token">
                  {token1 && <TokenOption token={token1} />}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {tokens.map(token => (
                  <SelectItem
                    key={token.address}
                    value={token.address}
                    className="py-2"
                    disabled={token0?.address === token.address}
                  >
                    <TokenOption token={token} />
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>
    )
  }

  // Step 2: Show existing pools or new pool form
  return (
    <Card>
      <CardHeader>
        <CardTitle>Add Liquidity</CardTitle>
        <div className="flex items-center gap-2 mt-2">
          <TokenIcon token={token0} />
          <TokenIcon token={token1} />
          <span className="text-sm text-gray-500">
            {token0.symbol}/{token1.symbol}
          </span>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => { setToken0(null); setToken1(null); }}
          >
            Change
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-6">
        {existingPools.length > 0 ? (
          <>
            <div className="space-y-4">
              <h3 className="font-medium">Existing Pools</h3>
              {existingPools.map(pool => (
                <div key={pool.id} className="p-4 border rounded-lg space-y-2">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <StabilityBadge isStable={pool.isStable} />
                      <span className="text-sm text-gray-500">
                        Fee: {(pool.fee * 100).toFixed(2)}%
                      </span>
                    </div>
                    <ProtectedButton size="sm">New Deposit</ProtectedButton>
                  </div>
                  <div className="text-sm text-gray-500">
                    TVL: ${pool.tvl.toLocaleString()} •
                    Volume (24h): ${pool.volume24h.toLocaleString()} •
                    APY: {(pool.baseAPY + pool.matsAPY).toFixed(2)}%
                  </div>
                </div>
              ))}
            </div>
          </>
        ) : (
          <div className="space-y-4">
            <h3 className="font-medium">Create New Pool</h3>

            <div>
              <label className="block text-sm font-medium mb-1">Pool Name</label>
              <Input
                value={poolName}
                onChange={(e) => setPoolName(e.target.value)}
                placeholder="Enter pool name"
              />
            </div>

            <div>
              <label className="block text-sm font-medium mb-2">Pool Type</label>
              <div className="flex gap-2">
                <Button
                  variant={isStable ? "default" : "outline"}
                  onClick={() => { setIsStable(true); setFee(''); }}
                  className="flex-1"
                >
                  Stable
                </Button>
                <Button
                  variant={!isStable ? "default" : "outline"}
                  onClick={() => { setIsStable(false); setFee(''); }}
                  className="flex-1"
                >
                  Volatile
                </Button>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Fee Rate</label>
              <Select value={fee} onValueChange={setFee}>
                <SelectTrigger>
                  <SelectValue placeholder="Select fee rate" />
                </SelectTrigger>
                <SelectContent>
                  {feeOptions.map(option => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="pt-4">
              <ProtectedButton className="w-full">
                Create Pool
              </ProtectedButton>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

const LiquidityInterface = ({ pools, tokens } : { pools: Pool[], tokens: Token[] }) => {
  const [filter, setFilter] = useState<'all' | 'stable' | 'volatile'>('all')
  const [sortBy, setSortBy] = useState<'volume' | 'tvl' | 'apy'>('tvl')

  const filteredPools = pools.filter(pool => {
    if (filter === 'stable') return pool.isStable
    if (filter === 'volatile') return !pool.isStable
    return true
  })

  return (
    <div className="max-w-4xl mx-auto mt-8 space-y-6">
      <div className="flex justify-between items-center">
        <Dialog>
          <DialogTrigger asChild>
            <Button className="gap-2">
              <Plus className="h-4 w-4" />
              Add Liquidity
            </Button>
          </DialogTrigger>
          <DialogContent className="sm:max-w-[600px]">
            <AddLiquidityForm pools={pools} tokens={tokens} />
          </DialogContent>
        </Dialog>

        <div className="space-x-2">
          <Button
            variant={filter === 'all' ? "default" : "outline"}
            onClick={() => setFilter('all')}
          >
            All
          </Button>
          <Button
            variant={filter === 'stable' ? "default" : "outline"}
            onClick={() => setFilter('stable')}
          >
            Stable
          </Button>
          <Button
            variant={filter === 'volatile' ? "default" : "outline"}
            onClick={() => setFilter('volatile')}
          >
            Volatile
          </Button>
        </div>

        <Select value={sortBy} onValueChange={(value: any) => setSortBy(value)}>
          <SelectTrigger className="w-[180px]">
            <SelectValue placeholder="Sort by" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="volume">Volume</SelectItem>
            <SelectItem value="tvl">TVL</SelectItem>
            <SelectItem value="apy">APY</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Your Liquidity Positions</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-gray-500">No active positions found</p>
        </CardContent>
      </Card>

      <Card>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left border-b">
                  <th className="pb-2 w-[300px]">Pool</th>
                  <th className="pb-2">Fee</th>
                  <th className="pb-2">Volume (24h)</th>
                  <th className="pb-2">TVL</th>
                  <th className="pb-2">APY</th>
                </tr>
              </thead>
              <tbody>
                {filteredPools.map(pool => (
                  <tr key={pool.id} className="border-b">
                    <td className="py-3">
                      <PoolLabel pool={pool} />
                    </td>
                    <td className="py-3">{(pool.fee * 100).toFixed(2)}%</td>
                    <td className="py-3">${pool.volume24h.toLocaleString()}</td>
                    <td className="py-3">${pool.tvl.toLocaleString()}</td>
                    <td className="py-3">
                      <div>
                        <div className="font-medium">{(pool.baseAPY + pool.matsAPY).toFixed(2)}%</div>
                        <div className="text-xs text-gray-500">
                          Base: {pool.baseAPY.toFixed(2)}% + MATS: {pool.matsAPY.toFixed(2)}%
                        </div>
                      </div>
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

export default LiquidityInterface
