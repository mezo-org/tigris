import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  const FactoryRegistry = await deployments.getOrNull("FactoryRegistry")
  const isValidDeployment =
    FactoryRegistry && helpers.address.isValid(FactoryRegistry.address)
  if (isValidDeployment) {
    log(`Using FactoryRegistry at ${FactoryRegistry.address}`)
    return
  }

  log("Deploying FactoryRegistry contract...")
  const poolFactoryAddress = (await deployments.get("PoolFactory")).address
  const votingRewardsFactoryAddress = (
    await deployments.get("VotingRewardsFactory")
  ).address
  const gaugeFactoryAddress = (await deployments.get("GaugeFactory")).address
  const managedRewardsFactoryAddress = (
    await deployments.get("ManagedRewardsFactory")
  ).address

  const factoryRegistryDeployment = await deploy("FactoryRegistry", {
    from: deployer,
    args: [
      poolFactoryAddress,
      votingRewardsFactoryAddress,
      gaugeFactoryAddress,
      managedRewardsFactoryAddress,
    ],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.tags.etherscan) {
    await helpers.etherscan.verify(factoryRegistryDeployment)
  }

  if (hre.network.tags.tenderly) {
    await hre.tenderly.verify({
      name: "FactoryRegistry",
      address: factoryRegistryDeployment.address,
    })
  }
}

export default func

func.tags = ["FactoryRegistry"]
func.dependencies = [
  "PoolFactory",
  "VotingRewardsFactory",
  "GaugeFactory",
  "ManagedRewardsFactory",
]
