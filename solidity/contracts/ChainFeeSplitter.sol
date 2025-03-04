// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVoter} from "./interfaces/IVoter.sol";
import {IEpochGovernor} from "./interfaces/IEpochGovernor.sol";
import {Splitter} from "./Splitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IVoter} from "./interfaces/IVoter.sol";

/// @title ChainFeeSplitter
/// @notice A ChainFeeSplitter contract that changes the fee distribution between
///         veBTC holders and Stake Gauges based on the gauge needle position.
contract ChainFeeSplitter is Splitter {
    using SafeERC20 for IERC20;

    /// @notice Rewards distribution among stake gauges.
    IRewardsDistributor public immutable rewardsDistributor;

    /// @notice The address of the Voter contract.
    IVoter public immutable voter;

    constructor(
        address _voter, // the voting & distribution system
        address _ve, // the ve(3,3) system that will be locked into
        address _rewardsDistributor // rewards distributor
    ) Splitter(_ve) {
        /// The needle moves between 1 and 100. The default value is 33 to
        /// simulate ~1/3 of fees going to the veBTC holders and ~2/3 to the
        /// Stake Gauges.
        needle = 33;
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
        voter = IVoter(_voter);
        activePeriod = ((block.timestamp) / WEEK) * WEEK;
    }

    /// @notice Returns the address of the epoch governor.
    function epochGovernor() internal view override returns (address) {
        return voter.epochGovernor();
    }

    /// @notice Transfers amount to veBTC holders. Token is BTC.
    function transferFirstRecipient(uint256 amount) internal override {
        token.safeTransfer(address(rewardsDistributor), amount);
        // checkpoint token balance in rewards distributor
        rewardsDistributor.checkpointToken();
    }

    /// @notice Transfers amount to stake gauges. Token is BTC.
    function transferSecondRecipient(uint256 amount) internal override {
        token.safeApprove(address(voter), amount);
        voter.notifyRewardAmount(amount);
    }
}
