import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  log("Deploying PoolFactory contract...")
  const poolAddress = (await deployments.get("Pool")).address

  const poolFactory = await deploy("PoolFactory", {
    from: deployer,
    args: [poolAddress],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.tags.etherscan) {
    await helpers.etherscan.verify(poolFactory)
  }

  if (hre.network.tags.tenderly) {
    await hre.tenderly.verify({
      name: "PoolFactory",
      address: poolFactory.address,
    })
  }
}

export default func

func.tags = ["PoolFactory"]
func.dependencies = ["Pool"]