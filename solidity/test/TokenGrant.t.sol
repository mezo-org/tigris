pragma solidity 0.8.24;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {TokenGrant} from "contracts/grant/TokenGrant.sol";

import "./BaseTest.sol";

contract TokenGrantTest is BaseTest {
    event Converted(uint256 indexed tokenId, uint256 amount);

    uint64 GRANT_DURATION = 3 * 365 days;
    uint64 MAX_DURATION = 4 * 365 days;
    uint64 CLIFF_SECONDS = 2 * 365 days;

    address beneficiary;

    function _setUp() public override {
        beneficiary = address(owner5);
    }

    function newTokenGrant(
        address _beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffSeconds
    ) internal returns (TokenGrant) {
        TokenGrant implementation = new TokenGrant();
        ProxyAdmin proxyAdmin = new ProxyAdmin();

        bytes memory initData = abi.encodeWithSelector(
            TokenGrant.initialize.selector,
            address(MEZO),
            address(mezoEscrow),
            grantManager,
            _beneficiary,
            startTimestamp,
            durationSeconds,
            cliffSeconds
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            initData
        );

        return TokenGrant(payable(proxy));
    }

    function testCannotConvertIfNotBeneficiary() public {
        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS
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
            CLIFF_SECONDS
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
            CLIFF_SECONDS
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
            CLIFF_SECONDS
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

    function testConvertTwiceIfToppedUp() public {
        TokenGrant grant = newTokenGrant(
            beneficiary,
            uint64(block.timestamp),
            GRANT_DURATION,
            CLIFF_SECONDS
        );
        MEZO.transfer(address(grant), TOKEN_100K);

        vm.startPrank(beneficiary);
        uint256 tokenId1 = grant.convert();
        MEZO.transfer(address(grant), TOKEN_10K);
        uint256 tokenId2 = grant.convert();
        vm.stopPrank();

        int128 _lockedAmount1 = mezoEscrow.locked(tokenId1).amount;
        int128 _lockedAmount2 = mezoEscrow.locked(tokenId2).amount;
        assertEq(convert(_lockedAmount1), TOKEN_100K);
        assertEq(convert(_lockedAmount2), TOKEN_10K);

        // just a sanity check for vesting as well
        uint256 vestingEnd = block.timestamp + GRANT_DURATION;
        uint256 _vestingEnd1 = mezoEscrow.vestingEnd(tokenId1);
        uint256 _vestingEnd2 = mezoEscrow.vestingEnd(tokenId2);
        assertEq(_vestingEnd1, vestingEnd);
        assertEq(_vestingEnd2, vestingEnd);
    }

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
                CLIFF_SECONDS
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
                        CLIFF_SECONDS
                    )
                )
            )
        );
        // Sanity check conversion works as well for max duration
        MEZO.transfer(address(grant), TOKEN_100K);
        grant.convert();
    }
}
