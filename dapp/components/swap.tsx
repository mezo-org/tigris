import React, { useState } from 'react'
import { ArrowDown } from 'lucide-react'
import { Button } from "./ui/button"
import { Input } from "./ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/select"
import { default as ProtectedButton } from "./protected-button"
import { Token } from "./types"
import { TokenOption } from "./labels"

const SwapInterface = ({ tokens } : { tokens: Token[] }) => {
  const [fromToken, setFromToken] = useState<Token>(tokens[0])
  const [toToken, setToToken] = useState<Token>(tokens[1])
  const [fromAmount, setFromAmount] = useState('')
  const [toAmount, setToAmount] = useState('')

  // Mock rate of 20000 USDC per BTC
  const getExchangeRate = (tokenA: Token, tokenB: Token) => {
    if (tokenA.symbol === 'BTC' && tokenB.symbol === 'mUSD') return 20000
    if (tokenA.symbol === 'mUSD' && tokenB.symbol === 'BTC') return 1/20000
    return 1 // Default rate for other pairs
  }

  const updateToAmount = (amount: string, from: Token, to: Token) => {
    if (!amount) {
      setToAmount('')
      return
    }
    const rate = getExchangeRate(from, to)
    setToAmount((Number(amount) * rate).toFixed(to.decimals))
  }

  const handleSwitch = () => {
    setFromToken(toToken)
    setToToken(fromToken)
    // Update amounts based on new token order
    if (fromAmount) {
      updateToAmount(fromAmount, toToken, fromToken)
    }
  }

  const handleFromAmountChange = (value: string) => {
    setFromAmount(value)
    updateToAmount(value, fromToken, toToken)
  }

  return (
    <Card className="max-w-md mx-auto mt-8">
      <CardContent className="pt-6">
        <div className="space-y-4">
          <div className="space-y-2">
            <label className="block text-sm font-medium">From</label>
            <div className="flex gap-2">
              <Select
                value={fromToken.address}
                onValueChange={(value) => {
                  const newToken = tokens.find(t => t.address === value) || tokens[0]
                  setFromToken(newToken)
                  if (fromAmount) {
                    updateToAmount(fromAmount, newToken, toToken)
                  }
                }}
              >
                <SelectTrigger className="w-[200px]">
                  <SelectValue>
                    <TokenOption token={fromToken} />
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {tokens.map(token => (
                    <SelectItem key={token.address} value={token.address} className="py-2">
                      <TokenOption token={token} />
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Input
                type="number"
                placeholder="0.0"
                value={fromAmount}
                onChange={(e) => handleFromAmountChange(e.target.value)}
              />
            </div>
          </div>

          <div className="flex justify-center">
            <Button
              variant="ghost"
              size="icon"
              onClick={handleSwitch}
              className="hover:bg-gray-100 transition-colors"
            >
              <ArrowDown className="h-4 w-4" />
            </Button>
          </div>

          <div className="space-y-2">
            <label className="block text-sm font-medium">To</label>
            <div className="flex gap-2">
              <Select
                value={toToken.address}
                onValueChange={(value) => {
                  const newToken = tokens.find(t => t.address === value) || tokens[1]
                  setToToken(newToken)
                  if (fromAmount) {
                    updateToAmount(fromAmount, fromToken, newToken)
                  }
                }}
              >
                <SelectTrigger className="w-[200px]">
                  <SelectValue>
                    <TokenOption token={toToken} />
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {tokens.map(token => (
                    <SelectItem key={token.address} value={token.address} className="py-2">
                      <TokenOption token={token} />
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <div className="flex-1 p-2 bg-gray-100 rounded-md text-sm">
                {toAmount || '0.0'} {toToken.symbol}
              </div>
            </div>
          </div>

          <ProtectedButton className="w-full">Swap</ProtectedButton>
        </div>
      </CardContent>
    </Card>
  )
}

export default SwapInterface
