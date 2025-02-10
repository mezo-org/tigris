import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const MezoForwarder = await deployments.getOrNull("MezoForwarder")
  const isValidDeployment =
    MezoForwarder && helpers.address.isValid(MezoForwarder.address)
  if (isValidDeployment) {
    log(`Using MezoForwarder at ${MezoForwarder.address}`)
    return
  }

  log("Deploying MezoForwarder contract...")
  const mezoForwarderDeployment = await deploy("MezoForwarder", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(mezoForwarderDeployment)
  }
}

export default func

func.tags = ["MezoForwarder"]
