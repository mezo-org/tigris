import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { upgrades, helpers, ethers } from "hardhat"
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers"
import { expect } from "chai"
import {
    Router,
    MockBTC,
    MockERC20,
    FactoryRegistry,
    PoolFactory,
    Pool,
} from "../typechain"
import deployRouter from "./fixtures/deployRouter"

const { createSnapshot, restoreSnapshot } = helpers.snapshot

describe("Router", () => {
    let BTC: MockBTC
    let tokenX: MockERC20
    let tokenY: MockERC20
    let tokenZ: MockERC20
    let btcAddress: string
    let xAddress: string
    let yAddress: string
    let zAddress: string
    let poolFactory: PoolFactory
    let poolFactoryAddress: string
    let factoryRegistry: FactoryRegistry
    let router: Router
    let routerAddress: string
    let deployer: HardhatEthersSigner
    let userOne: HardhatEthersSigner
    let userTwo: HardhatEthersSigner

    before(async () => {
        ;({
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
            deployer,
            router,
            routerAddress,
            userOne,
            userTwo,
        } = await loadFixture(deployRouter))
    })

    describe("poolFor", async () => {
        beforeEach(async () => {
            await createSnapshot()
        })

        afterEach(async () => {
            await restoreSnapshot()
        })

        it("Returns garbage for nonexistent pool", async () => {
            expect(await router.poolFor(xAddress, yAddress, true, poolFactoryAddress)).to.not.equal("0")
        })

        it("Returns real pool address", async () => {
            let createdPool = await poolFactory.createPool.staticCall(xAddress, yAddress, ethers.Typed.uint24(1))
            await poolFactory.createPool(xAddress, yAddress, ethers.Typed.uint24(1))
            expect(await router.poolFor(xAddress, yAddress, true, poolFactoryAddress)).to.equal(createdPool)
        })
    })

    describe("liquidity", async () => {
        let poolXY: Pool

        before(async () => {
            await createSnapshot()

            let poolAddressXY = await poolFactory.createPool.staticCall(xAddress, yAddress, ethers.Typed.uint24(1))
            await poolFactory.createPool(xAddress, yAddress, ethers.Typed.uint24(1))
            poolXY = await ethers.getContractAt("Pool", poolAddressXY)
            await tokenX.mint(poolAddressXY, ethers.parseEther("100"))
            await tokenY.mint(poolAddressXY, ethers.parseEther("100"))
            await poolXY.mint(userOne)
            await helpers.time.mineBlocks(2)
        })

        after(async () => {
            await restoreSnapshot()
        })

        beforeEach(async () => {
            await createSnapshot()
        })

        afterEach(async () => {
            await restoreSnapshot()
        })

        it("can be added and removed", async () => {
            await tokenX.connect(userTwo).approve(routerAddress, ethers.parseEther("10"))
            await tokenY.connect(userTwo).approve(routerAddress, ethers.parseEther("10"))
            await helpers.time.mineBlocks(2)
            await router.connect(userTwo).addLiquidity(
                xAddress,
                yAddress,
                true,
                ethers.parseEther("10"),
                ethers.parseEther("10"),
                ethers.parseEther("9.99"),
                ethers.parseEther("9.99"),
                userTwo.address,
                0
            )
            expect(await poolXY.balanceOf(userTwo.address)).to.eq(ethers.parseEther("10"))

            await poolXY.connect(userTwo).approve(routerAddress, ethers.parseEther("5"))
            await router.connect(userTwo).removeLiquidity(
                xAddress,
                yAddress,
                true,
                ethers.parseEther("5"),
                ethers.parseEther("4.99"),
                ethers.parseEther("4.99"),
                userTwo.address,
                0
            )
            expect(await poolXY.balanceOf(userTwo.address)).to.eq(ethers.parseEther("5"))
        })

        // it("swaps", async () => {
        //     await tokenX.connect(userTwo).approve(routerAddress, ethers.parseEther("20"))
        //     await tokenY.connect(userTwo).approve(routerAddress, ethers.parseEther("5"))
        //     await router.connect(userTwo).addLiquidity(
        //         xAddress,
        //         yAddress,
        //         true,
        //         ethers.parseEther("20"),
        //         ethers.parseEther("5"),
        //         ethers.parseEther("5"),
        //         ethers.parseEther("5"),
        //         userTwo.address,
        //         0
        //     )
        // })
    })

    describe("swap tokens", async () => {
        before(async () => {
            await createSnapshot()

            let stablePoolAddressXY = await poolFactory.createPool.staticCall(xAddress, yAddress, ethers.Typed.bool(true))
            await poolFactory.createPool(xAddress, yAddress, ethers.Typed.bool(true))
            let stablePoolXY = await ethers.getContractAt("Pool", stablePoolAddressXY)
            await tokenX.mint(stablePoolAddressXY, ethers.parseEther("1000"))
            await tokenY.mint(stablePoolAddressXY, ethers.parseEther("1000"))
            await stablePoolXY.mint(userOne)

            let stablePoolAddressYZ = await poolFactory.createPool.staticCall(yAddress, zAddress, ethers.Typed.bool(true))
            await poolFactory.createPool(yAddress, zAddress, ethers.Typed.bool(true))
            let stablePoolYZ = await ethers.getContractAt("Pool", stablePoolAddressYZ)
            await tokenY.mint(stablePoolAddressYZ, ethers.parseEther("1000"))
            await tokenZ.mint(stablePoolAddressYZ, ethers.parseEther("1000"))
            await stablePoolYZ.mint(userOne)

            let volatilePoolAddressXY = await poolFactory.createPool.staticCall(xAddress, yAddress, ethers.Typed.bool(false))
            await poolFactory.createPool(xAddress, yAddress, ethers.Typed.bool(false))
            let volatilePoolXY = await ethers.getContractAt("Pool", volatilePoolAddressXY)
            await tokenX.mint(volatilePoolAddressXY, ethers.parseEther("1000"))
            await tokenY.mint(volatilePoolAddressXY, ethers.parseEther("1000"))
            await volatilePoolXY.mint(userOne)

            let volatilePoolAddressXZ = await poolFactory.createPool.staticCall(xAddress, zAddress, ethers.Typed.bool(false))
            await poolFactory.createPool(xAddress, zAddress, ethers.Typed.bool(false))
            let volatilePoolXZ = await ethers.getContractAt("Pool", volatilePoolAddressXZ)
            await tokenX.mint(volatilePoolAddressXZ, ethers.parseEther("1000"))
            await tokenZ.mint(volatilePoolAddressXZ, ethers.parseEther("2000"))
            await volatilePoolXZ.mint(userOne)

            let volatilePoolAddressYZ = await poolFactory.createPool.staticCall(yAddress, zAddress, ethers.Typed.bool(false))
            await poolFactory.createPool(yAddress, zAddress, ethers.Typed.bool(false))
            let volatilePoolYZ = await ethers.getContractAt("Pool", volatilePoolAddressYZ)
            await tokenY.mint(volatilePoolAddressYZ, ethers.parseEther("1000"))
            await tokenZ.mint(volatilePoolAddressYZ, ethers.parseEther("2000"))
            await volatilePoolYZ.mint(userOne)

            await helpers.time.mineBlocks(1)
        })

        after(async () => {
            await restoreSnapshot()
        })

        beforeEach(async () => {
            await createSnapshot()
        })

        afterEach(async () => {
            await restoreSnapshot()
        })

        it("works", async () => {
            await tokenX.connect(userTwo).approve(routerAddress, ethers.parseEther("3"))
            let balancePre = await tokenZ.balanceOf(userTwo.address)
            // await tokenY.connect(userTwo).approve(routerAddress, ethers.parseEther("10"))
            // let route: Router.RouteStruct
            let stableXY = {from: xAddress, to: yAddress, stable: true, factory: poolFactoryAddress}
            await router.connect(userTwo).swapExactTokensForTokens(
                ethers.parseEther("1"),
                ethers.parseEther("0.9"),
                [stableXY],
                userTwo.address,
                0,
            )
            let balanceMid = await tokenY.balanceOf(userTwo.address)
            let receivedStable = balanceMid - balancePre

            let volatileXY = {from: xAddress, to: yAddress, stable: false, factory: poolFactoryAddress}
            await router.connect(userTwo).swapExactTokensForTokens(
                ethers.parseEther("1"),
                ethers.parseEther("0.9"),
                [volatileXY],
                userTwo.address,
                0,
            )
            let balanceEnd = await tokenY.balanceOf(userTwo.address)
            let receivedVolatile = balanceEnd - balanceMid

            expect(receivedStable).to.be.closeTo(ethers.parseEther("1"), ethers.parseEther("0.001"))
            expect(receivedVolatile).to.be.closeTo(ethers.parseEther("1"), ethers.parseEther("0.02"))
            expect(receivedStable).to.gt(receivedVolatile)

            let volatileYZ = {from: yAddress, to: zAddress, stable: false, factory: poolFactoryAddress}
            let volatileZX = {from: zAddress, to: xAddress, stable: false, factory: poolFactoryAddress}
            await router.connect(userTwo).swapExactTokensForTokens(
                ethers.parseEther("1"),
                ethers.parseEther("0.9"),
                [volatileXY, volatileYZ, volatileZX, stableXY, volatileYZ, volatileZX, stableXY, volatileYZ, volatileZX],
                userTwo.address,
                0,
            )
            let balanceAfterRoundtrip = await tokenX.balanceOf(userTwo.address)
            let receivedInRoundtrip = balanceAfterRoundtrip - balanceEnd
            expect(receivedInRoundtrip).to.lt(ethers.parseEther("1"))
        })
    })

    describe("Zap", async () => {
        before(async () => {
            await createSnapshot()

            let stablePoolAddressXY = await poolFactory.createPool.staticCall(xAddress, yAddress, ethers.Typed.bool(true))
            await poolFactory.createPool(xAddress, yAddress, ethers.Typed.bool(true))
            let stablePoolXY = await ethers.getContractAt("Pool", stablePoolAddressXY)
            await tokenX.mint(stablePoolAddressXY, ethers.parseEther("1000"))
            await tokenY.mint(stablePoolAddressXY, ethers.parseEther("1000"))
            await stablePoolXY.mint(userOne)

            let stablePoolAddressYZ = await poolFactory.createPool.staticCall(yAddress, zAddress, ethers.Typed.bool(true))
            await poolFactory.createPool(yAddress, zAddress, ethers.Typed.bool(true))
            let stablePoolYZ = await ethers.getContractAt("Pool", stablePoolAddressYZ)
            await tokenY.mint(stablePoolAddressYZ, ethers.parseEther("1000"))
            await tokenZ.mint(stablePoolAddressYZ, ethers.parseEther("1000"))
            await stablePoolYZ.mint(userOne)

            let volatilePoolAddressXY = await poolFactory.createPool.staticCall(xAddress, yAddress, ethers.Typed.bool(false))
            await poolFactory.createPool(xAddress, yAddress, ethers.Typed.bool(false))
            let volatilePoolXY = await ethers.getContractAt("Pool", volatilePoolAddressXY)
            await tokenX.mint(volatilePoolAddressXY, ethers.parseEther("1000"))
            await tokenY.mint(volatilePoolAddressXY, ethers.parseEther("1000"))
            await volatilePoolXY.mint(userOne)

            let volatilePoolAddressXZ = await poolFactory.createPool.staticCall(xAddress, zAddress, ethers.Typed.bool(false))
            await poolFactory.createPool(xAddress, zAddress, ethers.Typed.bool(false))
            let volatilePoolXZ = await ethers.getContractAt("Pool", volatilePoolAddressXZ)
            await tokenX.mint(volatilePoolAddressXZ, ethers.parseEther("1000"))
            await tokenZ.mint(volatilePoolAddressXZ, ethers.parseEther("2000"))
            await volatilePoolXZ.mint(userOne)

            let volatilePoolAddressYZ = await poolFactory.createPool.staticCall(yAddress, zAddress, ethers.Typed.bool(false))
            await poolFactory.createPool(yAddress, zAddress, ethers.Typed.bool(false))
            let volatilePoolYZ = await ethers.getContractAt("Pool", volatilePoolAddressYZ)
            await tokenY.mint(volatilePoolAddressYZ, ethers.parseEther("1000"))
            await tokenZ.mint(volatilePoolAddressYZ, ethers.parseEther("2000"))
            await volatilePoolYZ.mint(userOne)

            await helpers.time.mineBlocks(1)
        })

        after(async () => {
            await restoreSnapshot()
        })

        beforeEach(async () => {
            await createSnapshot()
        })

        afterEach(async () => {
            await restoreSnapshot()
        })

        it("create zap in parameters", async () => {
            let stableXY = {from: xAddress, to: yAddress, stable: true, factory: poolFactoryAddress}
            let volatileXZ = {from: xAddress, to: zAddress, stable: false, factory: poolFactoryAddress}

            let zapIn = await router.generateZapInParams(
                yAddress,
                zAddress,
                false,
                poolFactoryAddress,
                ethers.parseEther("1"),
                ethers.parseEther("1"),
                [stableXY],
                [volatileXZ]
            )
            expect(zapIn[0]).to.be.closeTo(ethers.parseEther("1"), ethers.parseEther("0.01"))
            expect(zapIn[1]).to.be.closeTo(ethers.parseEther("2"), ethers.parseEther("0.01"))
            expect(zapIn[2]).to.be.closeTo(ethers.parseEther("1"), ethers.parseEther("0.01"))
            expect(zapIn[3]).to.be.closeTo(ethers.parseEther("2"), ethers.parseEther("0.01"))
        })

        it("create zap out parameters", async () => {
            let stableYX = {from: yAddress, to: xAddress, stable: true, factory: poolFactoryAddress}
            let volatileZX = {from: zAddress, to: xAddress, stable: false, factory: poolFactoryAddress}

            let zapOut = await router.generateZapOutParams(
                yAddress,
                zAddress,
                false,
                poolFactoryAddress,
                ethers.parseEther("2"),
                [stableYX],
                [volatileZX]
            )
            expect(zapOut[0]).to.be.closeTo(ethers.parseEther("1.4"), ethers.parseEther("0.02"))
            expect(zapOut[1]).to.be.closeTo(ethers.parseEther("1.4"), ethers.parseEther("0.02"))
            expect(zapOut[2]).to.be.closeTo(ethers.parseEther("1.4"), ethers.parseEther("0.02"))
            expect(zapOut[3]).to.be.closeTo(ethers.parseEther("2.8"), ethers.parseEther("0.03"))
        })

        it("zaps in", async () => {
            let stableXY = {from: xAddress, to: yAddress, stable: true, factory: poolFactoryAddress}
            let volatileXZ = {from: xAddress, to: zAddress, stable: false, factory: poolFactoryAddress}
            let zapInPool = {
                tokenA: yAddress,
                tokenB: zAddress,
                stable: false,
                factory: poolFactoryAddress,
                amountOutMinA: ethers.parseEther("0.9"),
                amountOutMinB: ethers.parseEther("1.9"),
                amountAMin: ethers.parseEther("0.9"),
                amountBMin: ethers.parseEther("1.9"),
            }

            await tokenX.connect(userTwo).approve(routerAddress, ethers.parseEther("3"))
            await router.connect(userTwo).zapIn(
                xAddress,
                ethers.parseEther("1"),
                ethers.parseEther("2"),
                zapInPool,
                [stableXY],
                [volatileXZ],
                userTwo.address,
                false
            )
        })
    })
})