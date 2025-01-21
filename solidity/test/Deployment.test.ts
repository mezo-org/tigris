/* eslint-disable @typescript-eslint/no-unused-expressions */
// TODO: complains about expect() calls; should probably be disabled globally

import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import {
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

  before(async () => {
    ;({ 
      poolImplementation,
      poolFactory,
      gaugeFactory,
      votingRewardsFactory,
      managedRewardsFactory
    } = await loadFixture(deployMezodrome))
  })

  it("should deploy the Pool implementation", async () => {
    expect(await poolImplementation.getAddress()).to.not.be.empty
  })

  it("should deploy the PoolFactory", async () => {
    expect(await poolFactory.getAddress()).to.not.be.empty
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
})
