// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./BaseTest.sol";

contract ZapTest is BaseTest {
    Router _router;
    Pool vPool;
    Gauge vGauge;
    Pool sPool;
    Gauge sGauge;
    uint256 constant feeRate = 30; // .3% fee for volatile pools on mainnet
    // @dev 2.5 tokens with 6 decimals
    uint256 constant mUSD_2_5 = 2.5e6;

    constructor() {
        deploymentType = Deployment.DEFAULT;
    }

    function _setUp() public override {
        wtBTC = new MockERC20("wtBTC", "wtBTC", 18);

        uint256[] memory amounts = new uint256[](1);
        address[] memory ownerAddr = new address[](1);
        amounts[0] = 1e35;
        ownerAddr[0] = address(owner);
        mintToken(address(wtBTC), ownerAddr, amounts);

        _addLiquidityToPool(
            address(owner),
            address(router),
            address(wtBTC),
            address(mUSD),
            false,
            TOKEN_1 * 763,
            mUSD_10K * 125
        );

        _addLiquidityToPool(
            address(owner),
            address(router),
            address(BTC),
            address(mUSD),
            true,
            TOKEN_100K * 10,
            mUSD_100K * 10
        );


        // Current State:
        // 1.25m mUSD, 763 wtBTC
        // Pool has slightly more mUSD than wtBTC
        vPool = Pool(factory.getPool(address(mUSD), address(wtBTC), false));

        /// Current State:
        /// ~1m BTC, ~1m mUSD
        sPool = Pool(factory.getPool(address(BTC), address(mUSD), true));

        deal(address(mUSD), address(owner2), mUSD_1 * 1e6);
        vm.deal(address(owner2), TOKEN_100K);

        _router = new Router(
            address(forwarder),
            address(factoryRegistry),
            address(factory)
        );
        _router.initializeVoter(address(voter));

        vm.startPrank(address(governor));
        vGauge = Gauge(voter.createGauge(address(factory), address(vPool)));
        sGauge = Gauge(voter.gauges(address(sPool)));
        vm.stopPrank();
    }

    function testZapInWithStablePool() public {
        vm.startPrank(address(owner2));
        mUSD.approve(address(_router), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(address(owner2));
        uint256 mUSDPoolPreBal = mUSD.balanceOf(address(sPool));
        uint256 mUSDOwnerPreBal = mUSD.balanceOf(address(owner2));
        uint256 btcOwnerPreBal = BTC.balanceOf(address(owner2));
        assertEq(sPool.balanceOf(address(owner2)), 0);

        uint256 ratio = _router.quoteStableLiquidityRatio(address(BTC), address(mUSD), address(factory));
        IRouter.Route[] memory routesA = new IRouter.Route[](1);
        routesA[0] = IRouter.Route(address(mUSD), address(BTC), true, address(factory));
        IRouter.Route[] memory routesB = new IRouter.Route[](0);
        IRouter.Zap memory zapInPool = _createZapInParams(
            address(BTC),
            address(mUSD),
            true,
            address(factory),
            (mUSD_10K * (1e18 - ratio)) / 1e18,
            (mUSD_10K * ratio) / 1e18,
            routesA,
            routesB
        );

        _router.zapIn(
            address(mUSD),
            (mUSD_10K * (1e18 - ratio)) / 1e18,
            (mUSD_10K * ratio) / 1e18,
            zapInPool,
            routesA,
            routesB,
            address(owner2),
            false
        );

        uint256 mUSDPoolPostBal = mUSD.balanceOf(address(sPool));
        uint256 mUSDOwnerPostBal = mUSD.balanceOf(address(owner2));
        uint256 btcOwnerPostBal = BTC.balanceOf(address(owner2));

        assertApproxEqAbs(mUSDPoolPostBal - mUSDPoolPreBal, mUSD_10K, mUSD_2_5);
        assertApproxEqAbs(mUSDOwnerPreBal - mUSDOwnerPostBal, mUSD_10K, mUSD_1);
        assertLt(btcOwnerPostBal - btcOwnerPreBal, (TOKEN_100K * 150) / MAX_BPS);
        assertGt(sPool.balanceOf(address(owner2)), 0);
        assertEq(mUSD.balanceOf(address(_router)), 0);
        assertEq(BTC.balanceOf(address(_router)), 0);
        vm.stopPrank();
    }

    function testZapAndStakeWithStablePool() public {
        vm.startPrank(address(owner2));
        mUSD.approve(address(_router), type(uint256).max);

        uint256 mUSDPoolPreBal = mUSD.balanceOf(address(sPool));
        uint256 mUSDOwnerPreBal = mUSD.balanceOf(address(owner2));
        uint256 btcOwnerPreBal = BTC.balanceOf(address(owner2));
        assertEq(sPool.balanceOf(address(owner2)), 0);
        assertEq(sPool.balanceOf(address(sGauge)), 0);
        assertEq(sGauge.balanceOf(address(owner2)), 0);

        uint256 ratio = _router.quoteStableLiquidityRatio(address(BTC), address(mUSD), address(factory));
        IRouter.Route[] memory routesA = new IRouter.Route[](1);
        routesA[0] = IRouter.Route(address(mUSD), address(BTC), true, address(factory));
        IRouter.Route[] memory routesB = new IRouter.Route[](0);
        IRouter.Zap memory zapInPool = _createZapInParams(
            address(BTC),
            address(mUSD),
            true,
            address(factory),
            (mUSD_10K * (1e18 - ratio)) / 1e18,
            (mUSD_10K * ratio) / 1e18,
            routesA,
            routesB
        );

        _router.zapIn(
            address(mUSD),
            (mUSD_10K * (1e18 - ratio)) / 1e18,
            (mUSD_10K * ratio) / 1e18,
            zapInPool,
            routesA,
            routesB,
            address(owner2),
            true
        );

        uint256 mUSDPoolPostBal = mUSD.balanceOf(address(sPool));
        uint256 mUSDOwnerPostBal = mUSD.balanceOf(address(owner2));
        uint256 btcOwnerPostBal = BTC.balanceOf(address(owner2));

        assertApproxEqAbs(mUSDPoolPostBal - mUSDPoolPreBal, mUSD_10K, mUSD_2_5);
        assertApproxEqAbs(mUSDOwnerPreBal - mUSDOwnerPostBal, mUSD_10K, mUSD_1);
        assertLt(btcOwnerPostBal - btcOwnerPreBal, (TOKEN_100K * 150) / MAX_BPS);
        assertEq(sPool.balanceOf(address(owner2)), 0);
        assertGt(sPool.balanceOf(address(sGauge)), 0);
        assertGt(sGauge.balanceOf(address(owner2)), 0);
        assertEq(mUSD.balanceOf(address(_router)), 0);
        assertEq(BTC.balanceOf(address(_router)), 0);
        assertEq(sPool.allowance(address(_router), address(sGauge)), 0);
        vm.stopPrank();
    }

    function testZapInWithVolatilePool() public {
        vm.startPrank(address(owner2));
        mUSD.approve(address(_router), type(uint256).max);

        uint256 mUSDPoolPreBal = mUSD.balanceOf(address(vPool));
        uint256 mUSDOwnerPreBal = mUSD.balanceOf(address(owner2));
        assertEq(vPool.balanceOf(address(owner2)), 0);
        assertEq(vPool.balanceOf(address(owner3)), 0);

        IRouter.Route[] memory routesA = new IRouter.Route[](1);
        routesA[0] = IRouter.Route(address(mUSD), address(wtBTC), false, address(factory));
        IRouter.Route[] memory routesB = new IRouter.Route[](0);
        IRouter.Zap memory zapInPool = _createZapInParams(
            address(wtBTC),
            address(mUSD),
            false,
            address(factory),
            mUSD_10K / 2,
            mUSD_10K / 2,
            routesA,
            routesB
        );

        _router.zapIn(address(mUSD), mUSD_10K / 2, mUSD_10K / 2, zapInPool, routesA, routesB, address(owner3), false);

        uint256 fee = ((mUSD_10K / 2) * feeRate) / MAX_BPS;

        assertEq(mUSD.balanceOf(address(vPool)) - mUSDPoolPreBal, mUSD_10K - fee);
        assertEq(mUSDOwnerPreBal - mUSD.balanceOf(address(owner2)), mUSD_10K);
        assertEq(vPool.balanceOf(address(owner2)), 0);
        assertGt(vPool.balanceOf(address(owner3)), 0);
        assertEq(mUSD.balanceOf(address(_router)), 0);
        assertEq(wtBTC.balanceOf(address(_router)), 0);
        vm.stopPrank();
    }

    function testZapAndStakeWithVolatilePool() public {
        vm.startPrank(address(owner2));
        mUSD.approve(address(_router), type(uint256).max);

        uint256 mUSDPoolPreBal = mUSD.balanceOf(address(vPool));
        uint256 mUSDOwnerPreBal = mUSD.balanceOf(address(owner2));
        uint256 wtBTCOwnerPreBal = wtBTC.balanceOf(address(owner2));
        assertEq(vPool.balanceOf(address(owner2)), 0);
        assertEq(vPool.balanceOf(address(vGauge)), 0);
        assertEq(vGauge.balanceOf(address(owner2)), 0);

        IRouter.Route[] memory routesA = new IRouter.Route[](1);
        routesA[0] = IRouter.Route(address(mUSD), address(wtBTC), false, address(factory));
        IRouter.Route[] memory routesB = new IRouter.Route[](0);
        IRouter.Zap memory zapInPool = _createZapInParams(
            address(wtBTC),
            address(mUSD),
            false,
            address(factory),
            mUSD_10K / 2,
            mUSD_10K / 2,
            routesA,
            routesB
        );

        _router.zapIn(address(mUSD), mUSD_10K / 2, mUSD_10K / 2, zapInPool, routesA, routesB, address(owner2), true);

        uint256 fee = ((mUSD_10K / 2) * feeRate) / MAX_BPS;

        assertEq(mUSD.balanceOf(address(vPool)) - mUSDPoolPreBal, mUSD_10K - fee);
        assertEq(mUSDOwnerPreBal - mUSD.balanceOf(address(owner2)), mUSD_10K);
        assertEq(vPool.balanceOf(address(owner2)), 0);
        assertGt(vPool.balanceOf(address(vGauge)), 0);
        assertGt(vGauge.balanceOf(address(owner2)), 0);
        assertEq(mUSD.balanceOf(address(_router)), 0);
        assertEq(wtBTC.balanceOf(address(_router)), 0);
        assertEq(vPool.allowance(address(_router), address(vGauge)), 0);
        vm.stopPrank();
    }

    function testZapOutWithVolatilePoolWithTokenInPool() public {
        vm.startPrank(address(owner2));
        mUSD.approve(address(_router), type(uint256).max);
        assertEq(vPool.balanceOf(address(owner2)), 0);

        IRouter.Route[] memory routesA = new IRouter.Route[](0);
        IRouter.Route[] memory routesB = new IRouter.Route[](1);
        routesB[0] = IRouter.Route(address(mUSD), address(wtBTC), false, address(factory));
        IRouter.Zap memory zap = _createZapInParams(
            address(mUSD),
            address(wtBTC),
            false,
            address(factory),
            mUSD_10K / 2,
            mUSD_10K / 2,
            routesA,
            routesB
        );

        _router.zapIn(address(mUSD), mUSD_10K / 2, mUSD_10K / 2, zap, routesA, routesB, address(owner2), false);
        uint256 liquidity = vPool.balanceOf(address(owner2));
        assertGt(liquidity, 0);

        uint256 amount = vPool.balanceOf(address(owner2));
        uint256 wtBTCPoolPreBal = wtBTC.balanceOf(address(vPool));
        uint256 wtBTCOwnerPreBal = wtBTC.balanceOf(address(owner2));

        routesB[0] = IRouter.Route(address(wtBTC), address(mUSD), false, address(factory));
        zap = _createZapOutParams(address(mUSD), address(wtBTC), false, address(factory), liquidity, routesA, routesB);
        vPool.approve(address(_router), type(uint256).max);
        _router.zapOut(address(mUSD), amount, zap, routesA, routesB);

        assertLt(wtBTCPoolPreBal - wtBTC.balanceOf(address(vPool)), TOKEN_1 / 100);
        assertEq(wtBTC.balanceOf(address(owner2)), wtBTCOwnerPreBal);
        assertEq(vPool.balanceOf(address(owner2)), 0);
        assertEq(mUSD.balanceOf(address(_router)), 0);
        assertEq(wtBTC.balanceOf(address(_router)), 0);
        vm.stopPrank();
    }

    function _createZapInParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 amountInA,
        uint256 amountInB,
        IRouter.Route[] memory routesA,
        IRouter.Route[] memory routesB
    ) internal view returns (IRouter.Zap memory zap) {
        // use 300 bps slippage for the smaller stable pool
        uint256 slippage = (stable == true) ? 300 : 50;
        (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin) = _router
            .generateZapInParams(tokenA, tokenB, stable, _factory, amountInA, amountInB, routesA, routesB);

        amountAMin = (amountAMin * (MAX_BPS - slippage)) / MAX_BPS;
        amountBMin = (amountBMin * (MAX_BPS - slippage)) / MAX_BPS;
        return IRouter.Zap(tokenA, tokenB, stable, _factory, amountOutMinA, amountOutMinB, amountAMin, amountBMin);
    }

    function _createZapOutParams(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint256 liquidity,
        IRouter.Route[] memory routesA,
        IRouter.Route[] memory routesB
    ) internal view returns (IRouter.Zap memory zap) {
        // use 300 bps slippage for the smaller stable pool
        uint256 slippage = (stable == true) ? 300 : 50;
        (uint256 amountOutMinA, uint256 amountOutMinB, uint256 amountAMin, uint256 amountBMin) = _router
            .generateZapOutParams(tokenA, tokenB, stable, _factory, liquidity, routesA, routesB);
        amountOutMinA = (amountOutMinA * (MAX_BPS - slippage)) / MAX_BPS;
        amountOutMinB = (amountOutMinB * (MAX_BPS - slippage)) / MAX_BPS;
        return IRouter.Zap(tokenA, tokenB, stable, _factory, amountOutMinA, amountOutMinB, amountAMin, amountBMin);
    }
}
