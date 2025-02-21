/* eslint-disable @typescript-eslint/no-unused-expressions */
// TODO: complains about expect() calls; should probably be disabled globally

import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers"
import {
  EpochGovernor,
  ERC20,
  FactoryRegistry,
  FeeSplitter,
  GaugeFactory,
  ManagedRewardsFactory,
  MezoForwarder,
  Pool,
  PoolFactory,
  RewardsDistributor,
  VeBTC,
  Voter,
  VotingRewardsFactory,
} from "../typechain"
import deployMezodrome from "./fixtures/deployMezodrome"

describe("Mezodrome deployment", () => {
  let governance: SignerWithAddress

  let btc: ERC20
  let poolImplementation: Pool
  let poolFactory: PoolFactory
  let gaugeFactory: GaugeFactory
  let votingRewardsFactory: VotingRewardsFactory
  let managedRewardsFactory: ManagedRewardsFactory
  let factoryRegistry: FactoryRegistry
  let forwarder: MezoForwarder
  let veBTC: VeBTC
  let veBTCVoter: Voter
  let rewardsDistributor: RewardsDistributor
  let feeSplitter: FeeSplitter
  let epochGovernor: EpochGovernor

  before(async () => {
    ;({
      governance,
      btc,
      poolImplementation,
      poolFactory,
      gaugeFactory,
      votingRewardsFactory,
      managedRewardsFactory,
      factoryRegistry,
      forwarder,
      veBTC,
      veBTCVoter,
      rewardsDistributor,
      feeSplitter,
      epochGovernor,
    } = await loadFixture(deployMezodrome))
  })

  it("should resolve the Bitcoin contract", async () => {
    expect(await btc.getAddress()).to.not.be.empty
  })

  it("should deploy the Pool implementation", async () => {
    expect(await poolImplementation.getAddress()).to.not.be.empty
  })

  it("should deploy the PoolFactory", async () => {
    expect(await poolFactory.getAddress()).to.not.be.empty
  })

  it("should wire up the PoolFactory", async () => {
    expect(await poolFactory.implementation()).to.equal(
      await poolImplementation.getAddress(),
    )
  })

  it("should deploy the GaugeFactory", async () => {
    expect(await gaugeFactory.getAddress()).to.not.be.empty
  })

  it("should deploy the VotingRewardsFactory", async () => {
    expect(await votingRewardsFactory.getAddress()).to.not.be.empty
  })

  it("should deploy the ManagedRewardsFactory", async () => {
    expect(await managedRewardsFactory.getAddress()).to.not.be.empty
  })

  it("should deploy the FactoryRegistry", async () => {
    expect(await factoryRegistry.getAddress()).to.not.be.empty
  })

  it("should wire up FactoryRegistry", async () => {
    expect(await factoryRegistry.fallbackPoolFactory()).to.equal(
      await poolFactory.getAddress(),
    )
    expect(await factoryRegistry.fallbackVotingRewardsFactory()).to.equal(
      await votingRewardsFactory.getAddress(),
    )
    expect(await factoryRegistry.fallbackGaugeFactory()).to.equal(
      await gaugeFactory.getAddress(),
    )
  })

  it("should deploy VeBTC", async () => {
    expect(await veBTC.getAddress()).to.not.be.empty
  })

  it("should wire up VeBTC", async () => {
    expect(await veBTC.forwarder()).to.equal(await forwarder.getAddress())
    expect(await veBTC.token()).to.equal(await btc.getAddress())
    expect(await veBTC.factoryRegistry()).to.equal(
      await factoryRegistry.getAddress(),
    )

    expect(await veBTC.voter()).to.equal(await veBTCVoter.getAddress())
    expect(await veBTC.distributor()).to.equal(
      await rewardsDistributor.getAddress(),
    )
    expect(await veBTC.team()).to.equal(await governance.getAddress())
  })

  it("should deploy VeBTCVoter", async () => {
    expect(await veBTCVoter.getAddress()).to.not.be.empty
  })

  it("should wire up VeBTCVoter", async () => {
    expect(await veBTCVoter.forwarder()).to.equal(await forwarder.getAddress())
    expect(await veBTCVoter.ve()).to.equal(await veBTC.getAddress())
    expect(await veBTCVoter.factoryRegistry()).to.equal(
      await factoryRegistry.getAddress(),
    )

    expect(await veBTCVoter.governor()).to.equal(await governance.getAddress())
    expect(await veBTCVoter.epochGovernor()).to.equal(
      await governance.getAddress(),
    )
    expect(await veBTCVoter.emergencyCouncil()).to.equal(
      await governance.getAddress(),
    )
    expect(await veBTCVoter.minter()).to.equal(await feeSplitter.getAddress())
  })

  it("should deploy RewardsDistributor", async () => {
    expect(await rewardsDistributor.getAddress()).to.not.be.empty
  })

  it("should wire up RewardsDistributor", async () => {
    expect(await rewardsDistributor.ve()).to.equal(await veBTC.getAddress())
    expect(await rewardsDistributor.depositor()).to.equal(
      await feeSplitter.getAddress(),
    )
  })

  it("should deploy FeeSplitter", async () => {
    expect(await feeSplitter.getAddress()).to.not.be.empty
  })

  it("should wire up FeeSplitter", async () => {
    expect(await feeSplitter.voter()).to.equal(await veBTCVoter.getAddress())
    expect(await feeSplitter.btc()).to.equal(await btc.getAddress())
    expect(await feeSplitter.rewardsDistributor()).to.equal(
      await rewardsDistributor.getAddress(),
    )
  })

  it("should deploy EpochGovernor", async () => {
    expect(await epochGovernor.getAddress()).to.not.be.empty
  })

  it("should wire up EpochGovernor", async () => {
    expect(await epochGovernor.isTrustedForwarder(forwarder)).to.be.true
    expect(await epochGovernor.token()).to.equal(await veBTC.getAddress())
    expect(await epochGovernor.minter()).to.equal(
      await feeSplitter.getAddress(),
    )
  })
})
