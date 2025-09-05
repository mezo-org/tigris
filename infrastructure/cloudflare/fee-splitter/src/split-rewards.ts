import context from "./context"
import { Env } from "./types"
import ChainFeeSplitter from "./abis/ChainFeeSplitter"
import updatePeriodTracker from "./update-period-tracker"

export default async function splitRewards(env: Env) {
  const { walletClient, publicClient, account } =
    context.createChainClients(env)
  try {
    console.log("Simulating `updatePeriod` transaction...")

    const { request } = await publicClient.simulateContract({
      account,
      abi: ChainFeeSplitter.abi,
      address: ChainFeeSplitter.address[env.MEZO_NETWORK],
      functionName: "updatePeriod",
    })

    console.log("Simulation completed successfully")

    console.log("Updating period...")

    const txHash = await walletClient.writeContract(request)

    const timestamp = Math.floor(Date.now() / 1_000)

    console.log(`Successfully updated the period; Transaction hash: ${txHash}`)

    updatePeriodTracker.updateLastSuccessfulTransaction(env, timestamp, txHash)
  } catch (error) {
    console.error("Failed to update the period", error)
    throw error
  }
}
