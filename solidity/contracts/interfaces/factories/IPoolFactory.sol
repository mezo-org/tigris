// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.19;

interface IPoolFactory {
    function getPair(address token1, address token2, bool stable) external returns (address) {}
}
