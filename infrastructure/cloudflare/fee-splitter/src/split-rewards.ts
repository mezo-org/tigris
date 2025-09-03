import context from "./context"
import { Env } from "./types"
import ChainFeeSplitter from "./abis/ChainFeeSplitter"

export default async function splitRewards(env: Env) {
  const client = context.createWalletClient(env)

  try {
    console.log("Updating period...")

    const txHash = await client.writeContract({
      abi: ChainFeeSplitter.abi,
      address: ChainFeeSplitter.address[env.MEZO_NETWORK],
      functionName: "updatePeriod",
    })

    console.log(`Successfully updated the period; Transaction hash: ${txHash}`)
  } catch (error) {
    console.error("Failed to update the period", error)
    throw error
  }
}
