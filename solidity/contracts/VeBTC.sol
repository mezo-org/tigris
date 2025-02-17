// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.24;

import {VotingEscrow} from "./VotingEscrow.sol";

contract VeBTC is VotingEscrow {
    address public btc;

    constructor(
        address trustedForwarder,
        address _btc
    ) VotingEscrow(trustedForwarder) {
        btc = _btc;
    }
}
