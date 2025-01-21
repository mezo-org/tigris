import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const PoolFactory = await deployments.getOrNull("PoolFactory")
  const isValidDeployment =
    PoolFactory && helpers.address.isValid(PoolFactory.address)
  if (isValidDeployment) {
    log(`Using PoolFactory at ${PoolFactory.address}`)
    return
  }

  log("Deploying PoolFactory contract...")
  const poolAddress = (await deployments.get("Pool")).address

  const poolFactoryDeployment = await deploy("PoolFactory", {
    from: deployer,
    args: [poolAddress],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.tags.etherscan) {
    await helpers.etherscan.verify(poolFactoryDeployment)
  }

  if (hre.network.tags.tenderly) {
    await hre.tenderly.verify({
      name: "PoolFactory",
      address: poolFactoryDeployment.address,
    })
  }
}

export default func

func.tags = ["PoolFactory"]
func.dependencies = ["Pool"]
