// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IEpochGovernor} from "../../contracts/interfaces/IEpochGovernor.sol";

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