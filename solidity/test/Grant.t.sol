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
    event Merge(
        address indexed _sender,
        uint256 indexed _from,
        uint256 indexed _to,
        uint256 _amountFrom,
        uint256 _amountTo,
        uint256 _amountFinal,
        uint256 _locktime,
        uint256 _ts
    );
    event Split(
        uint256 indexed _from,
        uint256 indexed _tokenId1,
        uint256 indexed _tokenId2,
        address _sender,
        uint256 _splitAmount1,
        uint256 _splitAmount2,
        uint256 _locktime,
        uint256 _ts
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

    function testCannotMergeFromUnvestedGrantNFT() public {
        uint256 vestingEnd = block.timestamp + GRANT_DURATION;
        address grantee = address(owner);

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId1 = escrow.createGrantLockFor(
            TOKEN_1, grantee, grantManager, vestingEnd
        );

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId2 = escrow.createLock(TOKEN_1, WEEK);

        vm.expectRevert(IVotingEscrow.UnvestedGrantNFT.selector);
        escrow.merge(tokenId1, tokenId2);
    }

    function testCannotMergeToUnvestedGrantNFT() public { 
        uint256 vestingEnd = block.timestamp + GRANT_DURATION;
        address grantee = address(owner);

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId1 = escrow.createLock(TOKEN_1, WEEK);

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId2 = escrow.createGrantLockFor(
            TOKEN_1, grantee, grantManager, vestingEnd
        );

        vm.expectRevert(IVotingEscrow.UnvestedGrantNFT.selector);
        escrow.merge(tokenId1, tokenId2);
    }

    function testCanMergeFromVestedGrantNFT() public {
        uint256 vestingEnd = block.timestamp + GRANT_DURATION;
        address grantee = address(owner);

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId1 = escrow.createGrantLockFor(
            TOKEN_1, grantee, grantManager, vestingEnd
        );

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId2 = escrow.createLock(TOKEN_1, WEEK);
        
        escrow.lockPermanent(tokenId2);

        skip(GRANT_DURATION);

        vm.expectEmit(address(escrow));
        emit Merge(
            address(owner), 
            tokenId1, 
            tokenId2, 
            TOKEN_1, 
            TOKEN_1, 
            TOKEN_1 * 2, 
            0, 
            1468801
        );
        escrow.merge(tokenId1, tokenId2);
    }

    function testCanMergeToVestedGrantNFT() public {
        uint256 vestingEnd = block.timestamp + GRANT_DURATION;
        address grantee = address(owner);

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId1 = escrow.createLock(TOKEN_1, WEEK);

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId2 = escrow.createGrantLockFor(
            TOKEN_1, grantee, grantManager, vestingEnd
        );
        
        escrow.lockPermanent(tokenId2);
        skip(GRANT_DURATION);

        vm.expectEmit(address(escrow));
        emit Merge(
            address(owner), 
            tokenId1, 
            tokenId2, 
            TOKEN_1, 
            TOKEN_1, 
            TOKEN_1 * 2, 
            0, 
            1468801
        );
        escrow.merge(tokenId1, tokenId2);
    }

    function testCannotSplitUnvestedGrantNFT() public {
        uint256 vestingEnd = block.timestamp + GRANT_DURATION;
        address grantee = address(owner);

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId = escrow.createGrantLockFor(
            TOKEN_1, grantee, grantManager, vestingEnd
        );

        escrow.toggleSplit(grantee, true);   
        escrow.lockPermanent(tokenId);

        vm.expectRevert(IVotingEscrow.UnvestedGrantNFT.selector);
        escrow.split(1, TOKEN_1 / 2);
    }

    function testCanSplitVestedGrantNFT() public {
        uint256 vestingEnd = block.timestamp + GRANT_DURATION;
        address grantee = address(owner);

        BTC.approve(address(escrow), TOKEN_1);
        uint256 tokenId = escrow.createGrantLockFor(
            TOKEN_1, grantee, grantManager, vestingEnd
        );

        escrow.toggleSplit(grantee, true);   
        escrow.lockPermanent(tokenId);
        skip(GRANT_DURATION);

        vm.expectEmit(address(escrow));
        emit Split(1, 2, 3, grantee, TOKEN_1 / 2, TOKEN_1 / 2, 0, 1468801);
        escrow.split(1, TOKEN_1 / 2);
    }
}