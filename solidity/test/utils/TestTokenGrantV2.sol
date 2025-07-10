// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import {TokenGrant} from "contracts/grant/TokenGrant.sol";

contract TokenGrantV2 is TokenGrant {
    function version() public pure returns (uint256) {
        return 2;
    }
}
