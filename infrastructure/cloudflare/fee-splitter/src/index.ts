import splitRewards from "./split-rewards"
import { Env } from "./types"

export default {
  async scheduled(controller: { cron: unknown }, env: Env) {
    try {
      switch (controller.cron) {
        // Every Thursday at 00:00.
        case "0 0 * * 4":
          await splitRewards(env)
          break
        default:
          console.log("Task not defined for a given cron")
      }
    } catch (error) {
      console.error("Cron task failed", error)
      throw error
    }

    console.log("Cron processed")
  },
}
