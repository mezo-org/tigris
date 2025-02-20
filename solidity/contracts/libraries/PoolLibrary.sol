// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library PoolLibrary {
    function f(uint256 x0, uint256 y) internal pure returns (uint256) {
        uint256 _a = (x0 * y) / 1e18;
        uint256 _b = ((x0 * x0) / 1e18 + (y * y) / 1e18);
        return (_a * _b) / 1e18;
    }

    function d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return (3 * x0 * ((y * y) / 1e18)) / 1e18 + ((((x0 * x0) / 1e18) * x0) / 1e18);
    }

    // only called in stable pools
    function get_y(
        uint256 x0,
        uint256 xy,
        uint256 y,
        uint256 decimals0,
        uint256 decimals1
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 k = f(x0, y);
            if (k < xy) {
                // there are two cases where dy == 0
                // case 1: The y is converged and we find the correct answer
                // case 2: _d(x0, y) is too large compare to (xy - k) and the rounding error
                //         screwed us.
                //         In this case, we need to increase y by 1
                uint256 dy = ((xy - k) * 1e18) / d(x0, y);
                if (dy == 0) {
                    if (k == xy) {
                        // We found the correct answer. Return y
                        return y;
                    }
                    if (stableK(x0, y + 1, decimals0, decimals1) > xy) {
                        // If _k(x0, y + 1) > xy, then we are close to the correct answer.
                        // There's no closer answer than y + 1
                        return y + 1;
                    }
                    dy = 1;
                }
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / d(x0, y);
                if (dy == 0) {
                    if (k == xy || f(x0, y - 1) < xy) {
                        // Likewise, if k == xy, we found the correct answer.
                        // If _f(x0, y - 1) < xy, then we are close to the correct answer.
                        // There's no closer answer than "y"
                        // It's worth mentioning that we need to find y where f(x0, y) >= xy
                        // As a result, we can't return y - 1 even it's closer to the correct answer
                        return y;
                    }
                    dy = 1;
                }
                y = y - dy;
            }
        }
        revert("!y");
    }

    function dispatchK(
        uint256 x,
        uint256 y,
        uint256 decimals0,
        uint256 decimals1,
        bool stable
    ) internal pure returns (uint256) {
        if (stable) {
            return stableK(x, y, decimals0, decimals1);
        } else {
            return volatileK(x, y);
        }
    }

    function stableK(
        uint256 x,
        uint256 y,
        uint256 decimals0,
        uint256 decimals1
    ) internal pure returns (uint256) {
        uint256 _x = (x * 1e18) / decimals0;
        uint256 _y = (y * 1e18) / decimals1;
        uint256 _a = (_x * _y) / 1e18;
        uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
        return (_a * _b) / 1e18; // x3y+y3x >= k
    }

    function volatileK(uint256 x, uint256 y) internal pure returns (uint256) {
        return x * y; // xy >= k
    }
}