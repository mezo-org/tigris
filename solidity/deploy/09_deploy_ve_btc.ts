import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const mezoForwarderAddress = (await deployments.get("MezoForwarder")).address
  log(`MezoForwarder address is ${mezoForwarderAddress}`)

  const btcAddress = (await deployments.get("Bitcoin")).address
  log(`Bitcoin address is ${btcAddress}`)

  const factoryRegistryAddress = (await deployments.get("FactoryRegistry"))
    .address
  log(`FactoryRegistry address is ${factoryRegistryAddress}`)

  const VeBTC = await deployments.getOrNull("VeBTC")

  const isValidDeployment = VeBTC && helpers.address.isValid(VeBTC.address)
  if (isValidDeployment) {
    log(`Using VeBTC at ${VeBTC.address}`)
    return
  }

  log("Deploying VeBTC contract...")
  const veBTCDeployment = await deploy("VeBTC", {
    from: deployer,
    args: [mezoForwarderAddress, btcAddress, factoryRegistryAddress],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(veBTCDeployment)
  }
}

export default func

func.tags = ["VeBTC"]
func.dependencies = ["MezoForwarder", "Bitcoin", "FactoryRegistry"]
