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

  // TODO: The initial stable and volatile fees are 0.02%. Is it OK or do we want
  // to update them?

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(poolFactoryDeployment)
  }
}

export default func

func.tags = ["PoolFactory"]
func.dependencies = ["Pool"]
