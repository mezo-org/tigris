import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const Pool = await deployments.getOrNull("Pool")
  const isValidDeployment = Pool && helpers.address.isValid(Pool.address)
  if (isValidDeployment) {
    log(`Using Pool at ${Pool.address}`)
    return
  }

  log("Deploying Pool contract...")
  const poolDeployment = await deploy("Pool", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.tags.etherscan) {
    await helpers.etherscan.verify(poolDeployment)
  }

  if (hre.network.tags.tenderly) {
    await hre.tenderly.verify({
      name: "Pool",
      address: poolDeployment.address,
    })
  }
}

export default func

func.tags = ["Pool"]
