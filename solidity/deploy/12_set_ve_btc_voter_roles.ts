import type { HardhatRuntimeEnvironment } from "hardhat/types"
import type { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { execute } = deployments
  const { deployer, governance } = await getNamedAccounts()

  // Set roles that were assigned to the deployer within the constructor.

  await execute(
    "VeBTCVoter",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setEpochGovernor",
    governance,
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

  // TODO: There is one more role that must be assigned - minter.
  //       However, this requires adjusting the Minter contract first.
  //       We are leaving this for the future.
}

export default func

func.tags = ["SetVeBTCVoterRoles"]
func.dependencies = ["VeBTCVoter"]
func.runAtTheEnd = true
