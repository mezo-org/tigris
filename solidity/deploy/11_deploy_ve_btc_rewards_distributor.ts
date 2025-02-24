import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const veBTCAddress = (await deployments.get("VeBTC")).address
  log(`veBTC address is ${veBTCAddress}`)

  const VeBTCRewardsDistributor = await deployments.getOrNull(
    "VeBTCRewardsDistributor",
  )

  const isValidDeployment =
    VeBTCRewardsDistributor &&
    helpers.address.isValid(VeBTCRewardsDistributor.address)
  if (isValidDeployment) {
    log(`Using VeBTCRewardsDistributor at ${VeBTCRewardsDistributor.address}`)
    return
  }

  log("Deploying VeBTCRewardsDistributor contract...")
  const veBTCRewardsDistributorDeployment = await deploy(
    "VeBTCRewardsDistributor",
    {
      contract: "RewardsDistributor",
      from: deployer,
      args: [veBTCAddress],
      log: true,
      waitConfirmations: 1,
    },
  )

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(veBTCRewardsDistributorDeployment)
  }
}

export default func

func.tags = ["VeBTCRewardsDistributor"]
func.dependencies = ["VeBTC"]
