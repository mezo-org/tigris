import { privateKeyToAccount } from "viem/accounts"
import { createWalletClient as viemCreateWalletClient, http } from "viem"
import { Env } from "./types"
import chain from "./chain"

function createWalletClient(env: Env) {
  console.log("Creating wallet client...")

  const account = privateKeyToAccount(
    env.MAINTAINER_PRIVATE_KEY as `0x${string}`,
  )

  const client = viemCreateWalletClient({
    account,
    chain: env.MEZO_NETWORK === "mainnet" ? chain.mainnet : chain.testnet,
    transport: http(),
  })

  console.log(`Wallet client created for the Mezo ${env.MEZO_NETWORK}`)

  return client
}

export default { createWalletClient }
