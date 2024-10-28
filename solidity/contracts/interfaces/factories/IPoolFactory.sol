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

    function getPair(address tokenA, address tokenB, bool stable) external view returns (address);
    function voter() external returns (address);
    function isPaused() external returns (bool);
    function getFee(address pool, bool stable) external view returns (uint256);
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
    function getPool(address tokenA, address tokenB, bool stable) external view returns (address);
    function createPair(address tokenA, address tokenB, bool stable) external returns (address pool);
    function createPool(address tokenA, address tokenB, bool stable) external returns (address pool);
    function allPoolsLength() external view returns (uint256);
    function isPool(address pool) external view returns (bool);
    function isPair(address pool) external view returns (bool);
    function setVoter(address voter) external;
    function setFee(bool stable, uint256 fee) external;
    function setCustomFee(address pool, uint256 fee) external;
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
}
