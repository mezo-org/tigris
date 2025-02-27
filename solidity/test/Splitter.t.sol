// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./BaseTest.sol";
import {IEpochGovernor} from "../contracts/interfaces/IEpochGovernor.sol";
contract SplitterTest is BaseTest {

    uint256 private constant TICK = 1;
    uint256 private constant MAXIMUM_GAUGE_SCALE = 100;
    uint256 private constant MINIMUM_GAUGE_SCALE = 1;
    MockEpochGovernor mockEpochGovernor;

    error AlreadyNudged();
    error NotEpochGovernor();

    function _setUp() public override {
         mockEpochGovernor = new MockEpochGovernor();
         splitter.setMockEpochGovernor(address(mockEpochGovernor));
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
        vm.expectRevert(NotEpochGovernor.selector);
        splitter.nudge();
    }

    function testNudgeAlreadyNudgedRevert() public {
        mockEpochGovernor.simulateDefeatedProposal();

        vm.prank(address(mockEpochGovernor));
        splitter.nudge();

        vm.expectRevert(AlreadyNudged.selector);
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
}

// TODO: test updatePeriod()

contract MockEpochGovernor is IEpochGovernor {
    ProposalState public lastResult;

    function simulateSuccessfulProposal() external {
        lastResult = ProposalState.Succeeded;
    }

    function simulateDefeatedProposal() external {
        lastResult = ProposalState.Defeated;
    }

    function simulateExpiredProposal() external {
        lastResult = ProposalState.Expired;
    }

    function result() external view override returns (ProposalState) {
        return lastResult;
    }
}