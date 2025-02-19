// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.24;

import {VotingEscrow} from "./VotingEscrow.sol";

contract VeBTC is VotingEscrow {
    // Notice that the same forwarder address must be used in the constructor and
    // in the `initialize` function.
    constructor(address _forwarder) VotingEscrow(_forwarder) {
        _disableInitializers();
    }

    function initialize(
        address _forwarder,
        address _btc,
        address _factoryRegistry
    ) external initializer {
        __initializeVotingEscrow(_forwarder, _btc, _factoryRegistry);
    }

    function name() external pure returns (string memory) {
        return "veBTC";
    }

    function symbol() external pure returns (string memory) {
        return "veBTC";
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}
