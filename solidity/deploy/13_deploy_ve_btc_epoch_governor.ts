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

  const chainFeeSplitterAddress = (await deployments.get("ChainFeeSplitter"))
    .address
  log(`ChainFeeSplitter address is ${chainFeeSplitterAddress}`)

  const VeBTCEpochGovernor = await deployments.getOrNull("VeBTCEpochGovernor")

  const isValidDeployment =
    VeBTCEpochGovernor && helpers.address.isValid(VeBTCEpochGovernor.address)
  if (isValidDeployment) {
    log(`Using VeBTCEpochGovernor at ${VeBTCEpochGovernor.address}`)
    return
  }

  log("Deploying VeBTCEpochGovernor contract...")
  const veBTCEpochGovernorDeployment = await deploy("VeBTCEpochGovernor", {
    contract: "EpochGovernor",
    from: deployer,
    args: [mezoForwarderAddress, veBTCAddress, chainFeeSplitterAddress],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(veBTCEpochGovernorDeployment)
  }
}

export default func

func.tags = ["VeBTCEpochGovernor"]
func.dependencies = ["MezoForwarder", "VeBTC", "ChainFeeSplitter"]
