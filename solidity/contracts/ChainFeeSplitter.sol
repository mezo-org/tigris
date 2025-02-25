// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVoter} from "./interfaces/IVoter.sol";
import {IEpochGovernor} from "./interfaces/IEpochGovernor.sol";
import {Splitter} from "./Splitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";

/// @title ChainFeeSplitter
/// @notice A ChainFeeSplitter contract that changes the fee distribution between
///         veBTC holders and Stake Gauges based on the gauge needle position.
contract ChainFeeSplitter is Splitter {
    using SafeERC20 for IERC20;

    /// @notice Rewards distribution among stake gauges.
    IRewardsDistributor public immutable rewardsDistributor;

    /// @dev Emitted when the epoch period is updated.
    event PeriodUpdated(
        uint256 oldPeriod,
        uint256 newPeriod,
        uint256 veBTCHoldersFee,
        uint256 stakeGuagesFee
    );

    constructor(
        address _voter, // the voting & distribution system
        address _ve, // the ve(3,3) system that will be locked into
        address _rewardsDistributor // the distribution system that ensures users aren't diluted
    ) Splitter(_voter, _ve) {
        /// The needle moves between 1 and 100. The default value is 33 to
        /// simulate ~1/3 of fees going to the veBTC holders and ~2/3 to the
        /// Stake Gauges.
        needle = 33;
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
    }

    /// @notice Updates the period of the current epoch. This function can be called
    ///         by anyone. Chain fees accumulate in this contract continuously and
    ///         are distributed to veBTC holders and stake gauges over a specified
    ///         period. In other words, the release of accumulated fees must wait
    ///         until the end of the period.
    function updatePeriod() external override returns (uint256 period) {
        period = activePeriod;
        if (block.timestamp >= period + WEEK) {
            uint256 oldPeriod = period;
            period = (block.timestamp / WEEK) * WEEK;
            activePeriod = period;

            uint256 stakeGuagesFee;
            uint256 veBTCHoldersFee;

            uint256 currentBalance = token.balanceOf(address(this));
            if (currentBalance > 0) {
                veBTCHoldersFee =
                    (currentBalance * needle) /
                    MAXIMUM_GAUGE_SCALE;
                stakeGuagesFee = currentBalance - veBTCHoldersFee;

                // For veBTC holders. Token is BTC.
                token.safeTransfer(
                    address(rewardsDistributor),
                    veBTCHoldersFee
                );
                rewardsDistributor.checkpointToken(); // checkpoint token balance in rewards distributor

                // For stake guages. Token is BTC.
                token.safeApprove(address(voter), stakeGuagesFee);
                voter.notifyRewardAmount(stakeGuagesFee);
            }

            emit PeriodUpdated(
                oldPeriod,
                period,
                veBTCHoldersFee,
                stakeGuagesFee
            );
        }
    }

    /// @notice Moves the needle up by 1 tick.
    /// @dev The needle can be moved up to the maximum gauge scale.
    function moveNeedleUp() internal override returns (uint256) {
        uint256 oldNeedle = needle;
        if (oldNeedle < MAXIMUM_GAUGE_SCALE) {
            needle = oldNeedle + TICK;
        }
        return needle;
    }

    /// @notice Moves the needle down by 1 tick.
    /// @dev The needle can be moved down to the minimum gauge scale.
    function moveNeedleDown() internal override returns (uint256) {
        uint256 oldNeedle = needle;
        if (oldNeedle > MINIMUM_GAUGE_SCALE) {
            needle = oldNeedle - TICK;
        }
        return needle;
    }
}
