import type { HardhatRuntimeEnvironment } from "hardhat/types"
import type { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { execute } = deployments
  const { deployer, governance } = await getNamedAccounts()

  const VeBTCEpochGovernor = await deployments.get("VeBTCEpochGovernor")
  const ChainFeeSplitter = await deployments.get("ChainFeeSplitter")

  // Set roles that were assigned to the deployer within the constructor.

  await execute(
    "VeBTCVoter",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setEpochGovernor",
    VeBTCEpochGovernor.address,
  )

  await execute(
    "VeBTCVoter",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setGovernor",
    governance,
  )

  await execute(
    "VeBTCVoter",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setEmergencyCouncil",
    governance,
  )

  await execute(
    "VeBTCVoter",
    { from: deployer, log: true, waitConfirmations: 1 },
    "initialize",
    [], // no initial whitelisted tokens
    ChainFeeSplitter.address,
  )
}

export default func

func.tags = ["SetVeBTCVoterRoles"]
func.dependencies = ["VeBTCVoter", "VeBTCEpochGovernor", "ChainFeeSplitter"]
func.runAtTheEnd = true
