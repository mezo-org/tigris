import context from "./context"
import { Env } from "./types"
import ChainFeeSplitter from "./abis/ChainFeeSplitter"

async function splitRewards(env: Env) {
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

    console.log(`Successfully updated the period; Transaction hash: ${txHash}`)
  } catch (error) {
    console.error("Failed to update the period", error)
    throw error
  }
}

async function getActivePeriod(env: Env) {
  const { publicClient } = context.createChainClients(env)

  return publicClient.readContract({
    abi: ChainFeeSplitter.abi,
    address: ChainFeeSplitter.address[env.MEZO_NETWORK],
    functionName: "activePeriod",
  })
}

export default { 
  getActivePeriod,
  splitRewards,
}
