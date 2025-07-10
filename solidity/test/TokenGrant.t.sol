pragma solidity 0.8.24;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {TokenGrant} from "contracts/grant/TokenGrant.sol";
import {TokenGrantFactory} from "contracts/grant/TokenGrantFactory.sol";

import "./BaseTest.sol";

import {console} from "forge-std/console.sol";

contract TokenGrantTest is BaseTest {
    event Converted(uint256 indexed tokenId, uint256 amount);
    event Revoked(address indexed destination, uint256 amount);

    uint64 GRANT_DURATION = 3 * 365 days;
    uint64 MAX_DURATION = 4 * 365 days;
    uint64 CLIFF_SECONDS = 2 * 365 days;

    address beneficiary;

    function _setUp() public override {
        beneficiary = makeAddr("beneficiary");
    }

    function newTokenGrant(
        address _beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffSeconds,
        bool isRevocable
    ) internal returns (TokenGrant) {
        TokenGrant implementation = new TokenGrant();
        TokenGrantFactory factory = new TokenGrantFactory();

        factory.initialize(
            address(MEZO),
            address(mezoEscrow),
            grantManager,
            address(implementation)
        );

        address tokenGrant = factory.createGrant(
            _beneficiary,
            startTimestamp,
            durationSeconds,
            cliffSeconds,
            isRevocable
        );

        return TokenGrant(payable(tokenGrant));
    }

    function testCannotConvertIfNotBeneficiary() public {
        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            true
        );

        vm.prank(address(owner2));
        vm.expectRevert(TokenGrant.NotBeneficiary.selector);
        grant.convert();
    }

    function testCannotConvertIfNoTokens() public {
        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            true
        );

        vm.prank(beneficiary);
        vm.expectRevert(TokenGrant.EmptyGrant.selector);
        grant.convert();
    }

    function testConvert() public {
        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            true
        );
        MEZO.transfer(address(grant), TOKEN_100K);

        vm.prank(beneficiary);

        // Skip check for tokenId as it's generated inside the function.
        vm.expectEmit(false, false, false, true);
        emit Converted(0, TOKEN_100K);

        uint256 tokenId = grant.convert();

        uint256 vestingEnd = block.timestamp + GRANT_DURATION;

        uint256 _lockEnd = mezoEscrow.locked(tokenId).end;
        uint256 _vestingEnd = mezoEscrow.vestingEnd(tokenId);
        assertEq(_lockEnd, (vestingEnd / WEEK) * WEEK);
        assertEq(_vestingEnd, vestingEnd);

        address _grantManager = mezoEscrow.grantManager(tokenId);
        assertEq(_grantManager, grantManager);
    }

    function testCannotConvertTwiceIfNoTokens() public {
        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            true
        );
        MEZO.transfer(address(grant), TOKEN_100K);

        vm.startPrank(beneficiary);
        // First conversion works fine and takes all tokens
        grant.convert();
        // Second conversion should fail as no tokens are left
        vm.expectRevert(TokenGrant.EmptyGrant.selector);
        grant.convert();
        vm.stopPrank();
    }

    // function testConvertTwiceIfToppedUp() public {
    //     TokenGrant grant = newTokenGrant(
    //         beneficiary,
    //         uint64(block.timestamp),
    //         GRANT_DURATION,
    //         CLIFF_SECONDS,
    //         true
    //     );
    //     MEZO.transfer(address(grant), TOKEN_100K);

    //     vm.startPrank(beneficiary);
    //     uint256 tokenId1 = grant.convert();
    //     MEZO.transfer(address(grant), TOKEN_10K);
    //     uint256 tokenId2 = grant.convert();
    //     vm.stopPrank();

    //     int128 _lockedAmount1 = mezoEscrow.locked(tokenId1).amount;
    //     int128 _lockedAmount2 = mezoEscrow.locked(tokenId2).amount;
    //     assertEq(convert(_lockedAmount1), TOKEN_100K);
    //     assertEq(convert(_lockedAmount2), TOKEN_10K);

    //     // just a sanity check for vesting as well
    //     uint256 vestingEnd = block.timestamp + GRANT_DURATION;
    //     uint256 _vestingEnd1 = mezoEscrow.vestingEnd(tokenId1);
    //     uint256 _vestingEnd2 = mezoEscrow.vestingEnd(tokenId2);
    //     assertEq(_vestingEnd1, vestingEnd);
    //     assertEq(_vestingEnd2, vestingEnd);
    // }

    function cannotInitWithMaxDurationExceeded() public {
        TokenGrant implementation = new TokenGrant();
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        // Fails for max duration exceeded
        vm.expectRevert(TokenGrant.MaxDurationExceeded.selector);
        new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            abi.encodeWithSelector(
                TokenGrant.initialize.selector,
                address(MEZO),
                address(mezoEscrow),
                address(owner),
                address(owner),
                block.timestamp,
                MAX_DURATION + 1,
                CLIFF_SECONDS,
                true
            )
        );
    }

    function testCanInitWithMaxDuration() public {
        TokenGrant implementation = new TokenGrant();
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        TokenGrant grant = TokenGrant(
            payable(
                new TransparentUpgradeableProxy(
                    address(implementation),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        TokenGrant.initialize.selector,
                        address(MEZO),
                        address(mezoEscrow),
                        address(owner),
                        address(owner),
                        block.timestamp,
                        MAX_DURATION,
                        CLIFF_SECONDS,
                        true
                    )
                )
            )
        );
        // Sanity check conversion works as well for max duration
        MEZO.transfer(address(grant), TOKEN_100K);
        grant.convert();
    }

    function testCannotRevokeIfNotGrantManager() public {
        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            true
        );

        vm.prank(beneficiary);
        vm.expectRevert(TokenGrant.NotGrantManager.selector);
        grant.revoke(address(grantManager));
    }

    function testCannotRevokeIfNonRevocable() public {
        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            false
        );

        vm.prank(address(grantManager));
        vm.expectRevert(TokenGrant.NonRevocableGrant.selector);
        grant.revoke(beneficiary);
    }

    function testCannotRevokeIfNoTokens() public {
        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            true
        );

        vm.prank(address(grantManager));
        vm.expectRevert(TokenGrant.EmptyGrant.selector);
        grant.revoke(beneficiary);
    }

    function testCanRevoke() public {
        address destination = makeAddr("destination");

        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            true
        );
        MEZO.transfer(address(grant), TOKEN_100K);

        vm.expectEmit(true, false, false, true);
        emit Revoked(destination, TOKEN_100K);

        vm.prank(address(grantManager));
        grant.revoke(destination);

        assertEq(MEZO.balanceOf(destination), TOKEN_100K);
        assertEq(MEZO.balanceOf(address(grant)), 0);
        assertEq(MEZO.balanceOf(grantManager), 0);
        assertEq(MEZO.balanceOf(beneficiary), 0);
    }

    function testCanRevokeIfPartiallyVested() public {
        address destination = makeAddr("destination");

        // Assume grant duration to be set to 3 years and revoke happens after
        // 2 years, so the remaining grant duration is 1 year.
        uint256 remainingGrantDuration = 1 * 365 days;
        uint256 expectedRevokedAmount = (TOKEN_100K * remainingGrantDuration) /
            (GRANT_DURATION) +
            1;

        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            true
        );
        MEZO.transfer(address(grant), TOKEN_100K);

        vm.warp(grant.end() - remainingGrantDuration);

        vm.prank(address(grantManager));
        grant.revoke(destination);

        assertEq(MEZO.balanceOf(destination), expectedRevokedAmount);
        assertEq(
            MEZO.balanceOf(address(grant)),
            TOKEN_100K - expectedRevokedAmount
        );
        assertEq(grant.releasable(), TOKEN_100K - expectedRevokedAmount);
        // assertEq(MEZO.balanceOf(grantManager), 0);
    }

    function testCanRevokeIfPartiallyVestedAndReleased() public {
        address destination = makeAddr("destination");

        // In this scenario, the grant is created for 4 years and 120 MEZO.
        uint256 grantAmount = 120 * 10 ** 18; // 120 MEZO
        uint64 grantDuration = 4 * 365 days;

        // After 1 year, grantee claims tokens. They are expected to receive 30 MEZO.
        uint256 releasedAfter = 1 * 365 days;
        uint256 expectedReleasedAmount = 30 * 10 ** 18; // 1/4 * 120 = 30

        // After 3 years, grant manager revokes the grant. The grant manager is
        // expected to revoke the unvested 30 MEZO.
        uint256 revokedAfter = 3 * 365 days;
        uint256 expectedRevokedAmount = 30 * 10 ** 18; // 120 - (3/4 * 120) = 30
        // After the grant is revoked there is still 60 MEZO the grantee can release
        // as these tokens have already vested.
        uint256 expectedRemainingReleasableAmount = 60 * 10 ** 18;

        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            grantDuration,
            0,
            true
        );
        MEZO.transfer(address(grant), grantAmount);

        // Progress to 1 year and claim tokens.
        vm.warp(grant.start() + releasedAfter);
        vm.prank(beneficiary);
        grant.release();

        assertEq(MEZO.balanceOf(beneficiary), expectedReleasedAmount);

        // Progress to 3 years and revoke the grant.
        vm.warp(grant.start() + revokedAfter);
        vm.prank(address(grantManager));
        grant.revoke(destination);

        assertEq(MEZO.balanceOf(destination), expectedRevokedAmount);
        assertEq(
            MEZO.balanceOf(address(grant)),
            expectedRemainingReleasableAmount
        );
        assertEq(grant.releasable(), expectedRemainingReleasableAmount);
        assertEq(MEZO.balanceOf(grantManager), 0);
    }

    function testCannotRevokeIfGrantIsVested() public {
        address destination = makeAddr("destination");

        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS,
            true
        );
        MEZO.transfer(address(grant), TOKEN_100K);

        vm.warp(grant.end());

        vm.prank(address(grantManager));
        vm.expectRevert(TokenGrant.GrantAlreadyVested.selector);
        grant.revoke(destination);
    }
}
