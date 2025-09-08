import { privateKeyToAccount } from "viem/accounts"
import {
  createWalletClient as viemCreateWalletClient,
  createPublicClient as viemCreatePublicClient,
  http,
} from "viem"
import { Env } from "./types"
import chain from "./chain"

function createChainClients(env: Env) {
  console.log("Creating Mezo chain clients...")

  const account = privateKeyToAccount(
    env.MAINTAINER_PRIVATE_KEY as `0x${string}`,
  )

  const options = {
    chain: env.MEZO_NETWORK === "mainnet" ? chain.mainnet : chain.testnet,
    transport: http(),
  }

  const walletClient = viemCreateWalletClient({
    account,
    ...options,
  })

  const publicClient = viemCreatePublicClient({
    ...options,
  })

  console.log(`Clients created for the Mezo ${env.MEZO_NETWORK}`)

  return { walletClient, publicClient, account }
}

export default { createChainClients }
