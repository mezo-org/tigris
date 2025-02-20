import type { HardhatRuntimeEnvironment } from "hardhat/types"
import type { DeployFunction } from "hardhat-deploy/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const Bitcoin = await deployments.getOrNull("Bitcoin")

  if (Bitcoin && helpers.address.isValid(Bitcoin.address)) {
    log(`Using existing Bitcoin contract at ${Bitcoin.address}`)
  } else {
    if (hre.network.name === "hardhat") {
      // Deploy a test Bitcoin contract on hardhat network to feed test fixtures.
      log("Deploying Bitcoin test contract")

      await deploy("Bitcoin", {
        contract: "TestERC20",
        from: deployer,
        args: ["BTC", "BTC"],
        log: true,
        waitConfirmations: 1,
      })

      return
    }

    // On any other network, we should have a real Bitcoin contract provided
    // as an external deployment.
    throw new Error("Bitcoin contract not found")
  }
}

export default func

func.tags = ["Bitcoin"]
