import { Chain, defineChain } from "viem"

const mezoTestnet: Chain = defineChain({
  id: 31611,
  name: "Mezo Testnet",
  network: "mezo-testnet",
  nativeCurrency: {
    decimals: 18,
    name: "Bitcoin",
    symbol: "BTC",
  },
  rpcUrls: {
    public: {
      http: ["https://rpc.test.mezo.org"],
      webSocket: ["wss://rpc-ws.test.mezo.org"],
    },
    default: {
      http: ["https://rpc.test.mezo.org"],
      webSocket: ["wss://rpc-ws.test.mezo.org"],
    },
  },
  blockExplorers: {
    default: {
      name: "Mezo Testnet Explorer",
      url: "https://explorer.test.mezo.org",
    },
  },
  contracts: {
    multicall3: {
      address: "0xcA11bde05977b3631167028862bE2a173976CA11",
      blockCreated: 3669328,
    },
  },
  testnet: true,
})

const mezoMainnet: Chain = defineChain({
  id: 31612,
  name: "Mezo",
  network: "mezo-mainnet",
  nativeCurrency: {
    decimals: 18,
    name: "Bitcoin",
    symbol: "BTC",
  },
  rpcUrls: {
    public: {
      http: ["https://rpc-internal.mezo.org"],
      webSocket: ["wss://rpc-ws-internal.mezo.org"],
    },
    default: {
      http: ["https://rpc-internal.mezo.org"],
      webSocket: ["wss://rpc-ws-internal.mezo.org"],
    },
  },
  blockExplorers: {
    default: {
      name: "Mezo Explorer",
      url: "https://explorer.mezo.org",
    },
  },
  contracts: {
    multicall3: {
      address: "0xcA11bde05977b3631167028862bE2a173976CA11",
      blockCreated: 351760,
    },
  },
})

export default { mainnet: mezoMainnet, testnet: mezoTestnet }
