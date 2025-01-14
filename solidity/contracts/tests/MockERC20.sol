pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockERC20 is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) ERC20(name, symbol) Ownable() {
        _mint(msg.sender, supply);
    }

    function mint(address account, uint256 value) external onlyOwner {
        _mint(account, value);
    }
}