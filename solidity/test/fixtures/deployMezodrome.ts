import { deployments, helpers } from "hardhat"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import {
  ERC20,
  FactoryRegistry,
  GaugeFactory,
  ManagedRewardsFactory,
  MezoForwarder,
  Pool,
  PoolFactory,
  VeBTC,
  Voter,
  VotingRewardsFactory,
} from "../../typechain"

export default async function deployMezodrome(): Promise<{
  deployer: SignerWithAddress
  governance: SignerWithAddress
  btc: ERC20
  poolImplementation: Pool
  poolFactory: PoolFactory
  gaugeFactory: GaugeFactory
  votingRewardsFactory: VotingRewardsFactory
  managedRewardsFactory: ManagedRewardsFactory
  factoryRegistry: FactoryRegistry
  forwarder: MezoForwarder
  veBTC: VeBTC
  veBTCVoter: Voter
}> {
  await deployments.fixture()

  const { deployer, governance } = await helpers.signers.getNamedSigners()

  const btc = await helpers.contracts.getContract("Bitcoin")
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
  const fowarder = await helpers.contracts.getContract("MezoForwarder")
  const veBTC = await helpers.contracts.getContract("VeBTC")
  const veBTCVoter = await helpers.contracts.getContract("VeBTCVoter")

  return {
    deployer,
    governance,
    btc: btc as unknown as ERC20,
    poolImplementation: poolImplementation as unknown as Pool,
    poolFactory: poolFactory as unknown as PoolFactory,
    gaugeFactory: gaugeFactory as unknown as GaugeFactory,
    votingRewardsFactory:
      votingRewardsFactory as unknown as VotingRewardsFactory,
    managedRewardsFactory:
      managedRewardsFactory as unknown as ManagedRewardsFactory,
    factoryRegistry: factoryRegistry as unknown as FactoryRegistry,
    forwarder: fowarder as unknown as MezoForwarder,
    veBTC: veBTC as unknown as VeBTC,
    veBTCVoter: veBTCVoter as unknown as Voter,
  }
}
