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

  const veBTCRewardsDistributorAddress = (
    await deployments.get("VeBTCRewardsDistributor")
  ).address
  log(`veBTCRewardsDistributor address is ${veBTCRewardsDistributorAddress}`)

  const ChainFeeSplitter = await deployments.getOrNull("ChainFeeSplitter")

  const isValidDeployment =
    ChainFeeSplitter && helpers.address.isValid(ChainFeeSplitter.address)
  if (isValidDeployment) {
    log(`Using ChainFeeSplitter at ${ChainFeeSplitter.address}`)
    return
  }

  // The initial needle should be 60% on real-world chains (mainnet and testnet).
  // However, we maintain 33% for Hardhat network to not break and modify
  // the existing (and math-heavy) system tests.
  const needle = hre.network.name === "hardhat" ? 33 : 60

  log("Deploying ChainFeeSplitter contract...")
  const chainFeeSplitterDeployment = await deploy("ChainFeeSplitter", {
    from: deployer,
    args: [
      veBTCVoterAddress,
      veBTCAddress,
      veBTCRewardsDistributorAddress,
      needle,
    ],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(chainFeeSplitterDeployment)
  }
}

export default func

func.tags = ["ChainFeeSplitter"]
func.dependencies = ["VeBTCVoter", "VeBTC", "VeBTCRewardsDistributor"]
