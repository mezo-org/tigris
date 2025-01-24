import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const ManagedRewardsFactory = await deployments.getOrNull(
    "ManagedRewardsFactory",
  )
  const isValidDeployment =
    ManagedRewardsFactory &&
    helpers.address.isValid(ManagedRewardsFactory.address)
  if (isValidDeployment) {
    log(`Using ManagedRewardsFactory at ${ManagedRewardsFactory.address}`)
    return
  }

  log("Deploying ManagedRewardsFactory contract...")
  const managedRewardsFactoryDeployment = await deploy(
    "ManagedRewardsFactory",
    {
      from: deployer,
      args: [],
      log: true,
      waitConfirmations: 1,
    },
  )

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(managedRewardsFactoryDeployment)
  }
}

export default func

func.tags = ["ManagedRewardsFactory"]
