pragma solidity 0.8.24;

import {TokenGrant} from "contracts/grant/TokenGrant.sol";
import {TokenGrantV2} from "./utils/TestTokenGrantV2.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./BaseTest.sol";

contract TokenGrantFactoryTest is BaseTest {
    event TokenGrantCreated(
        address indexed tokenGrant,
        address indexed beneficiary,
        uint256 startTimestamp,
        uint256 cliffTimestamp,
        uint256 endTimestamp,
        bool isRevocable
    );

    address beneficiary1;
    address beneficiary2;
    uint64 startTimestamp1;
    uint64 startTimestamp2;
    uint64 duration1;
    uint64 duration2;
    uint64 cliff1;
    uint64 cliff2;
    bool isRevocable1;
    bool isRevocable2;

    function _setUp() public override {
        beneficiary1 = makeAddr("beneficiary1");
        beneficiary2 = makeAddr("beneficiary2");
        startTimestamp1 = uint64(block.timestamp + 10);
        startTimestamp2 = uint64(block.timestamp + 20);
        duration1 = 201 days;
        duration2 = 201 days;
        cliff1 = 101 days;
        cliff2 = 102 days;
        isRevocable1 = true;
        isRevocable2 = false;
    }

    function testCreateGrant() public {
        createAndVerifyGrant(
            beneficiary1,
            startTimestamp1,
            duration1,
            cliff1,
            isRevocable1
        );
    }

    function testCreateMultipleGrants() public {
        createAndVerifyGrant(
            beneficiary1,
            startTimestamp1,
            duration1,
            cliff1,
            isRevocable1
        );

        createAndVerifyGrant(
            beneficiary2,
            startTimestamp2,
            duration2,
            cliff2,
            isRevocable2
        );
    }

    function testUpgradeTokenGrantImplementation() public {
        TokenGrant grant1 = createAndVerifyGrant(
            beneficiary1,
            startTimestamp1,
            duration1,
            cliff1,
            isRevocable1
        );

        TokenGrant grant2 = createAndVerifyGrant(
            beneficiary2,
            startTimestamp2,
            duration2,
            cliff2,
            isRevocable2
        );

        // Upgrade the implementation through the factory.
        TokenGrantV2 tokenGrantV2Impl = new TokenGrantV2();
        tokenGrantFactory.upgradeTokenGrantImplementation(
            address(tokenGrantV2Impl)
        );

        assertEq(tokenGrantFactory.implementation(), address(tokenGrantV2Impl));

        // Verify the implementation is upgraded for both grants.
        assertEq(TokenGrantV2(payable(address(grant1))).version(), 2);
        assertEq(TokenGrantV2(payable(address(grant2))).version(), 2);

        // Verify the grant state is unchanged.
        assertEq(grant1.beneficiary(), beneficiary1);
        assertEq(grant2.beneficiary(), beneficiary2);

        assertEq(grant1.start(), startTimestamp1);
        assertEq(grant2.start(), startTimestamp2);

        assertEq(grant1.end(), startTimestamp1 + duration1);
        assertEq(grant2.end(), startTimestamp2 + duration2);

        assertEq(grant1.cliff(), startTimestamp1 + cliff1);
        assertEq(grant2.cliff(), startTimestamp2 + cliff2);

        assertEq(grant1.isRevocable(), isRevocable1);
        assertEq(grant2.isRevocable(), isRevocable2);
    }

    function testCannotUpgradeToZeroAddress() public {
        vm.expectRevert(TokenGrantFactory.ZeroAddress.selector);
        tokenGrantFactory.upgradeTokenGrantImplementation(address(0));
    }

    function testCannotUpgradeIfNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(beneficiary1);
        tokenGrantFactory.upgradeTokenGrantImplementation(address(1));
    }

    function createAndVerifyGrant(
        address beneficiary,
        uint64 startTimestamp,
        uint64 duration,
        uint64 cliff,
        bool isRevocable
    ) internal returns (TokenGrant) {
        // Don't check the tokenGrant address (first parameter) since we can't know it beforehand
        vm.expectEmit(false, true, false, true);
        emit TokenGrantCreated(
            address(0), // We don't check this address
            beneficiary,
            startTimestamp,
            startTimestamp + cliff,
            startTimestamp + duration,
            isRevocable
        );

        address grantAddress = tokenGrantFactory.createGrant(
            beneficiary,
            startTimestamp,
            duration,
            cliff,
            isRevocable
        );

        TokenGrant grant = TokenGrant(payable(grantAddress));
        assertEq(address(grant.token()), address(MEZO));
        assertEq(address(grant.votingEscrow()), address(mezoEscrow));
        assertEq(grant.grantManager(), grantManager);
        assertEq(grant.beneficiary(), beneficiary);
        assertEq(grant.start(), startTimestamp);
        assertEq(grant.end(), startTimestamp + duration);
        assertEq(grant.cliff(), startTimestamp + cliff);
        assertEq(grant.isRevocable(), isRevocable);

        return grant;
    }
}
