import { deployments, helpers } from "hardhat"
import {
  GaugeFactory,
  Pool,
  PoolFactory,
  VotingRewardsFactory,
} from "../../typechain"

export default async function deployMezodrome(): Promise<{
  poolImplementation: Pool
  poolFactory: PoolFactory
  gaugeFactory: GaugeFactory
  votingRewardsFactory: VotingRewardsFactory
}> {
  await deployments.fixture()

  const poolImplementation = await helpers.contracts.getContract("Pool")
  const poolFactory = await helpers.contracts.getContract("PoolFactory")
  const gaugeFactory = await helpers.contracts.getContract("GaugeFactory")
  const votingRewardsFactory = await helpers.contracts.getContract(
    "VotingRewardsFactory",
  )

  return {
    poolImplementation: poolImplementation as unknown as Pool,
    poolFactory: poolFactory as unknown as PoolFactory,
    gaugeFactory: gaugeFactory as unknown as GaugeFactory,
    votingRewardsFactory:
      votingRewardsFactory as unknown as VotingRewardsFactory,
  }
}
