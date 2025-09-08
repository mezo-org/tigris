import feeSplitter from "./fee-splitter"
import { Env } from "./types"

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)

    if (url.pathname === "/metrics") {

      const activePeriod = await feeSplitter.getActivePeriod(env)

      const metrics =
        "# HELP active_period Start time of currently active epoch in UNIX timestamp.\n" +
        "# TYPE active_period gauge\n" +
        `active_period ${activePeriod}`

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
          await feeSplitter.splitRewards(env)
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
