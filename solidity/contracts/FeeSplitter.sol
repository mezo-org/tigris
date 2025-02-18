// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVoter} from "./interfaces/IVoter.sol";
import {IFeeSplitterGovernor} from "./interfaces/IFeeSplitterGovernor.sol";

/// @title FeeSplitter
/// @notice A FeeSplitter contract that changes the fee distribution between veBTC
///         holders and Stake Gauges based on the gauge needle position.
contract FeeSplitter {
    /// @notice The address of the Voter contract.
    IVoter public immutable voter;

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
    uint256 public needle = 37;

    /// @notice Start time of currently active epoch.
    uint256 public activePeriod;

    /// @dev activePeriod => proposal existing, used to enforce one proposal per epoch.
    mapping(uint256 => bool) public proposals;

    /// @dev Emitted when the caller is not the epoch governor.
    error NotEpochGovernor();

    /// @dev Emitted when the gauge needle was already moved in the current epoch.
    error AlreadyNudged();

    /// @dev Emitted when the gauge needle is moved.
    event NeedleMoved(uint256 oldNeedle, uint256 newNeedle);

    /// @dev Emitted when the gauge needle is nudged.
    event Nudge(uint256 indexed period, uint256 oldNeedle, uint256 newNeedle);

    /// @dev Emitted when the epoch period is updated.
    event PeriodUpdated(uint256 oldPeriod, uint256 newPeriod);

    constructor(address _voter) {
        voter = IVoter(_voter);
    }

    /// @notice Moves the gauge needle by 1 tick per epoch.
    function nudge() external {
        address epochGovernor = voter.epochGovernor();
        if (msg.sender != epochGovernor) revert NotEpochGovernor();

        uint256 period = activePeriod;
        if (proposals[period]) revert AlreadyNudged();

        IFeeSplitterGovernor.ProposalState state = IFeeSplitterGovernor(
            epochGovernor
        ).result();

        uint256 oldNeedle = needle;
        if (state != IFeeSplitterGovernor.ProposalState.Expired) {
            if (state == IFeeSplitterGovernor.ProposalState.MovedUp) {
                needle = needle + TICK > MAXIMUM_GAUGE_SCALE
                    ? MAXIMUM_GAUGE_SCALE
                    : needle + TICK;
            }
            if (state == IFeeSplitterGovernor.ProposalState.MovedDown) {
                needle = needle - TICK < MINIMUM_GAUGE_SCALE
                    ? MINIMUM_GAUGE_SCALE
                    : needle - TICK;
            }
            proposals[period] = true;
        }

        proposals[period] = true;
        // Might happen that the needle didn't change.
        emit Nudge(period, oldNeedle, needle);
    }

    /// @notice Updates the period of the current epoch.
    function updatePeriod() external {
        uint256 oldPeriod = activePeriod;
        if (block.timestamp >= activePeriod + WEEK) {
            activePeriod = (block.timestamp / WEEK) * WEEK;
        }
        emit PeriodUpdated(oldPeriod, activePeriod);
    }
}
