import { ethers, getNamedAccounts } from "hardhat"
import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, helpers } = hre
  const { execute, log } = deployments
  const { deployer } = await getNamedAccounts()

  const btcAddress = (await deployments.get("Bitcoin")).address
  const musdAddress = (await deployments.get("mUSD")).address

  log(`Bitcoin address is ${btcAddress}`)
  log(`mUSD address is ${musdAddress}`)

  const poolFactory = await helpers.contracts.getContract("PoolFactory")

  const pool = await poolFactory.getPair(btcAddress, musdAddress, false)

  if (pool !== ethers.ZeroAddress) {
    log(`BTC-mUSD pool already deployed at is ${pool}`)
  } else {
    log("Creating BTC-mUSD pool...")

    await execute(
      "PoolFactory",
      { from: deployer, log: true, waitConfirmations: 1 },
      "createPair",
      btcAddress,
      musdAddress,
      false,
    )
  }
}

export default func

func.tags = ["CreatePools"]
func.dependencies = ["PoolFactory"]

func.skip = async (hre) => hre.network.name !== "matsnet"
