import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const VotingRewardsFactory = await deployments.getOrNull(
    "VotingRewardsFactory",
  )
  const isValidDeployment =
    VotingRewardsFactory &&
    helpers.address.isValid(VotingRewardsFactory.address)
  if (isValidDeployment) {
    log(`Using VotingRewardsFactory at ${VotingRewardsFactory.address}`)
    return
  }

  log("Deploying VotingRewardsFactory contract...")
  const votingRewardsFactoryDeployment = await deploy("VotingRewardsFactory", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(votingRewardsFactoryDeployment)
  }
}

export default func

func.tags = ["VotingRewardsFactory"]
