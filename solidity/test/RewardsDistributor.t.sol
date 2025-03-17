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
        skipToNextEpoch(1 days); // epoch 1, ts: 1296000, blk: 2

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

        // epoch 2
        skipToNextEpoch(0); // distribute epoch 1's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 82499958949295791);
        assertEq(distributor.claimable(tokenId2), 82499958949295791);

        // epoch 3
        skipToNextEpoch(0); // distribute epoch 2's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 247499876849822084);
        assertEq(distributor.claimable(tokenId2), 247499876849822084);

        // epoch 4
        skipToNextEpoch(0); // distribute epoch 3's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 412499794752301963);
        assertEq(distributor.claimable(tokenId2), 412499794752301963);

        // epoch 5
        skipToNextEpoch(0); // distribute epoch 4's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 577499712656754580);
        assertEq(distributor.claimable(tokenId2), 577499712656754580);

        IVotingEscrow.LockedBalance memory preLocked = escrow.locked(tokenId);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 1209600, 3628800, 577499712656754580);
        distributor.claim(tokenId);
        IVotingEscrow.LockedBalance memory postLocked = escrow.locked(tokenId);
        assertEq(postLocked.amount - preLocked.amount, 577499712656754580);
        assertEq(postLocked.end, 127008000);
        assertEq(postLocked.isPermanent, false);
    }

    function testClaimWithPermanentLocks() public {
        skipToNextEpoch(1 days); // epoch 1, ts: 1296000, blk: 2

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

        // epoch 2
        skipToNextEpoch(0); // distribute epoch 1's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 82499959258581441);
        assertEq(distributor.claimable(tokenId2), 82499959258581441);

        // epoch 3
        skipToNextEpoch(0); // distribute epoch 2's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 247499878171291878);
        assertEq(distributor.claimable(tokenId2), 247499878171291878);

        // epoch 4
        skipToNextEpoch(0); // distribute epoch 3's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 412499797479549873);
        assertEq(distributor.claimable(tokenId2), 412499797479549873);

        // epoch 5
        skipToNextEpoch(0); // distribute epoch 4's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 577499717183355427);
        assertEq(distributor.claimable(tokenId2), 577499717183355427);

        IVotingEscrow.LockedBalance memory preLocked = escrow.locked(tokenId);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 1209600, 3628800, 577499717183355427);
        distributor.claim(tokenId);
        IVotingEscrow.LockedBalance memory postLocked = escrow.locked(tokenId);
        assertEq(postLocked.amount - preLocked.amount, 577499717183355427);
        assertEq(postLocked.end, 0);
        assertEq(postLocked.isPermanent, true);
    }

    function testClaimWithBothLocks() public {
        skipToNextEpoch(1 days); // epoch 1, ts: 1296000, blk: 2

        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);
        escrow.lockPermanent(tokenId);

        vm.startPrank(address(owner2));
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);
        vm.stopPrank();

        // expect permanent lock to earn more rebases
        // epoch 2
        skipToNextEpoch(0); // distribute epoch 1's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 82811921494237523);
        assertEq(distributor.claimable(tokenId2), 82187996714809230);

        // epoch 3
        skipToNextEpoch(0); // distribute epoch 2's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 248835270851551532);
        assertEq(distributor.claimable(tokenId2), 246164484177010138);

        // epoch 4
        skipToNextEpoch(0); // distribute epoch 3's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 415260058561115763);
        assertEq(distributor.claimable(tokenId2), 409739533690323476);

        // epoch 5
        skipToNextEpoch(0); // distribute epoch 4's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 582088230654704388);
        assertEq(distributor.claimable(tokenId2), 572911199224930434);

        uint256 pre = convert(escrow.locked(tokenId).amount);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 1209600, 3628800, 582088230654704388);
        distributor.claim(tokenId);
        uint256 post = convert(escrow.locked(tokenId).amount);

        assertEq(post - pre, 582088230654704388);
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
        assertEq(distributor.claimable(tokenId), 164999939420311928);
        assertEq(distributor.claimable(tokenId2), 164999939420311928);

        skipToNextEpoch(0);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 329999878947032951);
        assertEq(distributor.claimable(tokenId2), 329999878947032951);

        uint256 pre = convert(escrow.locked(tokenId).amount);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 33868800, 35078400, 329999878947032951);
        distributor.claim(tokenId);
        uint256 post = convert(escrow.locked(tokenId).amount);

        assertEq(post - pre, 329999878947032951);
    }

    function testClaimWithIncreaseAmountOnEpochFlip() public {
        skipToNextEpoch(1 days); // epoch 1
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);

        skipToNextEpoch(0); // distribute epoch 1's rebases
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 82499958949295791);
        assertEq(distributor.claimable(tokenId2), 82499958949295791);

        skipToNextEpoch(0);
        assertEq(distributor.claimable(tokenId), 82499958949295791);
        assertEq(distributor.claimable(tokenId2), 82499958949295791);
        // making lock larger on flip should not impact claimable
        BTC.approve(address(escrow), TOKEN_1M);
        escrow.increaseAmount(tokenId, TOKEN_1M);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod(); // epoch 1's rebases available
        assertEq(distributor.claimable(tokenId), 247499876849822084);
        assertEq(distributor.claimable(tokenId2), 247499876849822084);
    }

    function testClaimWithExpiredNFT() public {
        // test reward claims to expired NFTs are distributed as unlocked BTC
        // ts: 608402
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, WEEK * 4);

        skipToNextEpoch(1);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 329976685987017980);

        for (uint256 i = 0; i < 4; i++) {
            deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
            chainFeeSplitter.updatePeriod();
            skipToNextEpoch(1);
        }
        chainFeeSplitter.updatePeriod();

        assertGt(distributor.claimable(tokenId), 329976685987017980); // accrued rebases

        IVotingEscrow.LockedBalance memory locked = escrow.locked(tokenId);
        assertGt(block.timestamp, locked.end); // lock expired

        uint256 rebase = distributor.claimable(tokenId);
        uint256 pre = BTC.balanceOf(address(owner));
        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(tokenId, 604800, 3024000, 992528240207157801);
        distributor.claim(tokenId);
        uint256 post = BTC.balanceOf(address(owner));

        locked = escrow.locked(tokenId); // update locked value post claim

        assertEq(post - pre, rebase); // expired rebase distributed as unlocked BTC
        assertEq(uint256(uint128(locked.amount)), TOKEN_1M); // expired nft locked balance unchanged
    }

    function testClaimManyWithExpiredNFT() public {
        // test claim many with one expired nft and one normal nft
        // ts: 608402
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, WEEK * 4);
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);

        skipToNextEpoch(1);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertEq(distributor.claimable(tokenId), 4714275796606329);
        assertEq(distributor.claimable(tokenId2), 325284853284521961);

        for (uint256 i = 0; i < 4; i++) {
            deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
            chainFeeSplitter.updatePeriod();
            skipToNextEpoch(1);
        }
        chainFeeSplitter.updatePeriod();

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

    function testClaimRebaseWithManagedLocks() public {
        chainFeeSplitter.updatePeriod(); // does nothing
        BTC.approve(address(escrow), type(uint256).max);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);
        escrow.lockPermanent(tokenId);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M, MAXTIME);
        escrow.lockPermanent(tokenId2);
        uint256 mTokenId = escrow.createManagedLockFor(address(owner));

        voter.depositManaged(tokenId2, mTokenId);

        skipAndRoll(1 hours); // created at epoch 0 + 1 days + 1 hours
        uint256 tokenId3 = escrow.createLock(TOKEN_1M, MAXTIME);
        escrow.lockPermanent(tokenId3);

        assertEq(distributor.claimable(tokenId), 0);
        assertEq(distributor.claimable(tokenId2), 0);
        assertEq(distributor.claimable(tokenId3), 0);
        assertEq(distributor.claimable(mTokenId), 0);

        skipToNextEpoch(0); // epoch 1
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        // epoch 0 rebases distributed
        assertEq(distributor.claimable(tokenId), 109999963609600793);
        assertEq(distributor.claimable(tokenId2), 0);
        assertEq(distributor.claimable(tokenId3), 109999963609600793);
        assertEq(distributor.claimable(mTokenId), 109999963609600793);

        skipAndRoll(1 days); // deposit @ epoch 1 + 1 days
        voter.depositManaged(tokenId3, mTokenId);

        skipToNextEpoch(0); // epoch 2
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        // epoch 1 rebases distributed
        assertEq(distributor.claimable(tokenId), 219999927395000557);
        assertEq(distributor.claimable(tokenId2), 0);
        assertEq(distributor.claimable(tokenId3), 109999963609600793);
        assertEq(distributor.claimable(mTokenId), 329999891180400321);
        distributor.claim(mTokenId); // claim token rewards
        assertEq(distributor.claimable(mTokenId), 0);

        uint256 tokenId4 = escrow.createLock(TOKEN_1M, MAXTIME); // lock created in epoch 2
        escrow.lockPermanent(tokenId4);

        skipToNextEpoch(1 hours); // epoch 3
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        // epoch 2 rebases distributed
        assertEq(distributor.claimable(tokenId), 302011734796681236);
        assertEq(distributor.claimable(tokenId2), 0);
        assertEq(distributor.claimable(tokenId3), 109999963609600793); // claimable unchanged
        assertEq(distributor.claimable(tokenId4), 82011807401680679); // claim rebases from last epoch
        assertEq(distributor.claimable(mTokenId), 164023641867248877);

        skipToNextEpoch(0); // epoch 4
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        // rewards for epoch 2 locks
        assertEq(distributor.claimable(tokenId), 384999873338330165);
        assertEq(distributor.claimable(tokenId2), 0);
        assertEq(distributor.claimable(tokenId3), 109999963609600793); // claimable unchanged
        assertEq(distributor.claimable(tokenId4), 164999945943329608);
        assertEq(distributor.claimable(mTokenId), 329999946336623424);

        skipAndRoll(1 hours + 1);
        voter.withdrawManaged(tokenId3);

        for (uint256 i = 0; i <= 6; i++) {
            if (i == tokenId2) continue;
            distributor.claim(i);
            assertEq(distributor.claimable(i), 0);
        }

        assertLt(BTC.balanceOf(address(distributor)), 100); // dust
    }

    function testClaimRebaseWithDepositManaged() public {
        chainFeeSplitter.updatePeriod(); // does nothing
        vm.startPrank(address(owner2));
        BTC.approve(address(escrow), TOKEN_10M);
        uint256 tokenId = escrow.createLock(TOKEN_10M, MAXTIME);
        escrow.lockPermanent(tokenId);
        vm.stopPrank();

        vm.startPrank(address(owner3));
        BTC.approve(address(escrow), TOKEN_10M);
        uint256 tokenId2 = escrow.createLock(TOKEN_10M, MAXTIME);
        escrow.lockPermanent(tokenId2);
        vm.stopPrank();
        uint256 mTokenId = escrow.createManagedLockFor(address(owner));

        assertEq(distributor.claimable(tokenId), 0);
        assertEq(distributor.claimable(tokenId2), 0);
        assertEq(distributor.claimable(mTokenId), 0);

        skipToNextEpoch(0); // epoch 1
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        // epoch 0 rebases distributed
        assertEq(distributor.claimable(tokenId), 164999991812157876);
        assertEq(distributor.claimable(tokenId2), 164999991812157876);
        assertEq(distributor.claimable(mTokenId), 0);

        skipAndRoll(1 days);
        vm.prank(address(owner3));
        voter.depositManaged(tokenId2, mTokenId);

        assertEq(distributor.claimable(tokenId), 164999991812157876);
        assertEq(distributor.claimable(tokenId2), 164999991812157876);
        assertEq(distributor.claimable(mTokenId), 0);

        skipToNextEpoch(1 hours); // epoch 2
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        assertEq(distributor.claimable(tokenId), 329023652351138514);
        assertEq(distributor.claimable(tokenId2), 164999991812157876); // claimable unchanged
        assertEq(distributor.claimable(mTokenId), 164023660538980638); // rebase earned by tokenId2

        skipAndRoll(1);
        vm.prank(address(owner3));
        voter.withdrawManaged(tokenId2);

        skipToNextEpoch(0); // epoch 3
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        assertEq(distributor.claimable(tokenId), 495627592446708318);
        assertEq(distributor.claimable(tokenId2), 330348698063368142);
        assertEq(distributor.claimable(mTokenId), 164023660538980638); // claimable unchanged
    }

    function testCannotClaimRebaseWithLockedNFT() public {
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);
        escrow.lockPermanent(tokenId);
        uint256 mTokenId = escrow.createManagedLockFor(address(owner));

        skipToNextEpoch(2 hours); // epoch 1
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        assertEq(distributor.claimable(tokenId), 326117323398545910);
        assertEq(distributor.claimable(mTokenId), 0);

        voter.depositManaged(tokenId, mTokenId);

        skipToNextEpoch(1 days); // epoch 3
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        vm.expectRevert(IRewardsDistributor.NotManagedOrNormalNFT.selector);
        distributor.claim(tokenId);
    }

    function testCannotClaimBeforeUpdatePeriod() public {
        BTC.approve(address(escrow), type(uint256).max);
        uint256 tokenId = escrow.createLock(TOKEN_1M, MAXTIME);
        uint256 tokenId2 = escrow.createLock(TOKEN_1M * 8, MAXTIME);

        skipToNextEpoch(2 hours); // epoch 1
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        assertEq(distributor.claimable(tokenId), 36235290091503713);
        assertEq(distributor.claimable(tokenId2), 289882320732029728);

        skipToNextEpoch(1 hours); // epoch 3
        vm.expectRevert(IRewardsDistributor.UpdatePeriod.selector);
        distributor.claim(tokenId);

        skipAndRoll(1 hours);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();

        distributor.claim(tokenId);
    }

    function testCannotCheckpointTokenIfNotDepositor() public {
        vm.expectRevert(IRewardsDistributor.NotDepositor.selector);
        vm.prank(address(owner2));
        distributor.checkpointToken();
    }

    function testClaimBeforeLockedEnd() public {
        uint256 duration = WEEK * 12;
        vm.startPrank(address(owner));
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, duration);

        skipToNextEpoch(1);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertGt(distributor.claimable(tokenId), 0);

        IVotingEscrow.LockedBalance memory locked = escrow.locked(tokenId);
        vm.warp(locked.end - 1);
        assertEq(block.timestamp, locked.end - 1);
        chainFeeSplitter.updatePeriod();

        // Rebase should deposit into veNFT one second before expiry
        distributor.claim(tokenId);
        locked = escrow.locked(tokenId);
        assertGt(uint256(uint128((locked.amount))), TOKEN_1M);
    }

    function testClaimOnLockedEnd() public {
        uint256 duration = WEEK * 12;
        vm.startPrank(address(owner));
        BTC.approve(address(escrow), TOKEN_1M);
        uint256 tokenId = escrow.createLock(TOKEN_1M, duration);

        skipToNextEpoch(1);
        deal(address(BTC), address(chainFeeSplitter), TOKEN_1);
        chainFeeSplitter.updatePeriod();
        assertGt(distributor.claimable(tokenId), 0);

        IVotingEscrow.LockedBalance memory locked = escrow.locked(tokenId);
        vm.warp(locked.end);
        assertEq(block.timestamp, locked.end);
        chainFeeSplitter.updatePeriod();

        // Rebase should deposit into veNFT one second before expiry
        uint256 balanceBefore = BTC.balanceOf(address(owner));
        distributor.claim(tokenId);
        assertGt(BTC.balanceOf(address(owner)), balanceBefore);
    }
}
