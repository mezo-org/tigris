import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, helpers } = hre
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()

  log("Deploying Pool contract...")
  const bank = await deploy("Pool", {
    from: deployer,
    args: [],
    log: true,
    waitConfirmations: 1,
  })

  if (hre.network.tags.etherscan) {
    await helpers.etherscan.verify(bank)
  }

  if (hre.network.tags.tenderly) {
    await hre.tenderly.verify({
      name: "Bank",
      address: bank.address,
    })
  }
}

export default func

func.tags = ["Pool"]
