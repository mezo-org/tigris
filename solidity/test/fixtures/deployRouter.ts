import {
    deployments,
    ethers,
    getNamedAccounts,
    getUnnamedAccounts,
    helpers,
} from "hardhat"
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers"
import {
    Router,
    MockBTC,
    MockERC20,
    FactoryRegistry,
    VotingRewardsFactory,
    GaugeFactory,
    ManagedRewardsFactory,
    PoolFactory,
    Pool,
} from "../../typechain"

export default async function deployRouter(): Promise<{
    BTC: MockBTC
    tokenX: MockERC20
    tokenY: MockERC20
    tokenZ: MockERC20
    btcAddress: string
    xAddress: string
    yAddress: string
    zAddress: string
    poolFactory: PoolFactory
    poolFactoryAddress: string
    factoryRegistry: FactoryRegistry
    router: Router
    routerAddress: string
    deployer: HardhatEthersSigner
    userOne: HardhatEthersSigner
    userTwo: HardhatEthersSigner
}> {
    const { deployer } = await getNamedAccounts()
    const [userOne, userTwo] = await getUnnamedAccounts()
    await deployments.fixture()

    await deployments.deploy("MockBTC", {
        contract: "MockBTC",
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: 1,
    })
    const BTC = (await helpers.contracts.getContract(
        "MockBTC",
    )) as unknown as MockBTC 
    const btcAddress = await BTC.getAddress()

    await deployments.deploy("MockTokenX", {
        contract: "MockERC20",
        from: deployer,
        args: ["MockTokenX", "MockTokenX", ethers.parseEther("100")],
        log: true,
        waitConfirmations: 1,
    })
    const tokenX = (await helpers.contracts.getContract(
        "MockTokenX",
    )) as unknown as MockERC20 
    const xAddress = await tokenX.getAddress()

    await deployments.deploy("MockTokenY", {
        contract: "MockERC20",
        from: deployer,
        args: ["MockTokenY", "MockTokenY", ethers.parseEther("100")],
        log: true,
        waitConfirmations: 1,
    })
    const tokenY = (await helpers.contracts.getContract(
        "MockTokenY",
    )) as unknown as MockERC20 
    const yAddress = await tokenY.getAddress()

    await deployments.deploy("MockTokenZ", {
        contract: "MockERC20",
        from: deployer,
        args: ["MockTokenZ", "MockTokenZ", ethers.parseEther("100")],
        log: true,
        waitConfirmations: 1,
    })
    const tokenZ = (await helpers.contracts.getContract(
        "MockTokenZ",
    )) as unknown as MockERC20 
    const zAddress = await tokenZ.getAddress()

    await deployments.deploy("PoolBase", {
        contract: "Pool",
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: 1,
    })
    const poolBase = (await helpers.contracts.getContract(
        "PoolBase",
    )) as unknown as Pool 
    const poolBaseAddress = await poolBase.getAddress()

    await deployments.deploy("VotingRewardsFactory", {
        contract: "VotingRewardsFactory",
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: 1,
    })
    const votingRewardsFactory = (await helpers.contracts.getContract(
        "VotingRewardsFactory",
    )) as unknown as VotingRewardsFactory 
    const votingRewardsFactoryAddress = await votingRewardsFactory.getAddress()

    await deployments.deploy("GaugeFactory", {
        contract: "GaugeFactory",
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: 1,
    })
    const gaugeFactory = (await helpers.contracts.getContract(
        "GaugeFactory",
    )) as unknown as GaugeFactory 
    const gaugeFactoryAddress = await gaugeFactory.getAddress()

    await deployments.deploy("ManagedRewardsFactory", {
        contract: "ManagedRewardsFactory",
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: 1,
    })
    const managedRewardsFactory = (await helpers.contracts.getContract(
        "ManagedRewardsFactory",
    )) as unknown as ManagedRewardsFactory 
    const managedRewardsFactoryAddress = await managedRewardsFactory.getAddress()

    await deployments.deploy("PoolFactory", {
        contract: "PoolFactory",
        from: deployer,
        args: [poolBaseAddress],
        log: true,
        waitConfirmations: 1,
    })
    const poolFactory = (await helpers.contracts.getContract(
        "PoolFactory",
    )) as unknown as PoolFactory 
    const poolFactoryAddress = await poolFactory.getAddress()

    await deployments.deploy("FactoryRegistry", {
        contract: "FactoryRegistry",
        from: deployer,
        args: [poolFactoryAddress, votingRewardsFactoryAddress, gaugeFactoryAddress, managedRewardsFactoryAddress],
        log: true,
        waitConfirmations: 1,
    })
    const factoryRegistry = (await helpers.contracts.getContract(
        "FactoryRegistry",
    )) as unknown as FactoryRegistry 
    const factoryRegistryAddress = await factoryRegistry.getAddress()

    await deployments.deploy("Router", {
        contract: "Router",
        from: deployer,
        args: [factoryRegistryAddress, poolFactoryAddress, votingRewardsFactoryAddress, gaugeFactoryAddress, btcAddress],
        log: true,
        waitConfirmations: 1,
    })
    const router = (await helpers.contracts.getContract(
        "Router",
    )) as unknown as Router 
    const routerAddress = await router.getAddress()

    await Promise.all(
        [userOne, userTwo].map(async (address) => {
          await BTC.mint(address, ethers.parseEther("1000"))
          await tokenX.mint(address, ethers.parseEther("1000"))
          await tokenY.mint(address, ethers.parseEther("1000"))
          await tokenZ.mint(address, ethers.parseEther("1000"))
        }),
      )

    return {
        BTC,
        tokenX,
        tokenY,
        tokenZ,
        btcAddress,
        xAddress,
        yAddress,
        zAddress,
        poolFactory,
        poolFactoryAddress,
        factoryRegistry,
        router,
        routerAddress,
        deployer: await ethers.getSigner(deployer),
        userOne: await ethers.getSigner(userOne),
        userTwo: await ethers.getSigner(userTwo),
    }
}