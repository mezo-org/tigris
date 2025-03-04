// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./BaseTest.sol";
import {ISplitter} from "../contracts/interfaces/ISplitter.sol";
import {MockEpochGovernor} from "./utils/MockEpochGovernor.sol";

contract SplitterTest is BaseTest {

    uint256 private constant TICK = 1;
    uint256 private constant MAXIMUM_GAUGE_SCALE = 100;
    uint256 private constant MINIMUM_GAUGE_SCALE = 1;
    MockEpochGovernor mockEpochGovernor;
    address firstRecipient;
    address secondRecipient;

    IERC20 token;

    event PeriodUpdated(
        uint256 oldPeriod,
        uint256 newPeriod,
        uint256 firstRecipientAmount,
        uint256 secondRecipientAmount
    );

    function _setUp() public override {
        mockEpochGovernor = new MockEpochGovernor();
        splitter.setMockEpochGovernor(address(mockEpochGovernor));
        token = splitter.token();
        firstRecipient = address(0x1);
        secondRecipient = address(0x2);
        splitter.setFirstRecipient(firstRecipient);
        splitter.setSecondRecipient(secondRecipient);
    }

    function testInitialSetup() public {
        assertEq(splitter.needle(), 33);
        assertEq(splitter.activePeriod(), 0);
        assertEq(address(splitter.token()), address(BTC));
    }

    function testNudgeSuccessfulProposal() public {
        // Simulate a successful proposal in the mocked Governor
        mockEpochGovernor.simulateSuccessfulProposal();
        
        uint256 previousNeedle = splitter.needle();
        vm.prank(address(mockEpochGovernor));
        splitter.nudge();
        assertEq(splitter.needle(), previousNeedle + TICK, "Needle should increase by 1 if proposal succeeds");
    }

    function testNudgeMaxNeedle() public {
        // Simulate a successful proposal in the mocked Governor
        mockEpochGovernor.simulateSuccessfulProposal();
        splitter.setNeedle(MAXIMUM_GAUGE_SCALE);
        
        uint256 previousNeedle = splitter.needle();
        vm.prank(address(mockEpochGovernor));
        splitter.nudge();
        assertEq(splitter.needle(), MAXIMUM_GAUGE_SCALE, "Needle should stay at MAXIMUM_GAUGE_SCALE if it is already at max");
    }

    function testNudgeDefeatedProposal() public {
        // Simulate a defeated proposal in the mocked Governor
        mockEpochGovernor.simulateDefeatedProposal();
        
        uint256 previousNeedle = splitter.needle();
        vm.prank(address(mockEpochGovernor));
        splitter.nudge();
        assertEq(splitter.needle(), previousNeedle - TICK, "Needle should decrease by 1 if proposal fails");
    }

    function testNudgeMinNeedle() public {
        // Simulate a defeated proposal in the mocked Governor
        mockEpochGovernor.simulateDefeatedProposal();
        splitter.setNeedle(MINIMUM_GAUGE_SCALE);
        
        uint256 previousNeedle = splitter.needle();
        vm.prank(address(mockEpochGovernor));
        splitter.nudge();
        assertEq(splitter.needle(), MINIMUM_GAUGE_SCALE, "Needle should stay at MINIMUM_GAUGE_SCALE if it is already at min");
    }

    function testNudgeRevertsIfNotEpochGovernor() public {
        vm.expectRevert(ISplitter.NotEpochGovernor.selector);
        splitter.nudge();
    }

    function testNudgeAlreadyNudgedRevert() public {
        mockEpochGovernor.simulateDefeatedProposal();

        vm.prank(address(mockEpochGovernor));
        splitter.nudge();

        vm.expectRevert(ISplitter.AlreadyNudged.selector);
        vm.prank(address(mockEpochGovernor));
        splitter.nudge();
    }

    function testNudgeDoesNothingIfExpired() public {
        mockEpochGovernor.simulateExpiredProposal();

        uint256 initialNeedle = splitter.needle();
        vm.prank(address(mockEpochGovernor));
        splitter.nudge();

        assertEq(splitter.needle(), initialNeedle);
    }

    function testUpdatePeriod() public {
        token.transfer(address(splitter), 1000);
        assertEq(token.balanceOf(address(splitter)), 1000);

        uint256 prevActivePeriod = splitter.activePeriod();

        // Fast forward time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        uint256 currentBalance = token.balanceOf(address(splitter));
        splitter.updatePeriod();

        uint256 newActivePeriod = splitter.activePeriod();
        assertGt(newActivePeriod, prevActivePeriod, "Period should be updated");

        uint256 expectedFirstRecipientAmount = (currentBalance * splitter.needle()) / MAXIMUM_GAUGE_SCALE;
        uint256 expectedSecondRecipientAmount = currentBalance - expectedFirstRecipientAmount;

        assertEq(token.balanceOf(firstRecipient), expectedFirstRecipientAmount, "Incorrect first recipient amount");
        assertEq(token.balanceOf(secondRecipient), expectedSecondRecipientAmount, "Incorrect second recipient amount");
    }

    function testNoDistributionIfNoBalance() public {
        assertEq(token.balanceOf(address(splitter)), 0);

        // Fast forward time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        uint256 prevFirstRecipientBalance = token.balanceOf(firstRecipient);
        uint256 prevSecondRecipientBalance = token.balanceOf(secondRecipient);

        splitter.updatePeriod();

        assertEq(token.balanceOf(firstRecipient), prevFirstRecipientBalance, "First recipient balance should not change");
        assertEq(token.balanceOf(secondRecipient), prevSecondRecipientBalance, "Second recipient balance should not change");
    }

    function testPeriodUpdatedEventEmitted() public {
        // Fast forward time by 1 week
        vm.warp(block.timestamp + 1 weeks);

        uint256 currentBalance = token.balanceOf(address(splitter));
        uint256 expectedFirstRecipientAmount = (currentBalance * splitter.needle()) / splitter.MAXIMUM_GAUGE_SCALE();
        uint256 expectedSecondRecipientAmount = currentBalance - expectedFirstRecipientAmount;

        vm.expectEmit(true, true, true, true);
        emit PeriodUpdated(
            splitter.activePeriod(),
            (block.timestamp / 1 weeks) * 1 weeks,
            expectedFirstRecipientAmount,
            expectedSecondRecipientAmount
        );

        splitter.updatePeriod();
    }

    function testNoDistributionIfOldPeriodActive() public {
        splitter.updatePeriod();

        token.transfer(address(splitter), 1000);
        assertEq(token.balanceOf(address(splitter)), 1000);

        uint256 prevFirstRecipientBalance = token.balanceOf(firstRecipient);
        uint256 prevSecondRecipientBalance = token.balanceOf(secondRecipient);

        splitter.updatePeriod();

        assertEq(token.balanceOf(firstRecipient), prevFirstRecipientBalance, "First recipient balance should not change");
        assertEq(token.balanceOf(secondRecipient), prevSecondRecipientBalance, "Second recipient balance should not change");
    }
}