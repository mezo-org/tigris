pragma solidity 0.8.24;

import {BaseSystemTest} from "./BaseSystemTest.sol";
import {IGovernor} from "contracts/governance/IGovernor.sol";
import {GovernorCountingMajority} from "contracts/governance/GovernorCountingMajority.sol";

contract FullEpoch is BaseSystemTest {
    function testFullEpoch() public {
        // Start Epoch 1 and move to it's first second.
        // Assume this is timestamp T.
        skipToNextEpoch(1);

        // Define actors.
        address user1 = accounts[1];
        address user2 = accounts[2];
        address user3 = accounts[3];

        // Mint BTC to the users.
        vm.startPrank(governance);
        BTC.mint(user1, withTokenPrecision(10));
        BTC.mint(user2, withTokenPrecision(10));
        BTC.mint(user3, withTokenPrecision(10));
        vm.stopPrank();

        // Mint veBTC to the users.
        uint256 user1TokenId = mintVeBTC(user1, withTokenPrecision(10), YEAR);
        uint256 user2TokenId = mintVeBTC(user2, withTokenPrecision(10), 2 * YEAR);
        uint256 user3TokenId = mintVeBTC(user3, withTokenPrecision(10), 4 * YEAR); // max lock duration

        // Check veBTC balances and total supply.
        // Balance of NFT is a function defined as:
        // - balance(t) = bias - slope * (t - last_checkpoint).
        //
        // Upon lock creation, function parameters are set as follows:
        // - slope = locked_amount / max_lock_duration
        // - bias = slope * (lock_end - lock_start) = slope * lock_duration
        // - last_checkpoint = lock_start
        //
        // Notes:
        // - The slope and bias parameters are modified upon each checkpoint.
        // - The lock_duration must be rounded down to weeks using integer arithmetic
        //   (i.e. (lock_duration / 604800) * 604800) and offset by the
        //   difference between lock_start and epoch start.

        // User1 balance calculation, at timestamp T:
        // - lock_duration = (((365 * 86400) / 604800) * 604800) - 1 = 52 (rounded) * 604800 - 1 (offset) = 31449599
        // - slope = (10 * 1e18) / (4 * 365 * 86400) = 79274479959
        // - bias = 79274479959 * 31449599 = 2493150605644086441
        // - balance = 2493150605644086441 - 79274479959 * (T - T) = 2493150605644086441
        assertEq(veBTC.balanceOfNFT(user1TokenId), 2493150605644086441, "unexpected user1 token veBTC balance");

        // User2 balance calculation, at timestamp T:
        // - lock_duration = (((2 * 365 * 86400) / 604800) * 604800) - 1 = 104 (rounded) * 604800 - 1 (offset) = 62899199
        // - slope = (10 * 1e18) / (4 * 365 * 86400) = 79274479959
        // - bias = 79274479959 * 62899199 = 4986301290562652841
        // - balance = 4986301290562652841 - 79274479959 * (T - T) = 4986301290562652841
        assertEq(veBTC.balanceOfNFT(user2TokenId), 4986301290562652841, "unexpected user2 token veBTC balance");

        // User3 balance calculation, at timestamp T:
        // - lock_duration = (((4 * 365 * 86400) / 604800) * 604800) - 1 = 208 (rounded) * 604800 - 1 (offset) = 125798399
        // - slope = (10 * 1e18) / (4 * 365 * 86400) = 79274479959
        // - bias = 79274479959 * 125798399 = 9972602660399785641
        // - balance = 9972602660399785641 - 79274479959 * (T - T) = 9972602660399785641
        assertEq(veBTC.balanceOfNFT(user3TokenId), 9972602660399785641, "unexpected user3 token veBTC balance");

        // Sum of all veBTC balances.
        assertEq(veBTC.totalSupply(), 17452054556606524923, "unexpected veBTC total supply");

        // Make sure BTC was transferred to the veBTC contract as expected.
        assertEq(BTC.balanceOf(user1), 0, "unexpected user1 BTC balance");
        assertEq(BTC.balanceOf(user2), 0, "unexpected user2 BTC balance");
        assertEq(BTC.balanceOf(user3), 0, "unexpected user3 BTC balance");
        assertEq(BTC.balanceOf(address(veBTC)), withTokenPrecision(30), "unexpected veBTC contract BTC balance");

        // Load the chain fee splitter with BTC.
        vm.prank(governance);
        BTC.mint(address(chainFeeSplitter), withTokenPrecision(100));

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

        // We must move the time forward past the voting delay to allow voting.
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
        // decayed a bit since locks creation since we moved 15m (900s) ahead.
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
    }

    function mintVeBTC(address user, uint256 amount, uint256 lockDuration) internal returns (uint256 tokenId) {
        vm.startPrank(user);
        BTC.approve(address(veBTC), amount);
        tokenId = veBTC.createLock(amount, lockDuration);
        vm.stopPrank();
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
}
