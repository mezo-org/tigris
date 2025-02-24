// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISplitter} from "./interfaces/ISplitter.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {IMezo} from "./interfaces/IMezo.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IEpochGovernor} from "./interfaces/IEpochGovernor.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Minter
/// @notice Controls minting of emissions and rebases for Mezodrome
contract Minter is ISplitter {
    using SafeERC20 for IMezo;
    IMezo public immutable mezo;
    IVoter public immutable voter;
    IVotingEscrow public immutable ve;
    IRewardsDistributor public immutable rewardsDistributor;

    /// @notice Duration of epoch in seconds
    // uint256 public constant WEEK = 1 weeks;
    /// @notice Decay rate of emissions as percentage of `MAX_BPS`
    uint256 public constant WEEKLY_DECAY = 9_900;
    /// @notice Maximum tail emission rate in basis points.
    uint256 public constant MAXIMUM_TAIL_RATE = 100;
    /// @notice Minimum tail emission rate in basis points.
    uint256 public constant MINIMUM_TAIL_RATE = 1;
    /// @notice Denominator for emissions calculations (as basis points)
    uint256 public constant MAX_BPS = 10_000;
    /// @notice Rate change per proposal
    uint256 public constant NUDGE = 1;
    /// @notice When emissions fall below this amount, begin tail emissions
    uint256 public constant TAIL_START = 6_000_000 * 1e18;
    /// @notice Tail emissions rate in basis points
    uint256 public tailEmissionRate = 30;
    /// @notice Starting weekly emission of 15M MEZO (MEZO has 18 decimals)
    uint256 public weekly = 15_000_000 * 1e18;
    /// @notice Start time of currently active epoch
    uint256 public activePeriod;
    /// @dev activePeriod => proposal existing, used to enforce one proposal per epoch
    mapping(uint256 => bool) public proposals;

    constructor(
        address _voter, // the voting & distribution system
        address _ve, // the ve(3,3) system that will be locked into
        address _rewardsDistributor // the distribution system that ensures users aren't diluted
    ) {
        mezo = IMezo(IVotingEscrow(_ve).token());
        voter = IVoter(_voter);
        ve = IVotingEscrow(_ve);
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
        activePeriod = ((block.timestamp) / WEEK) * WEEK; // allow emissions this coming epoch
    }

    /// @notice Calculates rebases according to the formula
    ///         weekly * (ve.totalSupply / mezo.totalSupply) ^ 3 / 2
    ///         Note that ve.totalSupply is the locked ve supply
    ///         mezo.totalSupply is the total ve supply minted
    /// @param _minted Amount of MEZO minted this epoch
    /// @return _growth Rebases
    function calculateGrowth(
        uint256 _minted
    ) public view returns (uint256 _growth) {
        uint256 _veTotal = ve.totalSupplyAt(activePeriod - 1);
        uint256 _mezoTotal = mezo.totalSupply();
        return
            (((((_minted * _veTotal) / _mezoTotal) * _veTotal) / _mezoTotal) *
                _veTotal) /
            _mezoTotal /
            2;
    }

    /// @inheritdoc ISplitter
    function nudge() external {
        address _epochGovernor = voter.epochGovernor();
        if (msg.sender != _epochGovernor) revert NotEpochGovernor();
        IEpochGovernor.ProposalState _state = IEpochGovernor(_epochGovernor)
            .result();
        if (weekly >= TAIL_START) revert TailEmissionsInactive();
        uint256 _period = activePeriod;
        if (proposals[_period]) revert AlreadyNudged();
        uint256 _newRate = tailEmissionRate;
        uint256 _oldRate = _newRate;

        if (_state != IEpochGovernor.ProposalState.Expired) {
            if (_state == IEpochGovernor.ProposalState.Succeeded) {
                _newRate = _oldRate + NUDGE > MAXIMUM_TAIL_RATE
                    ? MAXIMUM_TAIL_RATE
                    : _oldRate + NUDGE;
            } else {
                _newRate = _oldRate - NUDGE < MINIMUM_TAIL_RATE
                    ? MINIMUM_TAIL_RATE
                    : _oldRate - NUDGE;
            }
            tailEmissionRate = _newRate;
        }
        proposals[_period] = true;
        emit Nudge(_period, _oldRate, _newRate);
    }

    /// @inheritdoc ISplitter
    function updatePeriod() external returns (uint256 _period) {
        _period = activePeriod;
        if (block.timestamp >= _period + WEEK) {
            _period = (block.timestamp / WEEK) * WEEK;
            activePeriod = _period;
            uint256 _weekly = weekly;
            uint256 _emission;
            uint256 _totalSupply = mezo.totalSupply();
            bool _tail = _weekly < TAIL_START;

            if (_tail) {
                _emission = (_totalSupply * tailEmissionRate) / MAX_BPS;
            } else {
                _emission = _weekly;
                _weekly = (_weekly * WEEKLY_DECAY) / MAX_BPS;
                weekly = _weekly;
            }

            uint256 _growth = calculateGrowth(_emission);
            uint256 _required = _growth + _emission;
            uint256 _balanceOf = mezo.balanceOf(address(this));
            if (_balanceOf < _required) {
                mezo.mint(address(this), _required - _balanceOf);
            }

            mezo.safeTransfer(address(rewardsDistributor), _growth);
            rewardsDistributor.checkpointToken(); // checkpoint token balance that was just minted in rewards distributor

            mezo.safeApprove(address(voter), _emission);
            voter.notifyRewardAmount(_emission);

            emit Mint(msg.sender, _emission, mezo.totalSupply(), _tail);
        }
    }
}
