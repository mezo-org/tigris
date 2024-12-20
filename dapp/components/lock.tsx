import { useState } from "react"
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
} from "recharts"
import { Copy } from "lucide-react"
import { Lock } from "./types"
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card"
import { Input } from "./ui/input"
import { Button } from "./ui/button"
import ProtectedButton from "./protected-button"

// Mock lock duration data
const lockData = [
  { duration: "1 week", btcLocked: 25 },
  { duration: "1 month", btcLocked: 75 },
  { duration: "3 months", btcLocked: 150 },
  { duration: "6 months", btcLocked: 125 },
  { duration: "1 year", btcLocked: 85 },
  { duration: "2 years", btcLocked: 30 },
  { duration: "4 years", btcLocked: 10 },
]

// Mock delegation suggestions
const popularDelegates = [
  { name: "alice.mezo", address: "0x1234...5678" },
  { name: "bob.mezo", address: "0x2345...6789" },
  { name: "charlie.mezo", address: "0x3456...7890" },
  { name: "indexcoop.mezo", address: "0x4567...8901" },
  { name: "treasury.mezo", address: "0x5678...9012" },
  { name: "snapshot.mezo", address: "0x6789...0123" },
]

const DelegationCard = ({
  title,
  description,
  currentDelegate,
  onDelegate,
}: {
  title: string
  description: string
  currentDelegate: string | null
  onDelegate: (delegate: string) => void
}) => {
  const [delegateInput, setDelegateInput] = useState("")

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <p className="text-sm text-gray-500">{description}</p>

        {currentDelegate && (
          <div className="p-3 bg-gray-50 rounded-lg flex items-center justify-between">
            <span className="text-sm">
              Currently delegated to: {currentDelegate}
            </span>
            <Button variant="ghost" size="sm" onClick={() => onDelegate("")}>
              Clear
            </Button>
          </div>
        )}

        <div className="space-y-2">
          <label className="text-sm font-medium">Delegate to</label>
          <div className="flex gap-2">
            <Input
              placeholder="address or name.mezo"
              value={delegateInput}
              onChange={(e) => setDelegateInput(e.target.value)}
            />
            <ProtectedButton onClick={() => onDelegate(delegateInput)}>
              Delegate
            </ProtectedButton>
          </div>
        </div>

        <div className="space-y-2">
          <label className="text-sm font-medium">Popular Delegates</label>
          <div className="grid grid-cols-2 gap-2">
            {popularDelegates.map((delegate) => (
              <Button
                key={delegate.address}
                variant="outline"
                className="justify-between"
                onClick={() => onDelegate(delegate.name)}
              >
                <span>{delegate.name}</span>
                <Copy className="h-4 w-4 text-gray-500" />
              </Button>
            ))}
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

export const LockInterface = ({ locks }: { locks: Lock[] }) => {
  const [votingDelegate, setVotingDelegate] = useState<string | null>(null)
  const [stakingDelegate, setStakingDelegate] = useState<string | null>(null)

  return (
    <div className="max-w-4xl mx-auto mt-8 space-y-6">
      {/* Statistics Cards */}
      <div className="grid grid-cols-3 gap-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-lg">Total veBTC</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">250 veBTC</div>
            <p className="text-sm text-gray-500">From 500 BTC locked</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-lg">Average Lock Time</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">2 Years</div>
            <p className="text-sm text-gray-500">50% of max boost</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-lg">Your Locks</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold">
              {locks.reduce((acc, lock) => acc + lock.votingPower, 0)} veBTC
            </div>
            <p className="text-sm text-gray-500">
              From {locks.reduce((acc, lock) => acc + lock.amount, 0)} BTC
              locked
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Active Locks Table */}
      <Card>
        <CardHeader>
          <CardTitle>Your Active Locks</CardTitle>
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
                {locks.map((lock) => (
                  <tr key={lock.id} className="border-b">
                    <td className="py-3">{lock.id}</td>
                    <td className="py-3">{lock.amount} BTC</td>
                    <td className="py-3">
                      {Math.ceil(
                        (lock.endTime - Date.now()) / (1000 * 60 * 60 * 24),
                      )}{" "}
                      days
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

      {/* Lock Distribution Chart */}
      <Card>
        <CardHeader>
          <CardTitle>Lock Duration Distribution</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={lockData}>
                <XAxis dataKey="duration" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="btcLocked" fill="#FF004D" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </CardContent>
      </Card>

      {/* Create New Lock Form */}
      <Card>
        <CardHeader>
          <CardTitle>Create New Lock</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">
              Amount (BTC)
            </label>
            <Input type="number" placeholder="0.0" />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">
              Lock Duration
            </label>
            <div className="grid grid-cols-4 gap-2">
              {["1 Year", "2 Years", "3 Years", "4 Years"].map((duration) => (
                <Button key={duration} variant="outline">
                  {duration}
                </Button>
              ))}
            </div>
          </div>
          <ProtectedButton className="w-full">Create Lock</ProtectedButton>
        </CardContent>
      </Card>

      {/* Delegation Controls */}
      <div className="grid grid-cols-2 gap-6">
        <DelegationCard
          title="Voting Power Delegation"
          description="Delegate your voting power to another address. They will be able to vote with your veBTC balance."
          currentDelegate={votingDelegate}
          onDelegate={setVotingDelegate}
        />

        <DelegationCard
          title="Staking Power Delegation"
          description="Delegate your staking power to another address. They will earn rewards on your behalf."
          currentDelegate={stakingDelegate}
          onDelegate={setStakingDelegate}
        />
      </div>
    </div>
  )
}

export default LockInterface
