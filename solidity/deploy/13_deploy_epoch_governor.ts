import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const mezoForwarderAddress = (await deployments.get("MezoForwarder")).address
  log(`MezoForwarder address is ${mezoForwarderAddress}`)

  const veBTCAddress = (await deployments.get("VeBTC")).address
  log(`veBTC address is ${veBTCAddress}`)

  const feeSplitterAddress = (await deployments.get("FeeSplitter")).address
  log(`FeeSplitter address is ${feeSplitterAddress}`)

  const EpochGovernor = await deployments.getOrNull("EpochGovernor")

  const isValidDeployment =
    EpochGovernor && helpers.address.isValid(EpochGovernor.address)
  if (isValidDeployment) {
    log(`Using EpochGovernor at ${EpochGovernor.address}`)
    return
  }

  log("Deploying EpochGovernor contract...")
  const epochGovernorDeployment = await deploy("EpochGovernor", {
    from: deployer,
    args: [mezoForwarderAddress, veBTCAddress, feeSplitterAddress],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(epochGovernorDeployment)
  }
}

export default func

func.tags = ["EpochGovernor"]
func.dependencies = ["MezoForwarder", "VeBTC", "FeeSplitter"]
