// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import "./BaseTest.sol";
import "../contracts/Mezo.sol";

contract MezoTest is BaseTest {
    Mezo token;

    function _setUp() public override {
        token = new Mezo();
    }

    function testCannotSetMinterIfNotMinter() public {
        vm.prank(address(owner2));
        vm.expectRevert(IMezo.NotMinter.selector);
        token.setMinter(address(owner3));
    }

    function testSetMinter() public {
        token.setMinter(address(owner3));

        assertEq(token.minter(), address(owner3));
    }

    function testCannotMintIfNotMinter() public {
        vm.prank(address(owner2));
        vm.expectRevert(IMezo.NotMinter.selector);
        token.mint(address(owner2), TOKEN_1);
    }
}
