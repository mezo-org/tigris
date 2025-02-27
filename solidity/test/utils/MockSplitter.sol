// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "contracts/Splitter.sol";

// MockSplitter contract inheriting from Splitter to test the functionality of
// the Splitter contract.
contract MockSplitter is Splitter {
    address public firstRecipient;
    address public secondRecipient;
    IEpochGovernor public mockEpochGovernor;

    constructor(address _ve, address _firstRecipient, address _secondRecipient) Splitter(_ve) {
        firstRecipient = _firstRecipient;
        secondRecipient = _secondRecipient;
        needle = 33;
    }

    function setMockEpochGovernor(address _mockEpochGovernor) public {
        mockEpochGovernor = IEpochGovernor(_mockEpochGovernor);
    }

    function epochGovernor() internal override view returns (address) {
        return address(mockEpochGovernor);
    }

    function transferFirstRecipient(uint256 amount) internal override {
        token.transfer(firstRecipient, amount);
    }

    function transferSecondRecipient(uint256 amount) internal override{
        token.transfer(secondRecipient, amount);
    }

    function setNeedle(uint256 _needle) public {
        needle = _needle;
    }
}
