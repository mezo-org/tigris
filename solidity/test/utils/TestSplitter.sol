// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "contracts/Splitter.sol";

// TestSplitter contract inheriting from Splitter to test the functionality of
// the Splitter contract.
contract TestSplitter is Splitter {
    address public firstRecipient;
    address public secondRecipient;
    IEpochGovernor public mockEpochGovernor;

    constructor(address _ve) Splitter(_ve) {
        needle = 33;
    }

    function setMockEpochGovernor(address _mockEpochGovernor) public {
        mockEpochGovernor = IEpochGovernor(_mockEpochGovernor);
    }

    function setFirstRecipient(address _firstRecipient) public {
        firstRecipient = _firstRecipient;
    }

    function setSecondRecipient(address _secondRecipient) public {
        secondRecipient = _secondRecipient;
    }

    function transferFirstRecipient(uint256 amount) internal override {
        token.transfer(firstRecipient, amount);
    }

    function transferSecondRecipient(uint256 amount) internal override {
        token.transfer(secondRecipient, amount);
    }

    function epochGovernor() internal view override returns (address) {
        return address(mockEpochGovernor);
    }

    function setNeedle(uint256 _needle) public {
        needle = _needle;
    }
}
