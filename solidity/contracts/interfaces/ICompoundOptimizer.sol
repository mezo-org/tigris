pragma ^0.8.4;

import { IRouter } from "./IRouter.sol";

interface ICompoundOptimizer {
    error NoRouteFound();

    function getOptimalTOkenToMezoRoute(address token, uint256 amountIn) external view returns (IRouter.Route[] memory);
}
