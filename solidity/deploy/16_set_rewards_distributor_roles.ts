import type { HardhatRuntimeEnvironment } from "hardhat/types"
import type { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { execute } = deployments
  const { deployer } = await getNamedAccounts()

  const FeeSplitter = await deployments.get("FeeSplitter")

  // Set roles that were assigned to the deployer within the constructor.

  await execute(
    "RewardsDistributor",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setDepositor",
    FeeSplitter.address,
  )
}

export default func

func.tags = ["SetRewardsDistributorRoles"]
func.dependencies = ["RewardsDistributor", "FeeSplitter"]
func.runAtTheEnd = true
