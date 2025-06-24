// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./BaseTest.sol";

contract WashTradeTest is BaseTest {
    constructor() {
        deploymentType = Deployment.CUSTOM;
    }

    function deployBaseCoins() public {
        skip(1 weeks);

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e28;
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
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), TOKEN_1);
    }

    function votingEscrowMerge() public {
        createLock();

        BTC.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        skipAndRoll(1);
        assertGt(escrow.balanceOfNFT(2), 995063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), 2 * TOKEN_1);
        escrow.merge(2, 1);
        assertGt(escrow.balanceOfNFT(1), 1990039602248405587);
        assertEq(escrow.balanceOfNFT(2), 0);
    }

    function confirmTokensForBTCmUSD() public {
        votingEscrowMerge();
        deployFactories();
        factory.setFee(true, 1);
        factory.setFee(false, 1);
        voter = new Voter(
            address(forwarder),
            address(escrow),
            address(factoryRegistry)
        );
        router = new Router(
            address(forwarder),
            address(factoryRegistry),
            address(factory)
        );
        deployPoolWithOwner(address(owner));

        (address token0, address token1) = router.sortTokens(
            address(mUSD),
            address(BTC)
        );
        assertEq(pool4.token0(), token0);
        assertEq(pool4.token1(), token1);
    }

    function mintAndBurnTokensForPoolBTCmUSD() public {
        confirmTokensForBTCmUSD();

        mUSD.transfer(address(pool4), mUSD_1);
        BTC.transfer(address(pool4), TOKEN_1);
        pool4.mint(address(owner));
        assertEq(pool4.getAmountOut(mUSD_1, address(mUSD)), 945128557522723966);
    }

    function routerAddLiquidity() public {
        mintAndBurnTokensForPoolBTCmUSD();

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
        mUSD.approve(address(router), mUSD_100K);
        wtBTC.approve(address(router), TOKEN_100K);
        router.addLiquidity(
            address(mUSD),
            address(wtBTC),
            false,
            mUSD_100K,
            TOKEN_100K,
            0,
            0,
            address(owner),
            block.timestamp
        );
        BTC.approve(address(router), TOKEN_100M);
        mUSD.approve(address(router), mUSD_100M);
        router.addLiquidity(
            address(BTC),
            address(mUSD),
            true,
            TOKEN_100M,
            mUSD_100M,
            0,
            0,
            address(owner),
            block.timestamp
        );
    }

    function deployVoter() public {
        routerAddLiquidity();

        voter = new Voter(
            address(forwarder),
            address(escrow),
            address(factoryRegistry)
        );
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
        voter.createGauge(address(factory), address(pool2));
        voter.createGauge(address(factory), address(pool3));
        voter.createGauge(address(factory), address(pool4));
        assertFalse(voter.gauges(address(pool4)) == address(0));

        address gaugeAddr4 = voter.gauges(address(pool4));
        address feesVotingRewardAddr4 = voter.gaugeToFees(gaugeAddr4);

        gauge4 = Gauge(gaugeAddr4);

        feesVotingReward4 = FeesVotingReward(feesVotingRewardAddr4);
        uint256 total = pool4.balanceOf(address(owner));
        pool4.approve(address(gauge4), total);
        gauge4.deposit(total);
        assertEq(gauge4.totalSupply(), total);
        assertEq(gauge4.earned(address(owner)), 0);
    }

    function routerPool4GetAmountsOutAndSwapExactTokensForTokens() public {
        deployPoolFactoryGauge();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(
            address(BTC),
            address(mUSD),
            true,
            address(0)
        );
        IRouter.Route[] memory routes2 = new IRouter.Route[](1);
        routes2[0] = IRouter.Route(
            address(mUSD),
            address(BTC),
            true,
            address(0)
        );

        uint256 i;
        for (i = 0; i < 10; i++) {
            assertEq(
                router.getAmountsOut(TOKEN_1M, routes)[1],
                pool4.getAmountOut(TOKEN_1M, address(BTC))
            );

            uint256[] memory expectedOutput = router.getAmountsOut(
                TOKEN_1M,
                routes
            );
            BTC.approve(address(router), TOKEN_1M);
            router.swapExactTokensForTokens(
                TOKEN_1M,
                expectedOutput[1],
                routes,
                address(owner),
                block.timestamp
            );

            assertEq(
                router.getAmountsOut(mUSD_1M, routes2)[1],
                pool4.getAmountOut(mUSD_1M, address(mUSD))
            );

            uint256[] memory expectedOutput2 = router.getAmountsOut(
                mUSD_1M,
                routes2
            );
            mUSD.approve(address(router), mUSD_1M);
            router.swapExactTokensForTokens(
                mUSD_1M,
                expectedOutput2[1],
                routes2,
                address(owner),
                block.timestamp
            );
        }
    }

    function voterReset() public {
        routerPool4GetAmountsOutAndSwapExactTokensForTokens();

        distributor = new RewardsDistributor(address(escrow));
        escrow.setVoterAndDistributor(address(voter), address(distributor));
        skip(1 hours);
        voter.reset(1);
    }

    function voterPokeSelf() public {
        voterReset();

        voter.poke(1);
    }

    function voterVoteAndFeesVotingRewardBalanceOf() public {
        voterPokeSelf();

        skipToNextEpoch(1 hours + 1);

        address[] memory pools = new address[](2);
        pools[0] = address(pool4);
        pools[1] = address(pool2);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;
        voter.vote(1, pools, weights);
        assertFalse(voter.totalWeight() == 0);
        assertFalse(feesVotingReward4.balanceOf(1) == 0);
    }

    function feesVotingRewardClaimRewards() public {
        voterVoteAndFeesVotingRewardBalanceOf();

        address[] memory tokens = new address[](2);
        tokens[0] = address(BTC);
        tokens[1] = address(mUSD);
        feesVotingReward4.getReward(1, tokens);
        skip(8 days);
        vm.roll(block.number + 1);
        feesVotingReward4.getReward(1, tokens);
    }

    function distributeAndClaimFees() public {
        feesVotingRewardClaimRewards();

        skip(8 days);
        vm.roll(block.number + 1);
        address[] memory tokens = new address[](2);
        tokens[0] = address(BTC);
        tokens[1] = address(mUSD);
        feesVotingReward4.getReward(1, tokens);

        address[] memory gauges = new address[](1);
        gauges[0] = address(gauge4);
    }

    function testBribeClaimRewards() public {
        distributeAndClaimFees();

        console2.log(feesVotingReward4.earned(address(BTC), 1));
        console2.log(BTC.balanceOf(address(owner)));
        console2.log(BTC.balanceOf(address(feesVotingReward4)));
        address[] memory tokens = new address[](2);
        tokens[0] = address(BTC);
        tokens[1] = address(mUSD);
        feesVotingReward4.getReward(1, tokens);
        skip(8 days);
        vm.roll(block.number + 1);
        console2.log(feesVotingReward4.earned(address(BTC), 1));
        console2.log(BTC.balanceOf(address(owner)));
        console2.log(BTC.balanceOf(address(feesVotingReward4)));
        feesVotingReward4.getReward(1, tokens);
        console2.log(feesVotingReward4.earned(address(BTC), 1));
        console2.log(BTC.balanceOf(address(owner)));
        console2.log(BTC.balanceOf(address(feesVotingReward4)));
    }
}
