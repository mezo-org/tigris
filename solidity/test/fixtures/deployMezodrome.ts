import { deployments, helpers } from "hardhat"
import { GaugeFactory, Pool, PoolFactory } from "../../typechain"

export default async function deployMezodrome(): Promise<{
  poolImplementation: Pool
  poolFactory: PoolFactory
  gaugeFactory: GaugeFactory
}> {
  await deployments.fixture()

  const poolImplementation = await helpers.contracts.getContract("Pool")
  const poolFactory = await helpers.contracts.getContract("PoolFactory")
  const gaugeFactory = await helpers.contracts.getContract("GaugeFactory")

  return {
    poolImplementation: poolImplementation as unknown as Pool,
    poolFactory: poolFactory as unknown as PoolFactory,
    gaugeFactory: gaugeFactory as unknown as GaugeFactory,
  }
}
