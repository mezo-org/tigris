import {useState} from "react"
import { Lock } from "../types"
import {Card, CardContent, CardHeader, CardTitle} from "./card"
import {Input} from "./input"
import ProtectedButton from "../protected-button"

export const mockLocks: Lock[] = [
  {
    id: 'veBTC-1',
    amount: 1.5,
    endTime: Date.now() + 365 * 24 * 60 * 60 * 1000,
    votingPower: 1.5,
    estimatedAPR: 15.5,
  },
]

export const LockInterface = () => {
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

