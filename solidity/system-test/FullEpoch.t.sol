pragma solidity 0.8.24;

import {BaseSystemTest} from "./BaseSystemTest.sol";
import {IGovernor} from "contracts/governance/IGovernor.sol";
import {Splitter} from "contracts/Splitter.sol";
import {GovernorCountingMajority} from "contracts/governance/GovernorCountingMajority.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TestERC20} from "contracts/test/TestERC20.sol";
import {IRouter} from "contracts/interfaces/IRouter.sol";
import {IGauge} from "contracts/interfaces/IGauge.sol";
import {IPool} from "contracts/interfaces/IPool.sol";

contract FullEpoch is BaseSystemTest {
    // veBTC holders
    address public user1;
    address public user2;
    address public user3;
    // liquidity providers
    address public user4;
    address public user5;
    address public user6;
    // trader
    address public user7;

    /// @dev This test executes a full protocol epoch with actions like
    ///      - locking BTC into veBTC
    ///      - adding liquidity into the pools (liquidity providers)
    ///      - staking LP tokens into gauges (liquidity providers)
    ///      - swapping tokens in the pools (traders)
    ///      - voting on the chain fee splitter needle movement
    ///      - voting on pool gauges
    ///      - distributing the BTC chain fees between gauges and reward distributor
    ///      - claiming trading fees from gauges (veBTC voters)
    ///      - claiming trading fees from pools (non-staking liquidity providers)
    ///      - claiming BTC rewards from gauges (staking liquidity providers)
    ///
    /// This scenario DOES NOT stress extended actions like:
    ///      - claiming BTC rewards from the reward distributor (veBTC holders)
    ///      - claiming bribes from gauges (veBTC voters)
    function testFullEpoch() public {
        // Start Epoch 1 and move to its first second.
        // Assume this is timestamp T + 1s, where T is Epoch 1 start.
        skipToNextEpoch(1);
        uint256 epoch1Start = vm.getBlockTimestamp() - 1;

        // Update the period in the splitter as it was deployed in the previous epoch.
        chainFeeSplitter.updatePeriod();
        assertEq(
            chainFeeSplitter.activePeriod(),
            epoch1Start,
            "unexpected chain fee splitter active period"
        );

        // Define veBTC holders.
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        // Define liquidity providers.
        user4 = accounts[4]; // stakes LP tokens  
        user5 = accounts[5]; // stakes LP tokens
        user6 = accounts[6]; // DOES NOT stake LP tokens
        // Define traders.
        user7 = accounts[7];

        // *********************************************************************************
        // Locking BTC into veBTC
        // *********************************************************************************
        
        // Mint BTC to the users.
        vm.startPrank(governance);
        BTC.mint(user1, withTokenPrecision18(10));
        BTC.mint(user2, withTokenPrecision18(10));
        BTC.mint(user3, withTokenPrecision18(10));
        vm.stopPrank();

        // Mint veBTC to the users.
        uint256 user1TokenId = mintVeBTC(user1, withTokenPrecision18(10), YEAR);
        uint256 user2TokenId = mintVeBTC(user2, withTokenPrecision18(10), 2 * YEAR);
        uint256 user3TokenId = mintVeBTC(user3, withTokenPrecision18(10), 4 * YEAR); // max lock duration

        // Check veBTC balances and total supply.
        // Balance of NFT is a function at timestamp t defined as:
        // - balance(t) = bias - slope * (t - last_checkpoint).
        //
        // Upon lock creation, function parameters are set as follows:
        // - slope = locked_amount / max_lock_duration
        // - bias = slope * (lock_end - lock_start) = slope * lock_duration
        // - last_checkpoint = lock_start (this is NFT-specific)
        //
        // Notes:
        // - The slope and bias parameters are modified upon each checkpoint.
        // - The lock_duration must be rounded down to weeks using integer arithmetic
        //   (i.e. (lock_duration / 604800) * 604800) and offset by the
        //   difference between lock_start and epoch start.

        // User1 balance calculation, at timestamp T + 1s:
        // - lock_duration = (((365 * 86400) / 604800) * 604800) - 1 = 52 (rounded) * 604800 - 1 (offset) = 31449599
        // - slope = (10 * 1e18) / (4 * 365 * 86400) = 79274479959
        // - bias = 79274479959 * 31449599 = 2493150605644086441
        // - balance = 2493150605644086441 - 79274479959 * 0 = 2493150605644086441
        assertEq(veBTC.balanceOfNFT(user1TokenId), 2493150605644086441, "unexpected user1 token veBTC balance");

        // User2 balance calculation, at timestamp T + 1s:
        // - lock_duration = (((2 * 365 * 86400) / 604800) * 604800) - 1 = 104 (rounded) * 604800 - 1 (offset) = 62899199
        // - slope = (10 * 1e18) / (4 * 365 * 86400) = 79274479959
        // - bias = 79274479959 * 62899199 = 4986301290562652841
        // - balance = 4986301290562652841 - 79274479959 * 0 = 4986301290562652841
        assertEq(veBTC.balanceOfNFT(user2TokenId), 4986301290562652841, "unexpected user2 token veBTC balance");

        // User3 balance calculation, at timestamp T + 1s:
        // - lock_duration = (((4 * 365 * 86400) / 604800) * 604800) - 1 = 208 (rounded) * 604800 - 1 (offset) = 125798399
        // - slope = (10 * 1e18) / (4 * 365 * 86400) = 79274479959
        // - bias = 79274479959 * 125798399 = 9972602660399785641
        // - balance = 9972602660399785641 - 79274479959 * 0 = 9972602660399785641
        assertEq(veBTC.balanceOfNFT(user3TokenId), 9972602660399785641, "unexpected user3 token veBTC balance");

        // Sum of all veBTC balances.
        assertEq(veBTC.totalSupply(), 17452054556606524923, "unexpected veBTC total supply");

        // Make sure BTC was transferred to the veBTC contract as expected.
        assertEq(BTC.balanceOf(user1), 0, "unexpected user1 BTC balance");
        assertEq(BTC.balanceOf(user2), 0, "unexpected user2 BTC balance");
        assertEq(BTC.balanceOf(user3), 0, "unexpected user3 BTC balance");
        assertEq(BTC.balanceOf(address(veBTC)), withTokenPrecision18(30), "unexpected veBTC contract BTC balance");

        // *********************************************************************************
        // Adding liquidity into the pools
        // *********************************************************************************    

        // Assert pools state.
        assertEq(veBTCVoter.length(), 3, "unexpected pools count");

        // Add liquidity to pools.
        addLiquidityToPool(user4, address(BTC), address(mUSD), withTokenPrecision18(10), withTokenPrecision18(10));
        addLiquidityToPool(user5, address(mUSD), address(LIMPETH), withTokenPrecision18(10), withTokenPrecision18(10));
        addLiquidityToPool(user6, address(mUSD), address(wtBTC), withTokenPrecision18(10), withTokenPrecision18(10));

        // Assert LP token balances for each liquidity provider.
        // We expect each liquidity provider to have all liquidity in the pool minus the minimum liquidity.
        // The pool locks the minimum liquidity upon first liquidity addition in order to prevent the pool 
        // from being drained completely and to avoid division by zero scenarios in the calculations.
        uint256 minimumLiquidity = 10 ** 3;
        assertEq(IERC20(pool_BTC_mUSD).balanceOf(user4), IERC20(pool_BTC_mUSD).totalSupply() - minimumLiquidity, "user4 should own proper amount of pool LP tokens");
        assertEq(IERC20(pool_mUSD_LIMPETH).balanceOf(user5), IERC20(pool_mUSD_LIMPETH).totalSupply() - minimumLiquidity, "user5 should own proper amount of pool LP tokens");
        assertEq(IERC20(pool_mUSD_wtBTC).balanceOf(user6), IERC20(pool_mUSD_wtBTC).totalSupply() - minimumLiquidity, "user6 should own proper amount of pool LP tokens");

        // *********************************************************************************
        // Staking LP tokens into gauges
        // *********************************************************************************

        // Stake LP tokens for user4 and user5 but not for user6.
        stakeGauge(user4, pool_BTC_mUSD); 
        stakeGauge(user5, pool_mUSD_LIMPETH);

        // *********************************************************************************
        // Swapping tokens in the pools
        // *********************************************************************************    

        // Execute trades on each pool with user7.
        executeSwap(
            user7,
            address(BTC),
            address(mUSD),
            withTokenPrecision18(5),
            0, // No min amount for test
            false, // Not stable
            address(poolFactory)
        );
        executeSwap(
            user7,
            address(mUSD),
            address(LIMPETH),
            withTokenPrecision18(6),
            0, // No min amount for test
            false, // Not stable
            address(poolFactory)
        );
        executeSwap(
            user7,
            address(mUSD),
            address(wtBTC),
            withTokenPrecision18(7),
            0, // No min amount for test
            false, // Not stable
            address(poolFactory)
        );

        // *********************************************************************************
        // Voting on the chain fee splitter needle movement
        // *********************************************************************************

        // Load the chain fee splitter with BTC.
        vm.prank(governance);
        BTC.mint(address(chainFeeSplitter), withTokenPrecision18(100));

        // Create a proposal to nudge the chain fee splitter.
        uint256 proposalId = proposeChainFeeSplitterNudge(user3, user3TokenId);

        // Assert state before the proposal voting:
        // --- assert voting parameters:
        (uint256 votingDelay, uint256 votingPeriod) = (15 minutes, 1 weeks);
        assertEq(veBTCEpochGovernor.votingDelay(), votingDelay, "unexpected voting delay");
        assertEq(veBTCEpochGovernor.votingPeriod(), votingPeriod, "unexpected voting period");
        // --- assert proposal state:
        assertEq(uint256(veBTCEpochGovernor.state(proposalId)), uint256(IGovernor.ProposalState.Pending), "unexpected proposal status");
        assertEq(uint256(veBTCEpochGovernor.result()), uint256(IGovernor.ProposalState.Pending), "unexpected result");
        // --- assert proposal votes:
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = veBTCEpochGovernor.proposalVotes(proposalId);
        assertEq(againstVotes, 0, "unexpected against votes");
        assertEq(forVotes, 0, "unexpected for votes");
        assertEq(abstainVotes, 0, "unexpected abstain votes");
        // --- assert proposal snapshot and deadline:
        assertEq(veBTCEpochGovernor.proposalSnapshot(proposalId), vm.getBlockTimestamp() + votingDelay, "unexpected proposal snapshot");
        assertEq(veBTCEpochGovernor.proposalDeadline(proposalId), vm.getBlockTimestamp() + votingDelay + votingPeriod, "unexpected proposal deadline");

        // We must go past the voting delay (15m since proposal creation) to allow voting.
        // We created the proposal at T + 1s, we need to jump 15m1s at least.
        // We land at T + 15m2s after the jump.
        skip(votingDelay + 1);
        assertEq(uint256(veBTCEpochGovernor.state(proposalId)), uint256(IGovernor.ProposalState.Active), "unexpected proposal status");

        // Cast votes.
        vm.prank(user1);
        veBTCEpochGovernor.castVote(proposalId, user1TokenId, uint8(GovernorCountingMajority.VoteType.Against));
        vm.prank(user2);
        veBTCEpochGovernor.castVote(proposalId, user2TokenId, uint8(GovernorCountingMajority.VoteType.Against));
        vm.prank(user3);
        veBTCEpochGovernor.castVote(proposalId, user3TokenId, uint8(GovernorCountingMajority.VoteType.For));

        // Assert proposal votes after voting. Voting power of all users
        // decayed a bit since locks creation (which happened at T + 1s)
        // because we actually moved 15m (900s) ahead from this point.
        // The slope is the same for all users - 79274479959.
        // That said, voting power per user decayed by 79274479959 * 900 = 71347031963100.
        (againstVotes, forVotes, abstainVotes) = veBTCEpochGovernor.proposalVotes(proposalId);
        // User1 and User2 with respective initial voting power of
        // 2493150605644086441 and 4986301290562652841 were against.
        // Total against including the 15m decay should be:
        // (2493150605644086441 - 71347031963100) + (4986301290562652841 - 71347031963100) = 7479309202142813082
        assertEq(againstVotes, 7479309202142813082, "unexpected against votes");
        // User3 with initial voting power of 9972602660399785641 was for.
        // Total for including the 15m decay should be:
        // 9972602660399785641 - 71347031963100 = 9972531313367822541
        assertEq(forVotes, 9972531313367822541, "unexpected for votes");
        assertEq(abstainVotes, 0, "unexpected abstain votes");

        // *********************************************************************************
        // Voting on pool gauges
        // *********************************************************************************

        // Gauge voting can start at T + 1h1s (see TimeLibrary.epochVoteStart).
        // We are already at T + 15m2s, so we need to jump 44m59s ahead.
        skip(45 minutes - 1);

        // User1 splits its voting power on all pools evenly.
        address[] memory poolVote = new address[](3);
        poolVote[0] = pool_BTC_mUSD;
        poolVote[1] = pool_mUSD_LIMPETH;
        poolVote[2] = pool_mUSD_wtBTC;
        uint256[] memory weights = new uint256[](3);
        weights[0] = 3333; // 3333 BPS
        weights[1] = 3333;
        weights[2] = 3334;
        vm.prank(user1);
        veBTCVoter.vote(user1TokenId, poolVote, weights);

        // User2 splits its voting power on the first two pools evenly.
        poolVote = new address[](2);
        poolVote[0] = pool_BTC_mUSD;
        poolVote[1] = pool_mUSD_LIMPETH;
        weights = new uint256[](2);
        weights[0] = 5000; // 5000 BPS
        weights[1] = 5000;
        vm.prank(user2);
        veBTCVoter.vote(user2TokenId, poolVote, weights);

        // User3 allocates its entire voting power to the last pool.
        poolVote = new address[](1);
        poolVote[0] = pool_mUSD_wtBTC;
        weights = new uint256[](1);
        weights[0] = 10000; // 10000 BPS
        vm.prank(user3);
        veBTCVoter.vote(user3TokenId, poolVote, weights);

        // Assert pool weights after voting. Voting power of all users
        // decayed a bit since locks creation (which happened at T + 1s)
        // because we actually moved 1h (3600s) ahead from this point.
        // The slope is the same for all users - 79274479959.
        // That said, voting power per user decayed by 79274479959 * 3600 = 285388127852400.
        // Current voting power of users:
        // - User1: 2493150605644086441 - 285388127852400 = 2492865217516234041
        // - User2: 4986301290562652841 - 285388127852400 = 4986015902434800441
        // - User3: 9972602660399785641 - 285388127852400 = 9972317272271933241

        // Total weight of the first pool should be a sum of:
        // - User1: 3333 * 2492865217516234041 / 10000 = 830871976998160805 (rounded down)
        // - User2: 5000 * 4986015902434800441 / 10000 = 2493007951217400220 (rounded down)
        // So, 830871976998160805 + 2493007951217400220 = 3323879928215561025
        assertEq(veBTCVoter.weights(pool_BTC_mUSD), 3323879928215561025, "unexpected BTC_mUSD pool weight");
        // Total weight of the second pool should be a sum of:
        // - User1: 3333 * 2492865217516234041 / 10000 = 830871976998160805 (rounded down)
        // - User2: 5000 * 4986015902434800441 / 10000 = 2493007951217400220 (rounded down)
        // So, 830871976998160805 + 2493007951217400220 = 3323879928215561025
        assertEq(veBTCVoter.weights(pool_mUSD_LIMPETH), 3323879928215561025, "unexpected mUSD_LIMPETH pool weight");
        // Total weight of the third pool should be a sum of:
        // - User1: 3334 * 2492865217516234041 / 10000 = 831121263519912429 (rounded down)
        // - User3: 10000 * 9972317272271933241 / 10000 = 9972317272271933241 (rounded down)
        // So, 831121263519912429 + 9972317272271933241 = 10803438535791845670
        assertEq(veBTCVoter.weights(pool_mUSD_wtBTC), 10803438535791845670, "unexpected mUSD_wtBTC pool weight");
        // Sum of all pool weights:
        // 3323879928215561025 + 3323879928215561025 + 10803438535791845670 = 17451198392222967720.
        assertEq(veBTCVoter.totalWeight(), 17451198392222967720, "unexpected voter total weight");

        // *********************************************************************************
        // Distributing the BTC chain fees between gauges and reward distributor
        // *********************************************************************************

        // We are at T + 1h1s and we want to jump to the place where the
        // ChainFeeSplitter nudge proposal can be executed:
        // - proposal_creation = T + 1s (proposal was created during the first second of Epoch 1)
        // - proposal_deadline = proposal_creation + voting_delay + voting_period =
        //   T + 1s + 15m + 1w = T + 1w15m1s
        // - Execution is possible past proposal_deadline so we need to
        //   jump to T + 1w15m2s.
        //
        // First, we jump to the beginning of Epoch 2 which is effectively T + 1w
        skipToNextEpoch(0);
        uint256 epoch2Start = vm.getBlockTimestamp();
        // Then, we jump the remaining 15m2s. We are at T + 1w15m2s.
        skip(votingDelay + 2);

        // Assert needle state before proposal execution.
        assertEq(chainFeeSplitter.needle(), 33, "unexpected needle value");
        // Execute the proposal and assert the new needle is as expected.
        executeChainFeeSplitterNudge();
        assertEq(uint256(veBTCEpochGovernor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
        assertEq(uint256(veBTCEpochGovernor.result()), uint256(IGovernor.ProposalState.Succeeded));
        assertEq(chainFeeSplitter.needle(), 34, "unexpected needle value");

        // Prepare for period update in the ChainFeeSplitter. Assert
        // we are still in the old period inside.
        assertEq(
            chainFeeSplitter.activePeriod(),
            epoch1Start,
            "unexpected chain fee splitter active period"
        );
        // Update period in the ChainFeeSplitter and distribute the accumulated
        // fees among gauges and veBTC holders.
        vm.expectEmit(true, true, true, true, address(chainFeeSplitter));
        // The needle is 34 so we expect 34% of 100 BTC accumulated on the
        // splitter to go veBTC holders (through the RewardsDistributor contract)
        // and the remaining 66% to gauges.
        emit Splitter.PeriodUpdated(epoch1Start, epoch2Start, withTokenPrecision18(34), withTokenPrecision18(66));
        veBTCVoter.distribute(0, veBTCVoter.length());

        // ChainFeeSplitter's BTC balance should be zeroed out.
        assertEq(BTC.balanceOf(address(chainFeeSplitter)), 0, "unexpected chain fee splitter BTC balance");

        // 34 BTC should be pushed to RewardsDistributor so veBTC holders
        // can claim their share from there in the next epoch.
        assertEq(BTC.balanceOf(address(veBTCRewardsDistributor)), withTokenPrecision18(34), "unexpected rewards distributor BTC balance");

        // Claims will be available in the next epoch. For now, it should be 0 for all.
        assertEq(veBTCRewardsDistributor.claimable(user1TokenId), 0, "unexpected claimable for user1 token");
        assertEq(veBTCRewardsDistributor.claimable(user2TokenId), 0, "unexpected claimable for user2 token");
        assertEq(veBTCRewardsDistributor.claimable(user3TokenId), 0, "unexpected claimable for user3 token");

        // Gauge BTC share is calculated as follows:
        // - ratio = total_btc_reward * 1e18 / total_pool_weight
        // - share = (pool_weight * ratio) / 1e18
        // In our case, total_btc_reward is the 66 BTC distributed to gauges,
        // and total_pool_weight is 17451198392222967720 (computed after gauge voting earlier).
        // That said, ratio = 66 * 1e18 * 1e18 / 17451198392222967720 = 3781975226951321774 (rounded down)

        // The BTC_mUSD pool vote weight was 3323879928215561025.
        // share = (3323879928215561025 * 3781975226951321774) / 1e18 = 12570831545871989534 (rounded down)
        assertEq(BTC.balanceOf(address(veBTCVoter.gauges(pool_BTC_mUSD))), 12570831545871989534, "unexpected BTC_mUSD gauge BTC balance");
        // The mUSD_LIMPETH pool vote weight was 3323879928215561025.
        // share = (3323879928215561025 * 3781975226951321774) / 1e18 = 12570831545871989534 (rounded down)
        assertEq(BTC.balanceOf(address(veBTCVoter.gauges(pool_mUSD_LIMPETH))), 12570831545871989534, "unexpected mUSD_LIMPETH gauge BTC balance");
        // The mUSD_wtBTC pool vote weight was 10803438535791845670.
        // share = (10803438535791845670 * 3781975226951321774) / 1e18 = 40858336908256020929 (rounded down)
        assertEq(BTC.balanceOf(address(veBTCVoter.gauges(pool_mUSD_wtBTC))), 40858336908256020929, "unexpected mUSD_wtBTC gauge BTC balance");

        // *********************************************************************************
        // Claiming trading fees from gauges
        // *********************************************************************************

        // Skip to Epoch 3 which is effectively T + 2w.
        // This is required to claim trading fees from gauges, 
        // that were distributed in the previous epoch.
        skipToNextEpoch(0);

        // Each gauge has a FeesVotingReward contract where trading fees are pushed for distribution 
        // to veBTC holders (this happens during the veBTCVoter.distribute call done earlier).
        // Assert balances of FeesVotingReward contracts before veBTC holders claim fees.
        // In general, claimable_fees for the given LP token holder is calculated as follows:
        // - claimable_fees = (lp_token_balance * fee_index) / 1e18
        // - [for each swap] fee_index += (((swap_amount * fee) / 10000) * 1e18) / lp_token_total_supply
        //
        // Notes:
        // - As we check total claimable fees, we assume lp_token_balance = lp_token_total_supply.
        // - Each pool had one liquidity provision transaction. A 10 * 1e18 of each token from the pair was added to the pool.
        //   That said, lp_token_total_supply can be computed as sqrt(amountA * amountB) - minimum_liquidity (see Pool.mint).
        //   In our case, lp_token_total_supply = sqrt((10 * 1e18) * (10 * 1e18)) - 1000 = 9999999999999999000.
        // - Each pool had a single swap.
        // - Each pool is unstable. Fee for unstable pool is 4 (0.04%).

        // Check the BTC_mUSD pool. 
        // - swap_amount = 5 * 1e18 BTC
        // - fee_index += (((5 * 1e18 * 4) / 10000) * 1e18) / 9999999999999999000 = 200000000000000 (rounded down)
        // - claimable_fees = (9999999999999999000 * 200000000000000) / 1e18 = 1999999999999999 (rounded down)
        assertFeesVotingRewardBalance(pool_BTC_mUSD, address(BTC), 1999999999999999);
        assertFeesVotingRewardBalance(pool_BTC_mUSD, address(mUSD), 0);
        // Check the mUSD_LIMPETH pool.
        // - swap_amount = 6 * 1e18 mUSD
        // - fee_index += (((6 * 1e18 * 4) / 10000) * 1e18) / 9999999999999999000 = 240000000000000 (rounded down)
        // - claimable_fees = (9999999999999999000 * 240000000000000) / 1e18 = 2399999999999999 (rounded down)
        assertFeesVotingRewardBalance(pool_mUSD_LIMPETH, address(mUSD), 2399999999999999);
        assertFeesVotingRewardBalance(pool_mUSD_LIMPETH, address(LIMPETH), 0);
        // Check the mUSD_wtBTC pool. There was one swap but the single LP provider of this pool (user6) 
        // did not stake its LP tokens to the gauge. That said, the FeesVotingReward contract for 
        // this pool did not receive any fees. Fees can be claimed by the LP provider, directly from the pool.
        // For the sake of the future assertion, the mUSD fees claimable directly from the pool are computed
        // as follows (remember this is not available in the FeesVotingReward contract hence the two following assertions expect 0):
        // - swap_amount = 7 * 1e18 mUSD
        // - fee_index += (((7 * 1e18 * 4) / 10000) * 1e18) / 9999999999999999000 = 280000000000000 (rounded down)
        // - claimable_fees = (9999999999999999000 * 280000000000000) / 1e18 = 2799999999999999 (rounded down)
        assertFeesVotingRewardBalance(pool_mUSD_wtBTC, address(mUSD), 0);
        assertFeesVotingRewardBalance(pool_mUSD_wtBTC, address(wtBTC), 0);

        // Capture initial balances of pool tokens for each veBTC holder before fees were claimed.
        // First level of array is for each veBTC holder.
        // Second level of array is for each pool token.
        // We use an array to avoid stack too deep error.
        uint256[][] memory preClaimBalances = new uint256[][](3);
        // Sub-array for user1.
        preClaimBalances[0] = new uint256[](4);
        preClaimBalances[0][0] = BTC.balanceOf(user1);
        preClaimBalances[0][1] = mUSD.balanceOf(user1);
        preClaimBalances[0][2] = LIMPETH.balanceOf(user1);
        preClaimBalances[0][3] = wtBTC.balanceOf(user1);
        // Sub-array for user2. 
        preClaimBalances[1] = new uint256[](4);
        preClaimBalances[1][0] = BTC.balanceOf(user2);
        preClaimBalances[1][1] = mUSD.balanceOf(user2);
        preClaimBalances[1][2] = LIMPETH.balanceOf(user2);
        preClaimBalances[1][3] = wtBTC.balanceOf(user2);
        // Sub-array for user3.
        preClaimBalances[2] = new uint256[](4);
        preClaimBalances[2][0] = BTC.balanceOf(user3);
        preClaimBalances[2][1] = mUSD.balanceOf(user3);
        preClaimBalances[2][2] = LIMPETH.balanceOf(user3);
        preClaimBalances[2][3] = wtBTC.balanceOf(user3);

        claimVeBTCVoterFees(user1, user1TokenId);
        claimVeBTCVoterFees(user2, user2TokenId);
        claimVeBTCVoterFees(user3, user3TokenId);

        // Assert balances of specific pool tokens for each veBTC holder after claiming fees.
        // Based on the information above, following fees are available in the pools' FeesVotingReward
        // contracts for veBTC voters:
        // - 1999999999999999 BTC fees from BTC_mUSD pool
        // - 2399999999999999 mUSD fees from mUSD_LIMPETH pool
        //
        // Moreover, the LP provider of the mUSD_wtBTC pool can claim 2799999999999999 mUSD of fees directly from the pool.
        //
        // Assert for user1. It has:
        // - 830871976998160805 out of 3323879928215561025 total weight for the BTC_mUSD pool.
        //   BTC share is 1999999999999999 * 830871976998160805 / 3323879928215561025 = 499941029725593 (rounded down).
        // - 830871976998160805 out of 3323879928215561025 total weight for the mUSD_LIMPETH pool.
        //   mUSD share is 2399999999999999 * 830871976998160805 / 3323879928215561025 = 599929235670712 (rounded down).
        assertTokenBalanceChange(user1, address(BTC), preClaimBalances[0][0], 499941029725593);
        assertTokenBalanceChange(user1, address(mUSD), preClaimBalances[0][1], 599929235670712);
        assertTokenBalanceChange(user1, address(LIMPETH), preClaimBalances[0][2], 0);
        assertTokenBalanceChange(user1, address(wtBTC), preClaimBalances[0][3], 0);
        // Assert for user2. It has:
        // - 2493007951217400220 out of 3323879928215561025 total weight for the BTC_mUSD pool.
        //   BTC share is 1999999999999999 * 2493007951217400220 / 3323879928215561025 = 1500058970274405 (rounded down).
        // - 2493007951217400220 out of 3323879928215561025 total weight for the mUSD_LIMPETH pool.
        //   mUSD share is 2399999999999999 * 2493007951217400220 / 3323879928215561025 = 1800070764329286 (rounded down).
        assertTokenBalanceChange(user2, address(BTC), preClaimBalances[1][0], 1500058970274405);
        assertTokenBalanceChange(user2, address(mUSD), preClaimBalances[1][1], 1800070764329286);
        assertTokenBalanceChange(user2, address(LIMPETH), preClaimBalances[1][2], 0);
        assertTokenBalanceChange(user2, address(wtBTC), preClaimBalances[1][3], 0);
        // Assert for user3. It voted on the mUSD_wtBTC pool whose LP provider did not stake its LP tokens to the gauge.
        // That said, user3 should not receive any fees.
        assertTokenBalanceChange(user3, address(BTC), preClaimBalances[2][0], 0);
        assertTokenBalanceChange(user3, address(mUSD), preClaimBalances[2][1], 0);
        assertTokenBalanceChange(user3, address(LIMPETH), preClaimBalances[2][2], 0);
        assertTokenBalanceChange(user3, address(wtBTC), preClaimBalances[2][3], 0);

        // *********************************************************************************
        // Claiming trading fees from pools
        // *********************************************************************************    

        // User6 is the LP provider of the mUSD_wtBTC pool. User6 can claim fees from the pool directly
        // because they did not stake their LP tokens to the gauge.
        vm.prank(user6);
        IPool(pool_mUSD_wtBTC).claimFees();
        assertTokenBalanceChange(user6, address(BTC), preClaimBalances[2][0], 0);
        assertTokenBalanceChange(user6, address(mUSD), preClaimBalances[2][1], 2799999999999999);
        assertTokenBalanceChange(user6, address(LIMPETH), preClaimBalances[2][2], 0);
        assertTokenBalanceChange(user6, address(wtBTC), preClaimBalances[2][3], 0);

        // *********************************************************************************
        // Claiming BTC rewards from gauges
        // *********************************************************************************
        
        // TODO: Implement this.
    }

    function mintVeBTC(address user, uint256 amount, uint256 lockDuration) internal returns (uint256 tokenId) {
        vm.startPrank(user);
        BTC.approve(address(veBTC), amount);
        tokenId = veBTC.createLock(amount, lockDuration);
        vm.stopPrank();
    }

    function addLiquidityToPool(
        address user,
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal {
        uint256 initialBalanceA = IERC20(tokenA).balanceOf(user);
        uint256 initialBalanceB = IERC20(tokenB).balanceOf(user);

        vm.startPrank(governance);
        TestERC20(tokenA).mint(user, amountA);
        TestERC20(tokenB).mint(user, amountB);
        vm.stopPrank();

        assertEq(IERC20(tokenA).balanceOf(user), initialBalanceA + amountA, "user should have the correct amount of tokenA");
        assertEq(IERC20(tokenB).balanceOf(user), initialBalanceB + amountB, "user should have the correct amount of tokenB");

        vm.startPrank(user);
        IERC20(tokenA).approve(address(router), amountA);
        IERC20(tokenB).approve(address(router), amountB);
        router.addLiquidity(
            tokenA,
            tokenB,
            false, // not stable
            amountA,
            amountB,
            0, // no slippage protection for test
            0,
            user,
            vm.getBlockTimestamp() + 1 hours
        );
        vm.stopPrank();
        
        assertEq(IERC20(tokenA).balanceOf(user), initialBalanceA, "user should have the correct amount of tokenA");
        assertEq(IERC20(tokenB).balanceOf(user), initialBalanceB, "user should have the correct amount of tokenB");
    }

    function stakeGauge(address user, address pool) internal {
        address gauge = veBTCVoter.gauges(pool);
        assertNotEq(gauge, address(0), "gauge should exist");

        uint256 initialUserPoolBalance = IERC20(pool).balanceOf(user);
        assertNotEq(initialUserPoolBalance, 0, "user should have some LP tokens");

        uint256 initialGaugePoolBalance = IERC20(pool).balanceOf(gauge);

        vm.startPrank(user);
        IERC20(pool).approve(gauge, initialUserPoolBalance);
        IGauge(gauge).deposit(initialUserPoolBalance);
        vm.stopPrank();

        assertEq(IERC20(pool).balanceOf(user), 0, "user should have spent all of pool LP tokens");
        assertEq(IERC20(pool).balanceOf(gauge), initialGaugePoolBalance + initialUserPoolBalance, "gauge should have the correct amount of pool LP tokens");
    }

    function proposeChainFeeSplitterNudge(
        address user,
        uint256 tokenId
    ) internal returns (uint256 proposalId) {
        address[] memory targets = new address[](1);
        targets[0] = address(chainFeeSplitter);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(chainFeeSplitter.nudge.selector);

        string memory description = "nudge chain fee splitter";

        vm.prank(user);
        proposalId = veBTCEpochGovernor.propose(
            tokenId,
            targets,
            values,
            calldatas,
            description
        );
    }

    function executeChainFeeSplitterNudge() internal {
        address[] memory targets = new address[](1);
        targets[0] = address(chainFeeSplitter);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(chainFeeSplitter.nudge.selector);

        string memory description = "nudge chain fee splitter";

        veBTCEpochGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );
    }

    function executeSwap(
        address user,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        bool stable,
        address factory
    ) internal {
        uint256 initialUserTokenInBalance = IERC20(tokenIn).balanceOf(user);
        uint256 initialUserTokenOutBalance = IERC20(tokenOut).balanceOf(user);

        vm.startPrank(governance);
        TestERC20(tokenIn).mint(user, amountIn);
        vm.stopPrank();

        assertEq(IERC20(tokenIn).balanceOf(user), initialUserTokenInBalance + amountIn, "user should have the correct amount of tokenIn");
        
        IRouter.Route[] memory routes = new IRouter.Route[](1);
        routes[0] = IRouter.Route({
            from: tokenIn,
            to: tokenOut,
            stable: stable,
            factory: factory
        });

        vm.startPrank(user);
        IERC20(tokenIn).approve(address(router), amountIn);
        router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            routes,
            user,
            vm.getBlockTimestamp() + 1 hours
        );
        vm.stopPrank();

        assertEq(IERC20(tokenIn).balanceOf(user), initialUserTokenInBalance, "user should have spent the correct amount of tokenIn");
        assertGe(IERC20(tokenOut).balanceOf(user), initialUserTokenOutBalance + amountOutMin, "user should have received the correct amount of tokenOut");
    }

    function claimVeBTCVoterFees(address user, uint256 tokenId) internal {
        // Determine addresses of FeesVotingReward contract for each pool.
        address[] memory poolFees = new address[](3);
        poolFees[0] = veBTCVoter.gaugeToFees(veBTCVoter.gauges(pool_BTC_mUSD));
        poolFees[1] = veBTCVoter.gaugeToFees(veBTCVoter.gauges(pool_mUSD_LIMPETH));
        poolFees[2] = veBTCVoter.gaugeToFees(veBTCVoter.gauges(pool_mUSD_wtBTC));

        // Each pool has two tokens that can be claimed as fees.
        address[][] memory poolTokens = new address[][](3);
        // Tokens for the BTC_mUSD pool.
        poolTokens[0] = new address[](2);
        poolTokens[0][0] = address(BTC);
        poolTokens[0][1] = address(mUSD);
        // Tokens for the mUSD_LIMPETH pool.
        poolTokens[1] = new address[](2);
        poolTokens[1][0] = address(mUSD);
        poolTokens[1][1] = address(LIMPETH);
        // Tokens for the mUSD_wtBTC pool.
        poolTokens[2] = new address[](2);
        poolTokens[2][0] = address(mUSD);
        poolTokens[2][1] = address(wtBTC);

        // Claim fees for each user being a veBTC holder.
        vm.prank(user);
        veBTCVoter.claimFees(poolFees, poolTokens, tokenId);
    }

    function assertFeesVotingRewardBalance(address pool, address token, uint256 expectedClaimable) internal {
        address feesVotingReward = veBTCVoter.gaugeToFees(veBTCVoter.gauges(pool));
        assertEq(IERC20(token).balanceOf(feesVotingReward), expectedClaimable, "fees voting reward should have the correct amount of token");
    }

    function assertTokenBalanceChange(
        address user,
        address token,
        uint256 initialBalance,
        int256 expectedChange
    ) internal {
        assertEq(
            IERC20(token).balanceOf(user),
            uint256(int256(initialBalance) + expectedChange),
            "token balance did not change as expected"
        );
    }
}
