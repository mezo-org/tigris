// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.24;

import {IRouter} from "./IRouter.sol";

interface ICompoundOptimizer {
    error NoRouteFound();

    function getOptimalTokenToMezoRoute(
        address token,
        uint256 amountIn
    ) external view returns (IRouter.Route[] memory);
}
