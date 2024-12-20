// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.24;

interface IAutoCompounderFactory {
    event SetRewardAmount(uint256 amount);
    event CreateAutoCompounder(
        address created,
        address admin,
        address autoCompounder
    );

    error TokenIdZero();
    error TokenIdNotApproved();
    error TokenIdNotManaged();
    error NotTeam();
    error AmountSame();
    error AmountOutOfAcceptableRange();

    function rewardAmount() external returns (uint256);
}
