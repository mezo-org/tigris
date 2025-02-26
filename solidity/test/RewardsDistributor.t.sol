pragma solidity 0.8.24;

import "./BaseTest.sol";

contract RewardsDistributorTest is BaseTest {
    event Claimed(uint256 indexed tokenId, uint256 indexed epochStart, uint256 indexed epochEnd, uint256 amount);

    function _setUp() public override {
        // timestamp: 604801
        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId = escrow.createLock(TOKEN_1, MAXTIME);
        skip(1);

        address[] memory pools = new address[](2);
        pools[0] = address(pool);
        pools[1] = address(pool2);
        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 1;

        skip(1 hours);
        voter.vote(tokenId, pools, weights);
    }

    function testInitialize() public {
        assertEq(distributor.startTime(), 604800);
        assertEq(distributor.lastTokenTime(), 604800);
        assertEq(distributor.token(), address(BTC));
        assertEq(address(distributor.ve()), address(escrow));
    }

    function testClaim() public {
        skipToNextEpoch(1 days); // epoch 0, ts: 1296000, blk: 2

        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);

        IVotingEscrow.LockedBalance memory locked = escrow.locked(tokenId);
        assertEq(convert(locked.amount), TOKEN_1M);
        assertEq(locked.end, 127008000);
        assertEq(locked.isPermanent, false);

        assertEq(escrow.userPointEpoch(tokenId), 1);
        IVotingEscrow.UserPoint memory userPoint = escrow.userPointHistory(tokenId, 1);
        assertEq(convert(userPoint.slope), TOKEN_1M / MAXTIME); // TOKEN_1M / MAXTIME
        assertEq(convert(userPoint.bias), 996575342465753345952000); // (TOKEN_1M / MAXTIME) * (127008000 - 1296000)
        assertEq(userPoint.ts, 1296000);
        assertEq(userPoint.blk, 2);

        vm.startPrank(address(owner2));
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);
        vm.stopPrank();

        locked = escrow.locked(tokenId2);
        assertEq(convert(locked.amount), TOKEN_1M);
        assertEq(locked.end, 127008000);
        assertEq(locked.isPermanent, false);

        assertEq(escrow.userPointEpoch(tokenId2), 1);
        userPoint = escrow.userPointHistory(tokenId2, 1);
        assertEq(convert(userPoint.slope), TOKEN_1M / MAXTIME); // TOKEN_1M / MAXTIME
        assertEq(convert(userPoint.bias), 996575342465753345952000); // (TOKEN_1M / MAXTIME) * (127008000 - 1296000)
        assertEq(userPoint.ts, 1296000);
        assertEq(userPoint.blk, 2);

        skipToNextEpoch(0); // distribute epoch 1's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 0);
        assertEq(distributor.claimable(tokenId2), 0);

        skipToNextEpoch(0); // epoch 1's rebases available
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 164999917898591583);
        assertEq(distributor.claimable(tokenId2), 164999917898591583);

        skipToNextEpoch(0); // epoch 1+2's rebases available
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 329999835799117876);
        assertEq(distributor.claimable(tokenId2), 329999835799117876);

        skipToNextEpoch(0);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 494999753701597755);
        assertEq(distributor.claimable(tokenId2), 494999753701597755);

        IVotingEscrow.LockedBalance memory preLocked = escrow.locked(tokenId);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 1814400, 3628800, 494999753701597755);
        distributor.claim(tokenId);
        IVotingEscrow.LockedBalance memory postLocked = escrow.locked(tokenId);
        assertEq(postLocked.amount - preLocked.amount, 494999753701597755);
        assertEq(postLocked.end, 127008000);
        assertEq(postLocked.isPermanent, false);
    }

    function testClaimWithPermanentLocks() public {
        skipToNextEpoch(1 days); // epoch 0, ts: 1296000, blk: 2

        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);
        escrow.lockPermanent(tokenId);

        IVotingEscrow.LockedBalance memory locked = escrow.locked(tokenId);
        assertEq(convert(locked.amount), TOKEN_1M);
        assertEq(locked.end, 0);
        assertEq(locked.isPermanent, true);

        assertEq(escrow.userPointEpoch(tokenId), 1);
        IVotingEscrow.UserPoint memory userPoint = escrow.userPointHistory(tokenId, 1);
        assertEq(convert(userPoint.slope), 0);
        assertEq(convert(userPoint.bias), 0);
        assertEq(userPoint.ts, 1296000);
        assertEq(userPoint.blk, 2);
        assertEq(userPoint.permanent, TOKEN_1M);

        vm.startPrank(address(owner2));
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);
        escrow.lockPermanent(tokenId2);
        vm.stopPrank();

        locked = escrow.locked(tokenId2);
        assertEq(convert(locked.amount), TOKEN_1M);
        assertEq(locked.end, 0);
        assertEq(locked.isPermanent, true);

        assertEq(escrow.userPointEpoch(tokenId2), 1);
        userPoint = escrow.userPointHistory(tokenId2, 1);
        assertEq(convert(userPoint.slope), 0);
        assertEq(convert(userPoint.bias), 0);
        assertEq(userPoint.ts, 1296000);
        assertEq(userPoint.blk, 2);
        assertEq(userPoint.permanent, TOKEN_1M);

        skipToNextEpoch(0); // distribute epoch 1's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 0);
        assertEq(distributor.claimable(tokenId2), 0);

        skipToNextEpoch(0); // epoch 1's rebases available
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 164999918517162882);
        assertEq(distributor.claimable(tokenId2), 164999918517162882);

        skipToNextEpoch(0); // epoch 1+2's rebases available
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 329999837429873319);
        assertEq(distributor.claimable(tokenId2), 329999837429873319);

        skipToNextEpoch(0);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 494999756738131314);
        assertEq(distributor.claimable(tokenId2), 494999756738131314);

        IVotingEscrow.LockedBalance memory preLocked = escrow.locked(tokenId);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 1814400, 3628800, 494999756738131314);
        distributor.claim(tokenId);
        IVotingEscrow.LockedBalance memory postLocked = escrow.locked(tokenId);
        assertEq(postLocked.amount - preLocked.amount, 494999756738131314);
        assertEq(postLocked.end, 0);
        assertEq(postLocked.isPermanent, true);
    }

    function testClaimWithBothLocks() public {
        skipToNextEpoch(1 days); // epoch 0, ts: 1296000, blk: 2

        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);
        escrow.lockPermanent(tokenId);

        vm.startPrank(address(owner2));
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);
        vm.stopPrank();

        // expect permanent lock to earn more rebases
        skipToNextEpoch(0); // distribute epoch 1's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 0);
        assertEq(distributor.claimable(tokenId2), 0);

        skipToNextEpoch(0); // epoch 1's rebases available
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 165623842988475047);
        assertEq(distributor.claimable(tokenId2), 164375993429618460);

        skipToNextEpoch(0); // epoch 1+2's rebases available
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 331647192345789056);
        assertEq(distributor.claimable(tokenId2), 328352480891819368);

        skipToNextEpoch(0);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 498071980055353287);
        assertEq(distributor.claimable(tokenId2), 491927530405132706);

        uint256 pre = convert(escrow.locked(tokenId).amount);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 1814400, 3628800, 498071980055353287);
        distributor.claim(tokenId);
        uint256 post = convert(escrow.locked(tokenId).amount);

        assertEq(post - pre, 498071980055353287);
    }

    function testClaimWithLockCreatedMoreThan50EpochsLater() public {
        for (uint256 i = 0; i < 55; i++) {
            skipToNextEpoch(0);
            deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
            chainFeeSplitter.updatePeriod();
        }

        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);

        skipToNextEpoch(0);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 0);
        assertEq(distributor.claimable(tokenId2), 0);

        skipToNextEpoch(0);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 164999939420311928);
        assertEq(distributor.claimable(tokenId2), 164999939420311928);

        uint256 pre = convert(escrow.locked(tokenId).amount);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 33868800, 35078400, 164999939420311928);
        distributor.claim(tokenId);
        uint256 post = convert(escrow.locked(tokenId).amount);

        assertEq(post - pre, 164999939420311928);
    }

    function testClaimWithIncreaseAmountOnEpochFlip() public {
        skipToNextEpoch(1 days); // epoch 0
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);

        skipToNextEpoch(0); // distribute epoch 1's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 0);
        assertEq(distributor.claimable(tokenId2), 0);

        skipToNextEpoch(0);
        assertEq(distributor.claimable(tokenId), 0);
        assertEq(distributor.claimable(tokenId2), 0);
        // making lock larger on flip should not impact claimable
        BTC.approve(address(escrow), TOKEN_1M);
        escrow.increaseAmount(tokenId, TOKEN_1M);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod(); // epoch 1's rebases available
        assertEq(distributor.claimable(tokenId), 164999917898591583);
        assertEq(distributor.claimable(tokenId2), 164999917898591583);
    }

    function testClaimWithExpiredNFT() public {
        // test reward claims to expired NFTs are distributed as unlocked BTC
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, WEEK * 4);

        skipToNextEpoch(1);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 0);

        for (uint256 i = 0; i < 4; i++) {
            deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
            chainFeeSplitter.updatePeriod();
            skipToNextEpoch(1);
        }

        assertGt(distributor.claimable(tokenId), 0); // accrued rebases

        IVotingEscrow.LockedBalance memory locked = escrow.locked(tokenId);
        assertGt(block.timestamp, locked.end); // lock expired

        uint256 rebase = distributor.claimable(tokenId);
        uint256 pre = BTC.balanceOf(address(owner));
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 1209600, 3024000, 989875609087602635);
        distributor.claim(tokenId);
        uint256 post = BTC.balanceOf(address(owner));

        locked = escrow.locked(tokenId); // update locked value post claim

        assertEq(post - pre, rebase); // expired rebase distributed as unlocked BTC
        assertEq(uint256(uint128(locked.amount)), TOKEN_1M); // expired nft locked balance unchanged
    }

    function testClaimManyWithExpiredNFT() public {
        // test claim many with one expired nft and one normal nft
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, WEEK * 4);
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);

        skipToNextEpoch(1);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 0);
        assertEq(distributor.claimable(tokenId2), 0);

        for (uint256 i = 0; i < 4; i++) {
            deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
            chainFeeSplitter.updatePeriod();
            skipToNextEpoch(1);
        }

        assertGt(distributor.claimable(tokenId), 0); // accrued rebases
        assertGt(distributor.claimable(tokenId2), 0);

        IVotingEscrow.LockedBalance memory locked = escrow.locked(tokenId);
        assertGt(block.timestamp, locked.end); // lock expired

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId;
        tokenIds[1] = tokenId2;

        uint256 rebase = distributor.claimable(tokenId);
        uint256 rebase2 = distributor.claimable(tokenId2);

        uint256 pre = BTC.balanceOf(address(owner));
        assertTrue(distributor.claimMany(tokenIds));
        uint256 post = BTC.balanceOf(address(owner));

        locked = escrow.locked(tokenId); // update locked value post claim
        IVotingEscrow.LockedBalance memory postLocked2 = escrow.locked(tokenId2);

        assertEq(post - pre, rebase); // expired rebase distributed as unlocked BTC
        assertEq(uint256(uint128(locked.amount)), TOKEN_1M); // expired nft locked balance unchanged
        assertEq(uint256(uint128(postLocked2.amount)) - uint256(uint128(locked.amount)), rebase2); // rebase accrued to normal nft
    }
}
