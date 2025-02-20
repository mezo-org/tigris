import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const mezoForwarderAddress = (await deployments.get("MezoForwarder")).address
  log(`MezoForwarder address is ${mezoForwarderAddress}`)

  const btcAddress = (await deployments.get("Bitcoin")).address
  log(`Bitcoin address is ${btcAddress}`)

  const factoryRegistryAddress = (await deployments.get("FactoryRegistry"))
    .address
  log(`FactoryRegistry address is ${factoryRegistryAddress}`)

  const balanceLogicLibraryDeployment = await deploy("BalanceLogicLibrary", {
    from: deployer,
    log: true,
    waitConfirmations: 1,
  })

  const delegationLogicLibraryDeployment = await deploy(
    "DelegationLogicLibrary",
    {
      from: deployer,
      log: true,
      waitConfirmations: 1,
    },
  )

  const VeBTC = await deployments.getOrNull("VeBTC")

  const isValidDeployment = VeBTC && helpers.address.isValid(VeBTC.address)
  if (isValidDeployment) {
    log(`Using VeBTC at ${VeBTC.address}`)
    return
  }

  log("Deploying VeBTC contract...")
  const [_, veBTCDeployment] = await helpers.upgrades.deployProxy("VeBTC", {
    contractName: "VeBTC",
    initializerArgs: [mezoForwarderAddress, btcAddress, factoryRegistryAddress],
    factoryOpts: {
      signer: await ethers.getSigner(deployer),
      libraries: {
        BalanceLogicLibrary: balanceLogicLibraryDeployment.address,
        DelegationLogicLibrary: delegationLogicLibraryDeployment.address,
      },
    },
    proxyOpts: {
      kind: "transparent",
      constructorArgs: [mezoForwarderAddress],
    },
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(veBTCDeployment)
    await helpers.etherscan.verify(balanceLogicLibraryDeployment)
    await helpers.etherscan.verify(delegationLogicLibraryDeployment)
  }
}

export default func

func.tags = ["VeBTC"]
func.dependencies = ["MezoForwarder", "Bitcoin", "FactoryRegistry"]
