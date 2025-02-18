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

  const factoryRegistryAddress = (await deployments.get("FactoryRegistry"))
    .address
  log(`FactoryRegistry address is ${factoryRegistryAddress}`)

  const VeBTCVoter = await deployments.getOrNull("VeBTCVoter")

  const isValidDeployment =
    VeBTCVoter && helpers.address.isValid(VeBTCVoter.address)
  if (isValidDeployment) {
    log(`Using VeBTCVoter at ${VeBTCVoter.address}`)
    return
  }

  log("Deploying VeBTCVoter contract...")
  const veBTCVoterDeployment = await deploy("VeBTCVoter", {
    contract: "Voter",
    from: deployer,
    args: [mezoForwarderAddress, veBTCAddress, factoryRegistryAddress],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(veBTCVoterDeployment)
  }
}

export default func

func.tags = ["VeBTCVoter"]
func.dependencies = ["MezoForwarder", "VeBTC", "FactoryRegistry"]
