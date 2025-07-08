import { DeployFunction, DeployOptions } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts, helpers } = hre
  const { log } = deployments
  const { deployer, governance, grantManager } = await getNamedAccounts()

  const mezoGrantFactory = await deployments.getOrNull("MezoGrantFactory")

  const isValidDeployment =
    mezoGrantFactory && helpers.address.isValid(mezoGrantFactory.address)
  if (isValidDeployment) {
    log(`Using MEZO Grant Factory at ${mezoGrantFactory.address}`)
    return
  }

  log("Deploying MEZO Grant Factory contract...")

  const mezoToken = await deployments.get("MEZO")
  const veMEZO = await deployments.get("VeMEZO")
  const tokenGrantImplementation = await deployments.get("TokenGrant")

  const [_, mezoGrantFactoryDeployment] = await helpers.upgrades.deployProxy(
    "MezoGrantFactory",
    {
      contractName: "MezoGrantFactory",
      initializerArgs: [
        mezoToken,
        veMEZO,
        grantManager,
        tokenGrantImplementation,
      ],
      factoryOpts: {
        signer: await ethers.getSigner(deployer),
      },
      proxyOpts: {
        kind: "transparent",
        initialOwner: governance,
      },
    },
  )

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(mezoGrantFactoryDeployment)
  }
}

export default func

func.tags = ["MezoGrantFactory"]
func.dependencies = ["MEZO", "VeMEZO", "TokenGrant"]
