import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const veBTCAddress = (await deployments.get("VeBTC")).address
  log(`veBTC address is ${veBTCAddress}`)

  const RewardsDistributor = await deployments.getOrNull("RewardsDistributor")

  const isValidDeployment =
    RewardsDistributor && helpers.address.isValid(RewardsDistributor.address)
  if (isValidDeployment) {
    log(`Using RewardsDistributor at ${RewardsDistributor.address}`)
    return
  }

  log("Deploying RewardsDistributor contract...")
  const rewardsDistributorDeployment = await deploy("RewardsDistributor", {
    from: deployer,
    args: [veBTCAddress],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(rewardsDistributorDeployment)
  }
}

export default func

func.tags = ["RewardsDistributor"]
func.dependencies = ["VeBTC"]
