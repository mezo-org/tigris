// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVoter} from "./interfaces/IVoter.sol";
import {IEpochGovernor} from "./interfaces/IEpochGovernor.sol";
import {IMinter} from "./interfaces/IMinter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";

/// @title FeeSplitter
/// @notice A FeeSplitter contract that changes the fee distribution between veBTC
///         holders and Stake Gauges based on the gauge needle position.
contract FeeSplitter is IMinter {
    using SafeERC20 for IERC20;
    /// @notice The address of the Voter contract.
    IVoter public immutable voter;
    /// @notice Fee token.
    IERC20 public immutable btc;
    /// @notice Rewards distribution among stake gauges.
    IRewardsDistributor public immutable rewardsDistributor;

    /// @notice The maximum value of the gauge needle.
    uint256 public constant MAXIMUM_GAUGE_SCALE = 100;

    /// @notice The minimum value of the gauge needle.
    uint256 public constant MINIMUM_GAUGE_SCALE = 1;

    /// @notice Duration of epoch.
    /// TODO: Decide if we want to make this interval flexible and updatable by e.g. governor.
    uint256 public constant WEEK = 1 weeks;

    /// @notice Needle tick change per proposal.
    uint256 public constant TICK = 1;

    /// @notice The current position of the gauge needle.
    /// @dev The needle moves between 1 and 100. The default value is 33 to
    ///      simulate ~1/3 of fees going to the veBTC holders and ~2/3 to the
    ///      Stake Gauges.
    uint256 public needle = 33;

    /// @notice Start time of currently active epoch.
    uint256 public activePeriod;

    /// @dev activePeriod => proposal existing, used to enforce one proposal per epoch.
    mapping(uint256 => bool) public proposals;

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
    ) {
        voter = IVoter(_voter);
        btc = IERC20(IVotingEscrow(_ve).token());
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
    }

    /// @notice Moves the gauge needle by 1 tick per epoch.
    function nudge() external {
        address epochGovernor = voter.epochGovernor();
        if (msg.sender != epochGovernor) revert NotEpochGovernor();

        uint256 period = activePeriod;
        if (proposals[period]) revert AlreadyNudged();

        IEpochGovernor.ProposalState state = IEpochGovernor(epochGovernor)
            .result();

        uint256 oldNeedle = needle;
        if (state != IEpochGovernor.ProposalState.Expired) {
            // move the needle up by 1 tick
            if (state == IEpochGovernor.ProposalState.Succeeded) {
                needle = needle + TICK > MAXIMUM_GAUGE_SCALE
                    ? MAXIMUM_GAUGE_SCALE
                    : needle + TICK;
            } else {
                // move the needle down by 1 tick
                needle = needle - TICK < MINIMUM_GAUGE_SCALE
                    ? MINIMUM_GAUGE_SCALE
                    : needle - TICK;
            }
        }

        proposals[period] = true;
        // Might happen that needle did not move due to abstained or expired proposal.
        emit Nudge(period, oldNeedle, needle);
    }

    /// @notice Updates the period of the current epoch.
    function updatePeriod() external returns (uint256) {
        uint256 oldPeriod = activePeriod;
        if (block.timestamp >= activePeriod + WEEK) {
            activePeriod = (block.timestamp / WEEK) * WEEK;
        }

        uint256 stakeGuagesFee;
        uint256 veBTCHoldersFee;

        uint256 currentBalance = btc.balanceOf(address(this));
        if (currentBalance > 0) {
            veBTCHoldersFee = (currentBalance * needle) / MAXIMUM_GAUGE_SCALE;
            stakeGuagesFee = currentBalance - veBTCHoldersFee;
        }

        // For veBTC holders.
        btc.safeTransfer(address(rewardsDistributor), veBTCHoldersFee);
        rewardsDistributor.checkpointToken(); // checkpoint token balance in rewards distributor

        // For stake guages.
        btc.safeApprove(address(voter), stakeGuagesFee);
        voter.notifyRewardAmount(stakeGuagesFee);

        emit PeriodUpdated(
            oldPeriod,
            activePeriod,
            veBTCHoldersFee,
            stakeGuagesFee
        );

        return activePeriod;
    }

    /// TODO: consider removing this function from IMinter.
    function calculateGrowth(uint256 amount) external pure returns (uint256) {
        // noop
        return amount;
    }
}
