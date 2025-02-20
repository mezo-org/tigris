import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const veBTCVoterAddress = (await deployments.get("VeBTCVoter")).address
  log(`veBTCVoter address is ${veBTCVoterAddress}`)

  const veBTCAddress = (await deployments.get("VeBTC")).address
  log(`veBTC address is ${veBTCAddress}`)

  const rewardsDistributorAddress = (
    await deployments.get("RewardsDistributor")
  ).address
  log(`RewardsDistributor address is ${rewardsDistributorAddress}`)

  const FeeSplitter = await deployments.getOrNull("FeeSplitter")

  const isValidDeployment =
    FeeSplitter && helpers.address.isValid(FeeSplitter.address)
  if (isValidDeployment) {
    log(`Using FeeSplitter at ${FeeSplitter.address}`)
    return
  }

  log("Deploying FeeSplitter contract...")
  const feeSplitterDeployment = await deploy("FeeSplitter", {
    from: deployer,
    args: [veBTCVoterAddress, veBTCAddress, rewardsDistributorAddress],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(feeSplitterDeployment)
  }
}

export default func

func.tags = ["FeeSplitter"]
func.dependencies = ["VeBTCVoter", "VeBTC", "RewardsDistributor"]
