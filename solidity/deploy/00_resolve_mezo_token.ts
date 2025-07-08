import type { HardhatRuntimeEnvironment } from "hardhat/types"
import type { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const mezoToken = await deployments.getOrNull("MEZO")

  if (mezoToken && helpers.address.isValid(mezoToken.address)) {
    log(`Using existing MEZO contract at ${mezoToken.address}`)
  } else {
    if (hre.network.name === "hardhat") {
      // Deploy a test MEZO contract on hardhat network to feed test fixtures.
      log("Deploying MEZO test contract")

      await deploy("MEZO", {
        contract: "TestERC20",
        from: deployer,
        args: ["MEZO", "MEZO"],
        log: true,
        waitConfirmations: 1,
      })

      return
    }

    // On any other network, we should have a real MEZO contract provided
    // as an external deployment.
    throw new Error("MEZO contract not found")
  }
}

export default func

func.tags = ["MEZO"]
