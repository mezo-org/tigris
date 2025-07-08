import { DeployFunction, DeployOptions } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { log } = deployments
  const { deployer } = await getNamedAccounts()

  const deployOptions: DeployOptions = {
    from: deployer,
    log: true,
    waitConfirmations: 1,
  }

  let tokenGrant = await deployments.getOrNull("TokenGrant")
  if (tokenGrant && helpers.address.isValid(tokenGrant.address)) {
    log(`Using Token Grant at ${tokenGrant.address}`)
    return
  }
  log("Deploying Token Grant contract...")

  tokenGrant = await deployments.deploy("TokenGrant", deployOptions)

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(tokenGrant)
  }
}

export default func

func.tags = ["TokenGrant"]
func.dependencies = []
