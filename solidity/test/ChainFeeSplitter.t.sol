// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./BaseTest.sol";
import {IEpochGovernor} from "../contracts/interfaces/IEpochGovernor.sol";

contract ChainFeeSplitterTest is BaseTest {
    uint256 private constant MAXIMUM_GAUGE_SCALE = 100;
    IERC20 token;

    function _setUp() public override {
        token = chainFeeSplitter.token();
    }

    function testInitialSetup() public {
        assertEq(chainFeeSplitter.needle(), 33);
        assertEq(chainFeeSplitter.activePeriod(), ((block.timestamp) / WEEK) * WEEK);
        assertEq(address(chainFeeSplitter.token()), address(BTC));
    }

    function testUpdatePeriod() public {
        token.transfer(address(chainFeeSplitter), 10000);
        assertEq(token.balanceOf(address(chainFeeSplitter)), 10000);

        uint256 prevActivePeriod = chainFeeSplitter.activePeriod();

        skip(1 weeks);

        uint256 currentBalance = token.balanceOf(address(chainFeeSplitter));
        
        chainFeeSplitter.updatePeriod();

        uint256 newActivePeriod = chainFeeSplitter.activePeriod();
        assertGt(newActivePeriod, prevActivePeriod, "Period should be updated");

        uint256 expectedDistributorAmount = (currentBalance * chainFeeSplitter.needle()) / MAXIMUM_GAUGE_SCALE;
        uint256 expectedVoterAmount = currentBalance - expectedDistributorAmount;

        assertEq(token.balanceOf(address(distributor)), expectedDistributorAmount, "Incorrect distributor amount");
        assertEq(token.balanceOf(address(voter)), expectedVoterAmount, "Incorrect voter amount");
    }
}
