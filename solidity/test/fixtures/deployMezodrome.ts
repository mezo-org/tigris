import { deployments, helpers } from "hardhat"
import {
  FactoryRegistry,
  GaugeFactory,
  ManagedRewardsFactory,
  Pool,
  PoolFactory,
  VotingRewardsFactory,
} from "../../typechain"

export default async function deployMezodrome(): Promise<{
  poolImplementation: Pool
  poolFactory: PoolFactory
  gaugeFactory: GaugeFactory
  votingRewardsFactory: VotingRewardsFactory
  managedRewardsFactory: ManagedRewardsFactory
  factoryRegistry: FactoryRegistry
}> {
  await deployments.fixture()

  const poolImplementation = await helpers.contracts.getContract("Pool")
  const poolFactory = await helpers.contracts.getContract("PoolFactory")
  const gaugeFactory = await helpers.contracts.getContract("GaugeFactory")
  const votingRewardsFactory = await helpers.contracts.getContract(
    "VotingRewardsFactory",
  )
  const managedRewardsFactory = await helpers.contracts.getContract(
    "ManagedRewardsFactory",
  )
  const factoryRegistry = await helpers.contracts.getContract("FactoryRegistry")

  return {
    poolImplementation: poolImplementation as unknown as Pool,
    poolFactory: poolFactory as unknown as PoolFactory,
    gaugeFactory: gaugeFactory as unknown as GaugeFactory,
    votingRewardsFactory:
      votingRewardsFactory as unknown as VotingRewardsFactory,
    managedRewardsFactory:
      managedRewardsFactory as unknown as ManagedRewardsFactory,
    factoryRegistry: factoryRegistry as unknown as FactoryRegistry,
  }
}
