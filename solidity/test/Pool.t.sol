// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./BaseTest.sol";

contract PoolTest is BaseTest {
    constructor() {
        deploymentType = Deployment.CUSTOM;
    }

    function deployPoolCoins() public {
        skip(1 weeks);

        deployOwners();
        deployCoins();
        mintStables();
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 2e25;
        amounts[1] = 1e25;
        amounts[2] = 1e25;
        mintToken(address(BTC), owners, amounts);
        mintToken(address(LR), owners, amounts);
        deployFactories();
        factory.setFee(true, 1);
        factory.setFee(false, 1);

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

        distributor = new RewardsDistributor(address(escrow));
        voter = new Voter(address(forwarder), address(escrow), address(factoryRegistry));
        router = new Router(
            address(forwarder),
            address(factoryRegistry),
            address(factory)
        );

        escrow.setVoterAndDistributor(address(voter), address(distributor));
        factory.setVoter(address(voter));

        deployPoolWithOwner(address(owner));
        deployPoolWithOwner(address(owner2));
    }

    function createLock() public {
        deployPoolCoins();

        BTC.approve(address(escrow), 5e17);
        escrow.createLock(5e17, MAXTIME);
        vm.roll(block.number + 1); // fwd 1 block because escrow.balanceOfNFT() returns 0 in same block
        assertGt(escrow.balanceOfNFT(1), 495063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), 5e17);
    }

    function increaseLock() public {
        createLock();

        BTC.approve(address(escrow), 5e17);
        escrow.increaseAmount(1, 5e17);
        vm.expectRevert(IVotingEscrow.LockDurationNotInFuture.selector);
        escrow.increaseUnlockTime(1, MAXTIME);
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), TOKEN_1);
    }

    function votingEscrowViews() public {
        increaseLock();

        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), TOKEN_1);
    }

    function stealNFT() public {
        votingEscrowViews();

        vm.startPrank(address(owner2));
        vm.expectRevert(IVotingEscrow.NotApprovedOrOwner.selector);
        escrow.transferFrom(address(owner), address(owner2), 1);
        vm.expectRevert(IVotingEscrow.NotApprovedOrOwner.selector);
        escrow.approve(address(owner2), 1);
        vm.expectRevert(IVotingEscrow.NotApprovedOrOwner.selector);
        escrow.merge(1, 2);
        vm.stopPrank();
    }

    function votingEscrowMerge() public {
        stealNFT();

        BTC.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        assertGt(escrow.balanceOfNFT(2), 995063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), 2 * TOKEN_1);

        escrow.merge(2, 1);
        assertGt(escrow.balanceOfNFT(1), 1990063075414519385);
        assertEq(escrow.balanceOfNFT(2), 0);

        IVotingEscrow.LockedBalance memory locked;

        locked = escrow.locked(2);
        assertEq(locked.amount, 0);
        assertEq(escrow.ownerOf(2), address(0));

        BTC.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        assertGt(escrow.balanceOfNFT(3), 995063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), 3 * TOKEN_1);

        escrow.merge(3, 1);
        assertGt(escrow.balanceOfNFT(1), 1990063075414519385);
        assertEq(escrow.balanceOfNFT(3), 0);

        locked = escrow.locked(3);
        assertEq(locked.amount, 0);
        assertEq(escrow.ownerOf(3), address(0));
    }

    function confirmTokensForBTCmUSD() public {
        votingEscrowMerge();

        (address token0, address token1) = router.sortTokens(address(mUSD), address(BTC));
        assertEq(pool4.token0(), token0);
        assertEq(pool4.token1(), token1);
    }

    function mintAndBurnTokensForPoolBTCmUSD() public {
        confirmTokensForBTCmUSD();

        mUSD.transfer(address(pool4), mUSD_1);
        BTC.transfer(address(pool4), TOKEN_1);
        pool4.mint(address(owner));
        assertEq(pool4.getAmountOut(mUSD_1, address(mUSD)), 982117769725505988);
    }

    function mintAndBurnTokensForPoolBTCmUSDOwner2() public {
        mintAndBurnTokensForPoolBTCmUSD();

        vm.startPrank(address(owner2));
        mUSD.transfer(address(pool4), mUSD_1);
        BTC.transfer(address(pool4), TOKEN_1);
        pool4.mint(address(owner2));
        vm.stopPrank();

        assertEq(pool4.getAmountOut(mUSD_1, address(mUSD)), 992220948146798746);
    }

    function routerAddLiquidity() public {
        mintAndBurnTokensForPoolBTCmUSDOwner2();

        _addLiquidityToPool(address(owner), address(router), address(mUSD), address(BTC), false, mUSD_100K, TOKEN_100K);
        _addLiquidityToPool(
            address(owner),
            address(router),
            address(mUSD),
            address(LIMPETH),
            false,
            mUSD_100K,
            TOKEN_100K
        );
        _addLiquidityToPool(address(owner), address(router), address(mUSD), address(wtBTC), false, mUSD_100M, TOKEN_100M);
        _addLiquidityToPool(address(owner), address(router), address(mUSD), address(BTC), true, mUSD_100K, TOKEN_100K);
    }

    function deploySplitter() public {
        routerAddLiquidity();

        distributor = new RewardsDistributor(address(escrow));
        uint256 needle = 33;
        chainFeeSplitter = new ChainFeeSplitter(address(voter), address(escrow), address(distributor), needle);
        distributor.setDepositor(address(chainFeeSplitter));

        address[] memory tokens = new address[](5);
        tokens[0] = address(mUSD);
        tokens[1] = address(wtBTC);
        tokens[2] = address(LIMPETH);
        tokens[3] = address(BTC);
        tokens[4] = address(LR);
        voter.initialize(tokens, address(chainFeeSplitter));
    }

    function deployPoolFactoryGauge() public {
        deploySplitter();

        BTC.approve(address(gaugeFactory), 15 * TOKEN_100K);
        voter.createGauge(address(factory), address(pool));
        voter.createGauge(address(factory), address(pool2));
        voter.createGauge(address(factory), address(pool3));
        voter.createGauge(address(factory), address(pool4));
        assertFalse(voter.gauges(address(pool4)) == address(0));

        address gaugeAddress = voter.gauges(address(pool));
        address feesVotingRewardAddress = voter.gaugeToFees(gaugeAddress);
        address bribeVotingRewardAddress = voter.gaugeToBribe(gaugeAddress);

        address gaugeAddress2 = voter.gauges(address(pool2));
        address feesVotingRewardAddress2 = voter.gaugeToFees(gaugeAddress2);
        address bribeVotingRewardAddress2 = voter.gaugeToBribe(gaugeAddress2);

        address gaugeAddress3 = voter.gauges(address(pool3));
        address feesVotingRewardAddress3 = voter.gaugeToFees(gaugeAddress3);
        address bribeVotingRewardAddress3 = voter.gaugeToBribe(gaugeAddress3);

        address gaugeAddress4 = voter.gauges(address(pool4));
        address feesVotingRewardAddress4 = voter.gaugeToFees(gaugeAddress4);
        address bribeVotingRewardAddress4 = voter.gaugeToBribe(gaugeAddress4);

        gauge = Gauge(gaugeAddress);
        gauge2 = Gauge(gaugeAddress2);
        gauge3 = Gauge(gaugeAddress3);
        gauge4 = Gauge(gaugeAddress4);

        feesVotingReward = FeesVotingReward(feesVotingRewardAddress);
        bribeVotingReward = BribeVotingReward(bribeVotingRewardAddress);

        feesVotingReward2 = FeesVotingReward(feesVotingRewardAddress2);
        bribeVotingReward2 = BribeVotingReward(bribeVotingRewardAddress2);

        feesVotingReward3 = FeesVotingReward(feesVotingRewardAddress3);
        bribeVotingReward3 = BribeVotingReward(bribeVotingRewardAddress3);

        feesVotingReward4 = FeesVotingReward(feesVotingRewardAddress4);
        bribeVotingReward4 = BribeVotingReward(bribeVotingRewardAddress4);

        pool.approve(address(gauge), POOL_1);
        pool2.approve(address(gauge2), POOL_1);
        pool3.approve(address(gauge3), POOL_1);
        pool4.approve(address(gauge4), POOL_1);
        gauge.deposit(POOL_1);
        gauge2.deposit(POOL_1);
        gauge3.deposit(POOL_1);
        gauge4.deposit(POOL_1);
        assertEq(gauge4.totalSupply(), POOL_1);
        assertEq(gauge4.earned(address(owner)), 0);
    }

    function deployPoolFactoryGaugeOwner2() public {
        deployPoolFactoryGauge();

        owner2.approve(address(pool4), address(gauge4), POOL_1);
        owner2.deposit(address(gauge4), POOL_1);
        assertEq(gauge4.totalSupply(), 2 * POOL_1);
        assertEq(gauge4.earned(address(owner2)), 0);
    }

    function withdrawGaugeStake() public {
        deployPoolFactoryGaugeOwner2();

        gauge.withdraw(gauge.balanceOf(address(owner)));
        owner2.withdrawGauge(address(gauge4), gauge4.balanceOf(address(owner2)));
        gauge2.withdraw(gauge2.balanceOf(address(owner)));
        gauge3.withdraw(gauge3.balanceOf(address(owner)));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        assertEq(gauge.totalSupply(), 0);
        assertEq(gauge2.totalSupply(), 0);
        assertEq(gauge3.totalSupply(), 0);
        assertEq(gauge4.totalSupply(), 0);
    }

    function addGaugeAndVotingRewards() public {
        withdrawGaugeStake();

        _addRewardToGauge(address(voter), address(gauge4), POOL_1);

        BTC.approve(address(bribeVotingReward4), POOL_1);

        bribeVotingReward4.notifyRewardAmount(address(BTC), POOL_1);

        assertEq(gauge4.rewardRate(), 1653);
    }

    function exitAndGetRewardGaugeStake() public {
        addGaugeAndVotingRewards();

        uint256 supply = pool4.balanceOf(address(owner));
        pool4.approve(address(gauge4), supply);
        gauge4.deposit(supply);
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        assertEq(gauge4.totalSupply(), 0);
        pool4.approve(address(gauge4), supply);
        gauge4.deposit(POOL_1);
    }

    function voterReset() public {
        exitAndGetRewardGaugeStake();

        skip(1 weeks + 1 hours + 1);
        voter.reset(1);
    }

    function voterPokeSelf() public {
        voterReset();

        voter.poke(1);
    }

    function createLock2() public {
        voterPokeSelf();

        BTC.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        skip(1);
        assertGt(escrow.balanceOfNFT(1), 995063075414519385);
        assertEq(BTC.balanceOf(address(escrow)), 4 * TOKEN_1);
    }

    function voteHacking() public {
        createLock2();

        address[] memory pools = new address[](1);
        pools[0] = address(pool4);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        skip(1 weeks + 1 hours + 1);

        voter.vote(1, pools, weights);
        assertEq(voter.usedWeights(1), escrow.balanceOfNFT(1)); // within 1000
        assertEq(feesVotingReward4.balanceOf(1), uint256(voter.votes(1, address(pool4))));
        skip(1 weeks);

        voter.reset(1);
        assertLt(voter.usedWeights(1), escrow.balanceOfNFT(1));
        assertEq(voter.usedWeights(1), 0);
        assertEq(feesVotingReward4.balanceOf(1), uint256(voter.votes(1, address(pool4))));
        assertEq(feesVotingReward4.balanceOf(1), 0);
    }

    function gaugePokeHacking() public {
        voteHacking();

        assertEq(voter.usedWeights(1), 0);
        assertEq(voter.votes(1, address(pool4)), 0);
        voter.poke(1);
        assertEq(voter.usedWeights(1), 0);
        assertEq(voter.votes(1, address(pool4)), 0);
    }

    function gaugeVoteAndBribeBalanceOf() public {
        gaugePokeHacking();

        address[] memory pools = new address[](2);
        pools[0] = address(pool4);
        pools[1] = address(pool);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 5000;
        weights[1] = 5000;
        skip(1 weeks + 1 hours + 1);

        voter.vote(1, pools, weights);
        weights[0] = 50000;
        weights[1] = 50000;

        voter.vote(4, pools, weights);
        assertFalse(voter.totalWeight() == 0);
        assertFalse(feesVotingReward4.balanceOf(1) == 0);
    }

    function gaugePokeHacking2() public {
        gaugeVoteAndBribeBalanceOf();

        uint256 weightBefore = voter.usedWeights(1);
        uint256 votesBefore = voter.votes(1, address(pool4));
        voter.poke(1);
        assertEq(voter.usedWeights(1), weightBefore);
        assertEq(voter.votes(1, address(pool4)), votesBefore);
    }

    function voteHackingBreakMint() public {
        gaugePokeHacking2();

        address[] memory pools = new address[](1);
        pools[0] = address(pool4);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 5000;
        skip(1 weeks);

        voter.vote(1, pools, weights);

        assertEq(voter.usedWeights(1), escrow.balanceOfNFT(1)); // within 1000
        assertEq(feesVotingReward4.balanceOf(1), uint256(voter.votes(1, address(pool4))));
    }

    function gaugePokeHacking3() public {
        voteHackingBreakMint();

        assertEq(voter.usedWeights(1), uint256(voter.votes(1, address(pool4))));
        voter.poke(1);
        assertEq(voter.usedWeights(1), uint256(voter.votes(1, address(pool4))));
    }

    function gaugeDistributeBasedOnVoting() public {
        gaugePokeHacking3();

        deal(address(BTC), address(chainFeeSplitter), POOL_1);

        vm.startPrank(address(chainFeeSplitter));
        BTC.approve(address(voter), POOL_1);
        voter.notifyRewardAmount(POOL_1);
        vm.stopPrank();

        voter.updateFor(0, voter.length());
        voter.distribute(0, voter.length());
    }

    function feesVotingRewardClaimRewards() public {
        gaugeDistributeBasedOnVoting();

        address[] memory rewards = new address[](1);
        rewards[0] = address(BTC);
        feesVotingReward4.getReward(1, rewards);
        skip(8 days);
        vm.roll(block.number + 1);
        feesVotingReward4.getReward(1, rewards);
    }

    function routerPool1GetAmountsOutAndSwapExactTokensForTokens2() public {
        feesVotingRewardClaimRewards();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(mUSD), address(BTC), true, address(0));

        uint256[] memory expectedOutput = router.getAmountsOut(mUSD_1, routes);
        mUSD.approve(address(router), mUSD_1);
        router.swapExactTokensForTokens(mUSD_1, expectedOutput[1], routes, address(owner), block.timestamp);
    }

    function routerPool2GetAmountsOutAndSwapExactTokensForTokens2() public {
        routerPool1GetAmountsOutAndSwapExactTokensForTokens2();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(mUSD), address(BTC), false, address(0));

        uint256[] memory expectedOutput = router.getAmountsOut(mUSD_1, routes);
        mUSD.approve(address(router), mUSD_1);
        router.swapExactTokensForTokens(mUSD_1, expectedOutput[1], routes, address(owner), block.timestamp);
    }

    function routerPool1GetAmountsOutAndSwapExactTokensForTokens2Again() public {
        routerPool2GetAmountsOutAndSwapExactTokensForTokens2();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(BTC), address(mUSD), false, address(0));

        uint256[] memory expectedOutput = router.getAmountsOut(TOKEN_1, routes);
        BTC.approve(address(router), TOKEN_1);
        router.swapExactTokensForTokens(TOKEN_1, expectedOutput[1], routes, address(owner), block.timestamp);
    }

    function routerPool2GetAmountsOutAndSwapExactTokensForTokens2Again() public {
        routerPool1GetAmountsOutAndSwapExactTokensForTokens2Again();

        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route(address(BTC), address(mUSD), false, address(0));

        uint256[] memory expectedOutput = router.getAmountsOut(TOKEN_1, routes);
        BTC.approve(address(router), TOKEN_1);
        router.swapExactTokensForTokens(TOKEN_1, expectedOutput[1], routes, address(owner), block.timestamp);
    }

    function routerPool1Pool2GetAmountsOutAndSwapExactTokensForTokens() public {
        routerPool2GetAmountsOutAndSwapExactTokensForTokens2Again();

        IRouter.Route[] memory route = new IRouter.Route[](2);
        route[0] = IRouter.Route(address(BTC), address(mUSD), false, address(0));
        route[1] = IRouter.Route(address(mUSD), address(BTC), true, address(0));

        uint256 before = BTC.balanceOf(address(owner)) - TOKEN_1;

        uint256[] memory expectedOutput = router.getAmountsOut(TOKEN_1, route);
        BTC.approve(address(router), TOKEN_1);
        router.swapExactTokensForTokens(TOKEN_1, expectedOutput[2], route, address(owner), block.timestamp);
        uint256 after_ = BTC.balanceOf(address(owner));
        assertEq(after_ - before, expectedOutput[2]);
    }

    function distributeAndClaimFees() public {
        routerPool1Pool2GetAmountsOutAndSwapExactTokensForTokens();

        skip(8 days);
        vm.roll(block.number + 1);
        address[] memory rewards = new address[](2);
        rewards[0] = address(BTC);
        rewards[1] = address(mUSD);
        feesVotingReward4.getReward(1, rewards);

        address[] memory gauges = new address[](1);
        gauges[0] = address(gauge4);
    }

    function splitterUpdate() public {
        distributeAndClaimFees();

        chainFeeSplitter.updatePeriod();
        voter.updateFor(address(gauge4));
        voter.distribute(0, voter.length());
        skip(30 minutes);
        vm.roll(block.number + 1);
    }

    function gaugeClaimRewards() public {
        splitterUpdate();

        assertEq(address(owner), escrow.ownerOf(1));
        assertTrue(escrow.isApprovedOrOwner(address(owner), 1));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        skip(1);
        pool4.approve(address(gauge4), POOL_1);
        skip(1);
        gauge4.deposit(POOL_1);
        skip(1);
        uint256 before = BTC.balanceOf(address(owner));
        skip(1);
        uint256 earned = gauge4.earned(address(owner));
        gauge4.getReward(address(owner));
        skip(1);
        uint256 after_ = BTC.balanceOf(address(owner));
        uint256 received = after_ - before;
        assertEq(earned, received);

        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        skip(1 weeks);
        vm.roll(block.number + 1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
    }

    function gaugeClaimRewardsAfterExpiry() public {
        gaugeClaimRewards();

        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);
        gauge4.getReward(address(owner));
        skip(1 weeks);
        vm.roll(block.number + 1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
    }

    function votingEscrowDecay() public {
        gaugeClaimRewardsAfterExpiry();

        address[] memory feesVotingRewards_ = new address[](1);
        feesVotingRewards_[0] = address(feesVotingReward4);
        address[][] memory rewards = new address[][](1);
        address[] memory reward = new address[](1);
        reward[0] = address(LIMPETH);
        rewards[0] = reward;
        voter.claimBribes(feesVotingRewards_, rewards, 1);
        voter.claimFees(feesVotingRewards_, rewards, 1);
        uint256 supply = escrow.totalSupply();
        assertGt(supply, 0);
        skip(MAXTIME);
        vm.roll(block.number + 1);
        assertEq(escrow.balanceOfNFT(1), 0);
        assertEq(escrow.totalSupply(), 0);
        skip(1 weeks);

        voter.reset(1);
        escrow.withdraw(1);
    }

    function routerAddLiquidityOwner3() public {
        votingEscrowDecay();

        _addLiquidityToPool(address(owner3), address(router), address(mUSD), address(BTC), true, 1e12, TOKEN_1M);
    }

    function deployPoolFactoryGaugeOwner3() public {
        routerAddLiquidityOwner3();

        owner3.approve(address(pool4), address(gauge4), POOL_1);
        owner3.deposit(address(gauge4), POOL_1);
    }

    function gaugeClaimRewardsOwner3() public {
        deployPoolFactoryGaugeOwner3();

        owner3.withdrawGauge(address(gauge4), gauge4.balanceOf(address(owner3)));
        owner3.approve(address(pool4), address(gauge4), POOL_1);
        owner3.deposit(address(gauge4), POOL_1);
        owner3.withdrawGauge(address(gauge4), gauge4.balanceOf(address(owner3)));
        owner3.approve(address(pool4), address(gauge4), POOL_1);
        owner3.deposit(address(gauge4), POOL_1);

        owner3.getGaugeReward(address(gauge4), address(owner3));
        owner3.withdrawGauge(address(gauge4), gauge4.balanceOf(address(owner3)));
        owner3.approve(address(pool4), address(gauge4), POOL_1);
        owner3.deposit(address(gauge4), POOL_1);
        owner3.getGaugeReward(address(gauge4), address(owner3));
        owner3.withdrawGauge(address(gauge4), gauge4.balanceOf(address(owner3)));
        owner3.approve(address(pool4), address(gauge4), POOL_1);
        owner3.deposit(address(gauge4), POOL_1);
        owner3.getGaugeReward(address(gauge4), address(owner3));
        owner3.getGaugeReward(address(gauge4), address(owner3));
        owner3.getGaugeReward(address(gauge4), address(owner3));
        owner3.getGaugeReward(address(gauge4), address(owner3));

        owner3.withdrawGauge(address(gauge4), gauge4.balanceOf(address(owner)));
        owner3.approve(address(pool4), address(gauge4), POOL_1);
        owner3.deposit(address(gauge4), POOL_1);
        owner3.getGaugeReward(address(gauge4), address(owner3));
    }

    function minterMint2() public {
        gaugeClaimRewardsOwner3();

        skip(2 weeks);
        vm.roll(block.number + 1);
        chainFeeSplitter.updatePeriod();
        voter.updateFor(address(gauge4));
        address[] memory gauges = new address[](1);
        gauges[0] = address(gauge4);
        voter.updateFor(gauges);
        voter.distribute(0, voter.length());
        voter.claimRewards(gauges);
        assertEq(gauge4.rewardRate(), 1471);
        console2.log(gauge4.rewardPerTokenStored());
    }

    function testGaugeClaimRewards2() public {
        minterMint2();

        pool4.approve(address(gauge4), POOL_1);
        gauge4.deposit(POOL_1);

        _addRewardToGauge(address(voter), address(gauge4), TOKEN_1);

        skip(1 weeks);
        vm.roll(block.number + 1);
        gauge4.getReward(address(owner));
        gauge4.withdraw(gauge4.balanceOf(address(owner)));
    }

    function testSetPoolName() external {
        // Note: as this contract is a custom setup, the pool contracts are not already deployed from
        // base setup, and so they need to be deployed for these tests
        deployPoolCoins();

        assertEq(pool.name(), "Volatile AMM - BTC/mUSD");
        pool.setName("Some new name");
        assertEq(pool.name(), "Some new name");
    }

    function testCannotSetPoolNameIfNotEmergencyCouncil() external {
        deployPoolCoins();

        vm.prank(address(owner2));
        vm.expectRevert(IPool.NotEmergencyCouncil.selector);
        pool.setName("Some new name");
    }

    function testSetPoolSymbol() external {
        deployPoolCoins();

        assertEq(pool.symbol(), "vAMM-BTC/mUSD");
        pool.setSymbol("Some new symbol");
        assertEq(pool.symbol(), "Some new symbol");
    }

    function testCannotSetPoolSymbolIfNotEmergencyCouncil() external {
        deployPoolCoins();

        vm.prank(address(owner2));
        vm.expectRevert(IPool.NotEmergencyCouncil.selector);
        pool.setSymbol("Some new symbol");
    }
}
