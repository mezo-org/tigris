// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IVoter} from "./interfaces/IVoter.sol";
import {IEpochGovernor} from "./interfaces/IEpochGovernor.sol";
import {ISplitter} from "./interfaces/ISplitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";

/// @title Splitter
/// @notice An abstract contract for fee splitting between token holders and Stake Gauges.
abstract contract Splitter is ISplitter {
    using SafeERC20 for IERC20;

    /// @notice The address of the Voter contract.
    IVoter public immutable voter;

    /// @notice Token for fee distribution.
    IERC20 public immutable token;

    /// @notice The maximum value of the gauge needle.
    uint256 public constant MAXIMUM_GAUGE_SCALE = 100;

    /// @notice The minimum value of the gauge needle.
    uint256 public constant MINIMUM_GAUGE_SCALE = 1;

    /// @notice Duration of epoch.
    uint256 public constant WEEK = 1 weeks;

    /// @notice Needle tick change per proposal.
    uint256 public constant TICK = 1;

    /// @notice Start time of currently active epoch.
    uint256 public activePeriod;

    /// @notice The current position of the gauge needle.
    uint256 public needle;

    /// @dev activePeriod => proposal existing, used to enforce one proposal per epoch.
    mapping(uint256 => bool) public proposals;

    /// @notice Constructor to set up the fee splitter.
    constructor(address _voter, address _ve) {
        voter = IVoter(_voter);
        token = IERC20(IVotingEscrow(_ve).token());
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
            if (state == IEpochGovernor.ProposalState.Succeeded) {
                needle = moveNeedleUp();
            } else {
                needle = moveNeedleDown();
            }
        }

        proposals[period] = true;
        // Might happen that needle did not move due to abstained or expired proposal.
        emit Nudge(period, oldNeedle, needle);
    }

    /// @notice Updates the period of the current epoch.
    function updatePeriod() external virtual returns (uint256 period);

    /// @notice Moves the gauge needle to the right.
    function moveNeedleUp() internal virtual returns (uint256 needle);

    /// @notice Moves the gauge needle to the left.
    function moveNeedleDown() internal virtual returns (uint256 needle);
}
