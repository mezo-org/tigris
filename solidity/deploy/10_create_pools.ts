import { ethers, getNamedAccounts } from "hardhat"
import { DeployFunction } from "hardhat-deploy/dist/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, helpers } = hre
  const { execute, log } = deployments
  const { deployer } = await getNamedAccounts()

  const poolFactory = await helpers.contracts.getContract("PoolFactory")
  const veBTCVoter = await helpers.contracts.getContract("VeBTCVoter")

  const createPool = async (
    token1: string,
    token2: string,
    isStable: boolean,
  ) => {
    const token1Address = (await deployments.get(token1)).address
    const token2Address = (await deployments.get(token2)).address

    // The PoolFactory defines two getPool functions with different signatures.
    // A regular call like `poolFactory.getPool(...)` leads to the `ambiguous function description` error.
    // The solution is to specify the function signature explicitly.
    const getPoolFn = poolFactory["getPool(address,address,bool)"]

    let pool = await getPoolFn(token1Address, token2Address, isStable)
    if (pool !== ethers.ZeroAddress) {
      log(`${token1}/${token2} pool already exists at ${pool}`)
    } else {
      log(`Creating ${token1}/${token2} pool...`)
      await execute(
        "PoolFactory",
        { from: deployer, log: true, waitConfirmations: 1 },
        // The PoolFactory contract defines two createPool functions with different signatures.
        // We must specify the function signature explicitly.
        "createPool(address,address,bool)",
        token1Address,
        token2Address,
        isStable,
      )

      pool = await getPoolFn(token1Address, token2Address, isStable)
      log(`${token1}/${token2} pool created at ${pool}`)
    }

    let gauge = await veBTCVoter.gauges(pool)
    if (gauge !== ethers.ZeroAddress) {
      log(`${token1}/${token2} gauge already exists at ${gauge}`)
    } else {
      log(`Creating ${token1}/${token2} gauge...`)
      await execute(
        "VeBTCVoter",
        { from: deployer, log: true, waitConfirmations: 1 },
        "createGauge",
        await poolFactory.getAddress(),
        pool,
      )

      gauge = await veBTCVoter.gauges(pool)
      log(`${token1}/${token2} gauge created at ${gauge}`)
    }
  }

  await createPool("Bitcoin", "mUSD", false)
  await createPool("mUSD", "LIMPETH", false)
  await createPool("mUSD", "wtBTC", false)
}

export default func

func.tags = ["CreatePools"]
func.dependencies = ["Bitcoin", "mUSD", "PoolFactory", "VeBTCVoter"]

func.skip = async (hre) => hre.network.name !== "matsnet"
