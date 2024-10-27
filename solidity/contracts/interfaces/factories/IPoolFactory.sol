// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.24;

interface IPoolFactory {

    event PoolCreated(address token0, address token1, bool stable, address pool, uint256 numPools);
    event SetCustomFee(address pool, uint256 fee);
    event SetFeeManager(address feeManager);
    event SetPauseState(bool paused);
    event SetPauser(address pauser);
    event SetVoter(address voter);

    error PoolAlreadyExists();
    error ZeroAddress();
    error SameAddress();
    error FeeInvalid();
    error InvalidPool();
    error FeeTooHigh();
    error NotFeeManager();
    error ZeroFee();
    error NotPauser();
    error NotVoter();
    error NotSinkConverter();

    function getPair(address token1, address token2, bool stable) external returns (address);
    function voter() external returns (address);
    function isPaused() external returns (bool);
    function getFee(address pool, bool stable) external returns (uint256);
}
