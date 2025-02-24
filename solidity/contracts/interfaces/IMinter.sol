// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMinter {
    error AlreadyNudged();
    error NotEpochGovernor();
    error TailEmissionsInactive();

    event Mint(
        address indexed _sender,
        uint256 _weekly,
        uint256 _circulating_supply,
        bool indexed _tail
    );
    event Nudge(uint256 indexed _period, uint256 _oldRate, uint256 _newRate);

    /// @notice Allows epoch governor to modify the tail emission rate by at most 1 basis point
    ///         per epoch to a maximum of 100 basis points or to a minimum of 1 basis point.
    ///         Note: the very first nudge proposal must take place the week prior
    ///         to the tail emission schedule starting.
    /// @dev Throws if not epoch governor.
    ///      Throws if not currently in tail emission schedule.
    ///      Throws if already nudged this epoch.
    ///      Throws if nudging above maximum rate.
    ///      Throws if nudging below minimum rate.
    ///      This contract is coupled to EpochGovernor as it requires three option simple majority voting.
    function nudge() external;

    /// @notice Processes emissions and rebases. Callable once per epoch (1 week).
    /// @return _period Start of current epoch.
    function updatePeriod() external returns (uint256 _period);
}
