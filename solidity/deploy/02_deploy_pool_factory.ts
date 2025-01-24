import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { execute } = deployments
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

  log("Setting the initial stable pool fee to 0.01%...")
  await execute(
    "PoolFactory",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setFee",
    true,
    1,
  )

  log("Setting the initial volatile pool fee to 0.04%...")
  await execute(
    "PoolFactory",
    { from: deployer, log: true, waitConfirmations: 1 },
    "setFee",
    false,
    4,
  )

  // TODO: Pass the governance of the factory once the governance structure
  // contracts are deployed!

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(poolFactoryDeployment)
  }
}

export default func

func.tags = ["PoolFactory"]
func.dependencies = ["Pool"]
