import splitRewards from "./split-rewards"
import { Env } from "./types"
import updatePeriodTracker from "./update-period-tracker"

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)

    if (url.pathname === "/metrics") {
      const { timestamp } =
        await updatePeriodTracker.getLastSuccessfulTransaction(env)

      const metrics =
        "# HELP last_update_period Timestamp of the last successfully completed transaction.\n" +
        "# TYPE last_update_period gauge\n" +
        `last_update_period ${timestamp}`

      return new Response(metrics, {
        headers: {
          "Content-Type": "text/plain; version=0.0.4; charset=utf-8",
        },
      })
    }

    return new Response("OK")
  },
  async scheduled(controller: { cron: unknown }, env: Env) {
    try {
      switch (controller.cron) {
        // Every Thursday at 00:10.
        case "10 0 * * 4":
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
