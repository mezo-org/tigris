import React, { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card"
import { Button } from "./ui/button"
import { Input } from "./ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/select"
import { Alert, AlertDescription } from "./ui/alert"
import { Pool } from "./types"
import { PoolLabel } from "./labels"
import { default as ProtectedButton } from "./protected-button"

const incentiveTokens = [
  {
    address: "0x...1",
    symbol: "BTC",
    name: "Bitcoin",
    decimals: 8,
    balance: "1.25",
    logoURI:
      "data:image/svg+xml," +
      encodeURIComponent(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <rect width="24" height="24" fill="white"/>
        <circle cx="12" cy="12" r="11" fill="#F7931A"/>
        <path d="M16 10.5c.2-1.4-1-2.2-2.2-2.7l.4-1.8-1-.3-.4 1.8-.8-.2.4-1.8-1-.3-.4 1.8-2.1-.5-.3 1.1s.8.2.8.2c.4.1.5.4.5.6l-.5 2.2-.1.3-.8 3.2c0 .2-.2.4-.5.3 0 0-.8-.2-.8-.2l-.5 1.2 2 .5-.4 1.8 1 .3.4-1.8.8.2-.4 1.8 1 .3.4-1.8c1.7.3 3 .2 3.5-1.4.4-1.3 0-2.1-.9-2.6.6-.1 1.1-.5 1.2-1.4zm-2.1 3c-.3 1.1-2.1.5-2.7.4l.5-1.9c.6.1 2.5.4 2.2 1.5zm.3-2.9c-.3 1-1.6.5-2.1.4l.4-1.7c.5.1 1.9.3 1.7 1.3z" fill="white"/>
      </svg>
    `),
  },
  {
    address: "0x...3",
    symbol: "HUH",
    name: "HUH Token",
    decimals: 18,
    balance: "50000",
    logoURI:
      "data:image/svg+xml," +
      encodeURIComponent(`
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        <rect width="24" height="24" fill="white"/>
        <circle cx="12" cy="12" r="11" fill="#6B7280"/>
        <path d="M7 8c0.5-0.5 1.5-0.5 2 0s0.5 1.5 0 2s-1.5 0.5-2 0s-0.5-1.5 0-2z" fill="white"/>
        <path d="M15 8c0.5-0.5 1.5-0.5 2 0s0.5 1.5 0 2s-1.5 0.5-2 0s-0.5-1.5 0-2z" fill="white"/>
        <path d="M12 14c3 0 4 2 4 2l-8 0c0 0 1-2 4-2z" fill="white"/>
        <circle cx="18" cy="18" r="3" fill="#FF6B6B"/>
        <text x="18" y="19" text-anchor="middle" fill="white" style="font-family: system-ui; font-weight: bold; font-size: 4px;">?</text>
      </svg>
    `),
  },
]

const IncentiveTokenOption = ({
  token,
}: {
  token: (typeof incentiveTokens)[0]
}) => (
  <div className="flex items-center justify-between w-full">
    <div className="flex items-center gap-2">
      <div className="w-6 h-6 flex-shrink-0 overflow-hidden rounded-full bg-white shadow-sm">
        <div
          dangerouslySetInnerHTML={{
            __html: decodeURIComponent(token.logoURI.split(",")[1]),
          }}
        />
      </div>
      <div>
        <div className="font-medium">{token.symbol}</div>
        <div className="text-sm text-gray-500">{token.name}</div>
      </div>
    </div>
    <div className="text-sm text-gray-500">Balance: {token.balance}</div>
  </div>
)

const IncentivizeInterface = ({ pools }: { pools: Pool[] }) => {
  const [selectedPool, setSelectedPool] = useState("")
  const [selectedTokenAddress, setSelectedTokenAddress] = useState("")
  const [amount, setAmount] = useState("")
  const [showConfirm, setShowConfirm] = useState(false)

  const selectedPoolData = pools.find((p) => p.id === selectedPool)
  const selectedToken = incentiveTokens.find(
    (t) => t.address === selectedTokenAddress,
  )

  const canProceed =
    selectedPool && selectedTokenAddress && amount && Number(amount) > 0

  return (
    <div className="max-w-4xl mx-auto mt-8">
      <Card>
        <CardHeader>
          <CardTitle>Add Incentives</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">
              Select Pool
            </label>
            <Select value={selectedPool} onValueChange={setSelectedPool}>
              <SelectTrigger>
                <SelectValue placeholder="Select a pool" />
              </SelectTrigger>
              <SelectContent>
                {pools.map((pool) => (
                  <SelectItem key={pool.id} value={pool.id} className="py-2">
                    <PoolLabel pool={pool} />
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">
              Select Token
            </label>
            <Select
              value={selectedTokenAddress}
              onValueChange={setSelectedTokenAddress}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select a token">
                  {selectedToken && (
                    <IncentiveTokenOption token={selectedToken} />
                  )}
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {incentiveTokens.map((token) => (
                  <SelectItem
                    key={token.address}
                    value={token.address}
                    className="py-2"
                  >
                    <IncentiveTokenOption token={token} />
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Amount</label>
            <div className="relative">
              <Input
                type="number"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.0"
              />
              {selectedToken && (
                <div className="absolute right-3 top-1/2 -translate-y-1/2 text-sm text-gray-500">
                  {selectedToken.symbol}
                </div>
              )}
            </div>
            {selectedToken && (
              <div className="mt-1 text-sm text-gray-500">
                Balance: {selectedToken.balance} {selectedToken.symbol}
              </div>
            )}
          </div>

          {!showConfirm ? (
            <Button
              className="w-full"
              onClick={() => setShowConfirm(true)}
              disabled={!canProceed}
            >
              Add Incentive
            </Button>
          ) : (
            <div className="space-y-4">
              <Alert variant="destructive">
                <AlertDescription>
                  <p className="font-medium mb-1">
                    Please confirm your incentive:
                  </p>
                  <ul className="text-sm space-y-1">
                    <li>
                      Pool: {selectedPoolData?.token0.symbol}/
                      {selectedPoolData?.token1.symbol}
                    </li>
                    <li>
                      Amount: {amount} {selectedToken?.symbol}
                    </li>
                    <li>
                      Warning: Adding incentives is permanent. You won't be able
                      to recover these tokens.
                    </li>
                  </ul>
                </AlertDescription>
              </Alert>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  onClick={() => setShowConfirm(false)}
                  className="flex-1"
                >
                  Cancel
                </Button>
                <ProtectedButton variant="destructive" className="flex-1">
                  Confirm
                </ProtectedButton>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

export default IncentivizeInterface
