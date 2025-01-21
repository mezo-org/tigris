import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const GaugeFactory = await deployments.getOrNull("GaugeFactory")
  const isValidDeployment =
    GaugeFactory && helpers.address.isValid(GaugeFactory.address)
  if (isValidDeployment) {
    log(`Using GaugeFactory at ${GaugeFactory.address}`)
    return
  }

  log("Deploying GaugeFactory contract...")
  const gaugeFactoryDeployment = await deploy("GaugeFactory", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.tags.etherscan) {
    await helpers.etherscan.verify(gaugeFactoryDeployment)
  }

  if (hre.network.tags.tenderly) {
    await hre.tenderly.verify({
      name: "GaugeFactory",
      address: gaugeFactoryDeployment.address,
    })
  }
}

export default func

func.tags = ["GaugeFactory"]
