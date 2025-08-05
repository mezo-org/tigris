import { DeployFunction, DeployOptions } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const DAY = 86400
const YEAR = 365 * DAY

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

  const deployOptions: DeployOptions = {
    from: deployer,
    log: true,
    waitConfirmations: 1,
  }

  const balanceDeployment = await deploy("Balance", deployOptions)
  const delegationDeployment = await deploy("Delegation", deployOptions)
  const escrowDeployment = await deploy("Escrow", deployOptions)
  const managedNFTDeployment = await deploy("ManagedNFT", deployOptions)
  const nftDeployment = await deploy("NFT", deployOptions)
  const grantDeployment = await deploy("Grant", {
    libraries: {
      Escrow: escrowDeployment.address,
    },
    ...deployOptions,
  })

  const VeBTC = await deployments.getOrNull("VeBTC")

  const isValidDeployment = VeBTC && helpers.address.isValid(VeBTC.address)
  if (isValidDeployment) {
    log(`Using VeBTC at ${VeBTC.address}`)
    return
  }

  log("Deploying VeBTC contract...")

  // Originally, veBTC used a 4-year maxLockTime and all math-heavy
  // system tests rely on this value. Now, real-world veBTC deployments
  // use a 30-day maxLockTime but, in order to avoid refactoring all
  // the tests, we still use the 4-year maxLockTime for testing.
  const maxLockTime = hre.network.name === "hardhat" ? 4 * YEAR : 30 * DAY

  const [_, veBTCDeployment] = await helpers.upgrades.deployProxy("VeBTC", {
    contractName: "VeBTC",
    initializerArgs: [
      mezoForwarderAddress,
      btcAddress,
      factoryRegistryAddress,
      maxLockTime,
    ],
    factoryOpts: {
      signer: await ethers.getSigner(deployer),
      libraries: {
        Balance: balanceDeployment.address,
        Delegation: delegationDeployment.address,
        Escrow: escrowDeployment.address,
        ManagedNFT: managedNFTDeployment.address,
        NFT: nftDeployment.address,
        Grant: grantDeployment.address,
      },
    },
    proxyOpts: {
      kind: "transparent",
      // Allow external libraries linking. We need to ensure manually that the
      // external  libraries we link are upgrade safe, as the OpenZeppelin plugin
      // doesn't perform such a validation yet.
      // See: https://docs.openzeppelin.com/upgrades-plugins/1.x/faq#why-cant-i-use-external-libraries
      unsafeAllow: ["external-library-linking"],
    },
  })

  if (hre.network.name !== "hardhat") {
    // Verify contract in Blockscout
    await helpers.etherscan.verify(veBTCDeployment)
    await helpers.etherscan.verify(balanceDeployment)
    await helpers.etherscan.verify(delegationDeployment)
    await helpers.etherscan.verify(escrowDeployment)
    await helpers.etherscan.verify(managedNFTDeployment)
    await helpers.etherscan.verify(nftDeployment)
    await helpers.etherscan.verify(grantDeployment)
  }
}

export default func

func.tags = ["VeBTC"]
func.dependencies = ["MezoForwarder", "Bitcoin", "FactoryRegistry"]
