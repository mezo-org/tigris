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

    /// @notice Constructor to set up the chain fee splitter.
    /// @param _voter The address of the Voter contract.
    /// @param _ve The address of the VotingEscrow contract (i.e. the veNFT token contract).
    /// @param _rewardsDistributor The address of the rewards distributor.
    /// @param _needle The initial needle position. This is a percentage value directly
    ///                determining the portion of chain fees that goes to the veBTC holders.
    ///                The other portion of fees (100% - _needle) goes to the stake gauges.
    constructor(
        address _voter,
        address _ve,
        address _rewardsDistributor,
        uint256 _needle
    ) Splitter(_ve) {
        needle = _needle;
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
