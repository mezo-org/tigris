import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { Chain } from 'viem'

export const mezoChain: Chain = {
  id: 1_337_802, // Example chain ID for Mezo
  name: 'Mezo',
  nativeCurrency: {
    decimals: 8,
    name: 'Bitcoin',
    symbol: 'BTC',
  },
  rpcUrls: {
    default: {
      http: ['https://rpc.mezo.org'], // Replace with actual RPC URL
    },
    public: {
      http: ['https://rpc.mezo.org'], // Replace with actual RPC URL
    },
  },
  blockExplorers: {
    default: { name: 'MezoScan', url: 'https://scan.mezo.org' }, // Replace with actual explorer
  },
  testnet: true,
}

export const config = getDefaultConfig({
  appName: "Mezodrome",
  projectId: "YOUR_PROJECT_ID",
  chains: [mezoChain],
  ssr: true, // If your dApp uses server side rendering (SSR)
});
