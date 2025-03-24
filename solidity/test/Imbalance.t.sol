// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./BaseTest.sol";

contract ImbalanceTest is BaseTest {
    constructor() {
        deploymentType = Deployment.CUSTOM;
    }

    function deployBaseCoins() public {
        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e25;
        mintToken(address(BTC), owners, amounts);

        VeBTC impl = new VeBTC();
        bytes memory initData = abi.encodeWithSelector(
            impl.initialize.selector,
            address(forwarder),
            address(BTC),
            address(factoryRegistry)
        );
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            proxyAdmin,
            initData
        );
        escrow = VeBTC(address(proxy));
    }

    function createLock() public {
        deployBaseCoins();

        BTC.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.warp(1);
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), TOKEN_1);
    }

    function votingEscrowMerge() public {
        createLock();

        BTC.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        assertGt(escrow.balanceOfNFT(2), 995063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), 2 * TOKEN_1);
        escrow.merge(2, 1);
        assertGt(escrow.balanceOfNFT(1), 1990039602248405587);
        assertEq(escrow.balanceOfNFT(2), 0);
    }

    function confirmTokensFor_mUSD_wtBTC() public {
        votingEscrowMerge();
        deployFactories();
        factory.setFee(true, 1);
        factory.setFee(false, 1);
        voter = new Voter(address(forwarder), address(escrow), address(factoryRegistry));
        router = new Router(
            address(forwarder),
            address(factoryRegistry),
            address(factory),
            address(voter)
        );
        deployPoolWithOwner(address(owner));

        (address token0, address token1) = router.sortTokens(address(BTC), address(mUSD));
        assertEq(pool.token0(), token0);
        assertEq(pool.token1(), token1);
    }

    function mintAndBurnTokensForPool_mUSD_wtBTC() public {
        confirmTokensFor_mUSD_wtBTC();

        mUSD.transfer(address(pool), mUSD_1);
        BTC.transfer(address(pool), TOKEN_1);
        pool.mint(address(owner));
        assertEq(pool.getAmountOut(mUSD_1, address(mUSD)), 666622220740691356);
    }

    function routerAddLiquidity() public {
        mintAndBurnTokensForPool_mUSD_wtBTC();

        mUSD.approve(address(router), mUSD_100K);
        BTC.approve(address(router), TOKEN_100K);
        router.addLiquidity(
            address(BTC),
            address(mUSD),
            false,
            TOKEN_100K,
            mUSD_100K,
            TOKEN_100K,
            mUSD_100K,
            address(owner),
            block.timestamp
        );
        mUSD.approve(address(router), mUSD_100K);
        LIMPETH.approve(address(router), TOKEN_100K);
        router.addLiquidity(
            address(LIMPETH),
            address(mUSD),
            false,
            TOKEN_100K,
            mUSD_100K,
            TOKEN_100K,
            mUSD_100K,
            address(owner),
            block.timestamp
        );
        mUSD.approve(address(router), mUSD_100M);
        wtBTC.approve(address(router), TOKEN_100M);
        router.addLiquidity(
            address(mUSD),
            address(wtBTC),
            false,
            mUSD_100M,
            TOKEN_100M,
            0,
            0,
            address(owner),
            block.timestamp
        );
    }

    function deployVoter() public {
        routerAddLiquidity();

        voter = new Voter(address(forwarder), address(escrow), address(factoryRegistry));
        address[] memory tokens = new address[](4);
        tokens[0] = address(mUSD);
        tokens[1] = address(wtBTC);
        tokens[2] = address(LIMPETH);
        tokens[3] = address(BTC);
        voter.initialize(tokens, address(owner));

        assertEq(voter.length(), 0);
    }

    function deployPoolFactoryGauge() public {
        deployVoter();

        BTC.approve(address(gaugeFactory), 5 * TOKEN_100K);
        voter.createGauge(address(factory), address(pool3));
        assertFalse(voter.gauges(address(pool3)) == address(0));

        address gaugeAddr3 = voter.gauges(address(pool3));

        Gauge gauge3 = Gauge(gaugeAddr3);

        uint256 total = pool3.balanceOf(address(owner));
        pool3.approve(address(gauge3), total);
        gauge3.deposit(total);
        assertEq(gauge3.totalSupply(), total);
        assertEq(gauge3.earned(address(owner)), 0);
    }

    function testRouterPool3GetAmountsOutAndSwapExactTokensForTokens() public {
        deployPoolFactoryGauge();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(mUSD), address(wtBTC), false, address(0));
        IRouter.Route[] memory routes2 = new IRouter.Route[](1);
        routes2[0] = IRouter.Route(address(wtBTC), address(mUSD), false, address(0));

        uint256 mb = mUSD.balanceOf(address(owner));
        uint256 wb = wtBTC.balanceOf(address(owner));

        uint256 i;
        for (i = 0; i < 10; i++) {
            assertEq(router.getAmountsOut(1e10, routes)[1], pool3.getAmountOut(1e10, address(mUSD)));

            uint256[] memory expectedOutput = router.getAmountsOut(1e10, routes);
            mUSD.approve(address(router), 1e10);
            router.swapExactTokensForTokens(1e10, expectedOutput[1], routes, address(owner), block.timestamp);
        }

        mUSD.approve(address(router), mUSD_10B);
        wtBTC.approve(address(router), TOKEN_10B);
        uint256 poolBefore = pool3.balanceOf(address(owner));
        router.addLiquidity(
            address(mUSD),
            address(wtBTC),
            false,
            mUSD_10B,
            TOKEN_10B,
            0,
            0,
            address(owner),
            block.timestamp
        );
        uint256 poolAfter = pool3.balanceOf(address(owner));
        uint256 LPBal = poolAfter - poolBefore;

        for (i = 0; i < 10; i++) {
            assertEq(router.getAmountsOut(1e25, routes2)[1], pool3.getAmountOut(1e25, address(wtBTC)));

            uint256[] memory expectedOutput2 = router.getAmountsOut(1e25, routes2);
            wtBTC.approve(address(router), 1e25);
            router.swapExactTokensForTokens(1e25, expectedOutput2[1], routes2, address(owner), block.timestamp);
        }
        pool3.approve(address(router), LPBal);
        router.removeLiquidity(address(mUSD), address(wtBTC), false, LPBal, 0, 0, address(owner), block.timestamp);

        uint256 ma = mUSD.balanceOf(address(owner));
        uint256 wa = wtBTC.balanceOf(address(owner));

        uint256 netAfter = ma + wa;
        uint256 netBefore = wb + mb;

        assertGt(netBefore, netAfter);
    }
}
