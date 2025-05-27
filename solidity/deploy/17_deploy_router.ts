import type { HardhatRuntimeEnvironment } from "hardhat/types"
import type { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const mezoForwarderAddress = (await deployments.get("MezoForwarder")).address
  log(`MezoForwarder address is ${mezoForwarderAddress}`)

  const factoryRegistryAddress = (await deployments.get("FactoryRegistry"))
    .address
  log(`FactoryRegistry address is ${factoryRegistryAddress}`)

  const poolFactoryAddress = (await deployments.get("PoolFactory")).address
  log(`PoolFactory address is ${poolFactoryAddress}`)

  const Router = await deployments.getOrNull("Router")

  const isValidDeployment = Router && helpers.address.isValid(Router.address)
  if (isValidDeployment) {
    log(`Using Router at ${Router.address}`)
    return
  }

  log("Deploying Router contract...")
  const routerDeployment = await deploy("Router", {
    from: deployer,
    args: [
      mezoForwarderAddress,
      factoryRegistryAddress,
      poolFactoryAddress
    ],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(routerDeployment)
  }
}

export default func

func.tags = ["Router"]
func.dependencies = [
  "MezoForwarder",
  "FactoryRegistry",
  "PoolFactory",
]
