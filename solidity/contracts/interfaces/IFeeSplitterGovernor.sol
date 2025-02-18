// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IFeeSplitterGovernor {
    // TODO: Figure out what are the possible states of a proposal.
    //       This will drive logic flow in the FeeSplitter contract's nudge function.
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        MovedUp,
        MovedDown,
        Expired,
        Executed
    }

    function result() external returns (ProposalState);
}
