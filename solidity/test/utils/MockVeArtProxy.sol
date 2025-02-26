// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/Strings.sol";

contract MockVeArtProxy {
    address public ve;

    constructor(address _ve){
        ve = _ve;
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        return Strings.toHexString(uint160(ve), 20);
    }
}
