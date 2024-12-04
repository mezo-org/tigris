import React, { useState } from 'react'
import { Button } from "./ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/select"
import { default as ProtectedButton } from "./protected-button"
import { PoolLabel } from "./labels"
import {  mockLocks, mockPools } from '../mocks'

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

export default VoteInterface
