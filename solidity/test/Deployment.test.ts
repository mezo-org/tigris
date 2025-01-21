/* eslint-disable @typescript-eslint/no-unused-expressions */
// TODO: complains about expect() calls; should probably be disabled globally

import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import {
  FactoryRegistry,
  GaugeFactory,
  ManagedRewardsFactory,
  Pool,
  PoolFactory,
  VotingRewardsFactory,
} from "../typechain"
import deployMezodrome from "./fixtures/deployMezodrome"

describe("Mezodrome deployment", () => {
  let poolImplementation: Pool
  let poolFactory: PoolFactory
  let gaugeFactory: GaugeFactory
  let votingRewardsFactory: VotingRewardsFactory
  let managedRewardsFactory: ManagedRewardsFactory
  let factoryRegistry: FactoryRegistry

  before(async () => {
    ;({
      poolImplementation,
      poolFactory,
      gaugeFactory,
      votingRewardsFactory,
      managedRewardsFactory,
      factoryRegistry,
    } = await loadFixture(deployMezodrome))
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
})
