import type { HardhatRuntimeEnvironment } from "hardhat/types"
import type { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre
  const { execute } = deployments
  const { deployer } = await getNamedAccounts()

  const ChainFeeSplitter = await deployments.get("ChainFeeSplitter")

  // Set roles that were assigned to the deployer within the constructor.

  await execute(
    "VeBTCRewardsDistributor",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setDepositor",
    ChainFeeSplitter.address,
  )
}

export default func

func.tags = ["SetVeBTCRewardsDistributorRoles"]
func.dependencies = ["VeBTCRewardsDistributor", "ChainFeeSplitter"]
func.runAtTheEnd = true
