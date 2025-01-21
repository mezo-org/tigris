import { deployments, helpers } from "hardhat"
import { Pool, PoolFactory } from "../../typechain"

export default async function deployMezodrome(): Promise<{
  poolImplementation: Pool
  poolFactory: PoolFactory
}> {
  await deployments.fixture()

  const poolImplementation = await helpers.contracts.getContract("Pool")
  const poolFactory = await helpers.contracts.getContract("PoolFactory")

  return {
    poolImplementation: poolImplementation as unknown as Pool,
    poolFactory: poolFactory as unknown as PoolFactory,
  }
}
