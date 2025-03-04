// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.24;

import {VotingEscrow} from "./VotingEscrow.sol";

contract VeBTC is VotingEscrow {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
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
