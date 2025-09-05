import { Hex } from "viem"
import { Env } from "./types"

const KEY = "last_update"

async function updateLastSuccessfulTransaction(
  env: Env,
  timestamp: number,
  txHash: Hex,
) {
  console.log(
    `Saving the last successful transaction to KV... Timestamp: ${timestamp}, txHash: ${txHash}`,
  )
  await env.UPDATE_TRACKER.put(KEY, timestamp.toString(), {
    metadata: { txHash },
  })

  console.log(
    `Successfully saved data to KV. Timestamp: ${timestamp}, txHash: ${txHash}`,
  )
}

async function getLastSuccessfulTransaction(env: Env) {
  console.log("Reading the last successful transaction data from KV...")
  const result = await env.UPDATE_TRACKER.getWithMetadata(KEY)
  console.log("Successfully fetched data from KV.")

  const timestamp = result.value ? Number(result.value) : 0

  return { timestamp, metadata: result.metadata }
}

export default {
  updateLastSuccessfulTransaction,
  getLastSuccessfulTransaction,
}
