pragma solidity 0.8.24;

import "./BaseTest.sol";

contract GrantTest is BaseTest {

    uint256 constant GRANT_DURATION = 10 days;

    event CreateGrant(
        uint256 indexed _tokenId,
        address _grantee,
        address _grantManager,
        uint256 _vestingEnd
    );

    function testCreateGrantLockFor() public {
        uint256 vestingEnd = block.timestamp + GRANT_DURATION;
        address grantee = address(owner);

        BTC.approve(address(escrow), TOKEN_1);

        vm.expectEmit(address(escrow));
        emit CreateGrant(1, address(owner), grantManager, vestingEnd);

        uint256 tokenId = escrow.createGrantLockFor(
            TOKEN_1, grantee, grantManager, vestingEnd
        );

        uint256 _lockEnd = escrow.locked(tokenId).end;
        uint256 _vestingEnd = escrow.vestingEnd(tokenId);
        assertEq(_lockEnd, (vestingEnd / WEEK) * WEEK);
        assertEq(_vestingEnd, vestingEnd);

        address _grantManager = escrow.grantManager(tokenId);
        assertEq(_grantManager, grantManager);
    }
}