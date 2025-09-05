import context from "./context"
import { Env } from "./types"
import ChainFeeSplitter from "./abis/ChainFeeSplitter"

export default async function splitRewards(env: Env) {
  const { walletClient, publicClient } = context.createChainClients(env)
  const [account] = await walletClient.getAddresses()

  try {
    console.log("Updating period...")

    const { request } = await publicClient.simulateContract({
      account,
      abi: ChainFeeSplitter.abi,
      address: ChainFeeSplitter.address[env.MEZO_NETWORK],
      functionName: "updatePeriod",
    })

    const txHash = await walletClient.writeContract(request)

    console.log(`Successfully updated the period; Transaction hash: ${txHash}`)
  } catch (error) {
    console.error("Failed to update the period", error)
    throw error
  }
}
