// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.24;

import {VotingEscrow} from "./VotingEscrow.sol";

contract VeMEZO is VotingEscrow {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _forwarder,
        address _mezo,
        address _factoryRegistry
    ) external initializer {
        __VotingEscrow_initialize(_forwarder, _mezo, _factoryRegistry);
    }

    function name() external pure returns (string memory) {
        return "veMEZO";
    }

    function symbol() external pure returns (string memory) {
        return "veMEZO";
    }

    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}
