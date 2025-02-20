import type { HardhatRuntimeEnvironment } from "hardhat/types"
import type { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { execute } = deployments
  const { deployer, governance } = await getNamedAccounts()

  const veBTCVoter = await deployments.get("VeBTCVoter")
  const RewardsDistributor = await deployments.get("RewardsDistributor")

  // Set roles that were assigned to the deployer within the constructor.

  await execute(
    "VeBTC",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setVoterAndDistributor",
    veBTCVoter.address, // voter
    RewardsDistributor.address, // distributor
  )

  await execute(
    "VeBTC",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setTeam",
    governance,
  )
}

export default func

func.tags = ["SetVeBTCRoles"]
func.dependencies = ["VeBTC", "VeBTCVoter", "RewardsDistributor"]
func.runAtTheEnd = true
