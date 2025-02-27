// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";

library VotingEscrowState {
    struct Storage {
        /// @inheritdoc IVotingEscrow
        address forwarder;
        /// @inheritdoc IVotingEscrow
        address factoryRegistry;
        /// @inheritdoc IVotingEscrow
        address token;
        /// @inheritdoc IVotingEscrow
        address distributor;
        /// @inheritdoc IVotingEscrow
        address voter;
        /// @inheritdoc IVotingEscrow
        address team;
        /// @inheritdoc IVotingEscrow
        address artProxy;
        /// @inheritdoc IVotingEscrow
        address allowedManager;
        mapping(uint256 => IVotingEscrow.GlobalPoint) _pointHistory; // epoch -> unsigned global point
        /// @dev Mapping of interface id to bool about whether or not it's supported
        mapping(bytes4 => bool) supportedInterfaces;
        /// @inheritdoc IVotingEscrow
        uint256 tokenId;
        /*///////////////////////////////////////////////////////////////
                                MANAGED NFT
        //////////////////////////////////////////////////////////////*/

        /// @inheritdoc IVotingEscrow
        mapping(uint256 => IVotingEscrow.EscrowType) escrowType;
        /// @inheritdoc IVotingEscrow
        mapping(uint256 => uint256) idToManaged;
        /// @inheritdoc IVotingEscrow
        mapping(uint256 => mapping(uint256 => uint256)) weights;
        /// @inheritdoc IVotingEscrow
        mapping(uint256 => bool) deactivated;
        /// @inheritdoc IVotingEscrow
        mapping(uint256 => address) managedToLocked;
        /// @inheritdoc IVotingEscrow
        mapping(uint256 => address) managedToFree;
        /*//////////////////////////////////////////////////////////////
                            ERC721 BALANCE/OWNER
        //////////////////////////////////////////////////////////////*/

        /// @dev Mapping from NFT ID to the address that owns it.
        mapping(uint256 => address) idToOwner;
        /// @dev Mapping from owner address to count of his tokens.
        mapping(address => uint256) ownerToNFTokenCount;
        /*//////////////////////////////////////////////////////////////
                                ERC721 APPROVAL
        //////////////////////////////////////////////////////////////*/

        /// @dev Mapping from NFT ID to approved address.
        mapping(uint256 => address) idToApprovals;
        /// @dev Mapping from owner address to mapping of operator addresses.
        mapping(address => mapping(address => bool)) ownerToOperators;
        mapping(uint256 => uint256) ownershipChange;
        /*//////////////////////////////////////////////////////////////
                            INTERNAL MINT/BURN
        //////////////////////////////////////////////////////////////*/

        /// @inheritdoc IVotingEscrow
        mapping(address => mapping(uint256 => uint256)) ownerToNFTokenIdList;
        /// @dev Mapping from NFT ID to index of owner
        mapping(uint256 => uint256) tokenToOwnerIndex;
        /*//////////////////////////////////////////////////////////////
                                    ESCROW
        //////////////////////////////////////////////////////////////*/

        /// @inheritdoc IVotingEscrow
        uint256 epoch;
        /// @inheritdoc IVotingEscrow
        uint256 supply;
        mapping(uint256 => IVotingEscrow.LockedBalance) _locked;
        mapping(uint256 => IVotingEscrow.UserPoint[1000000000]) _userPointHistory;
        mapping(uint256 => uint256) userPointEpoch;
        /// @inheritdoc IVotingEscrow
        mapping(uint256 => int128) slopeChanges;
        /// @inheritdoc IVotingEscrow
        mapping(address => bool) canSplit;
        /// @inheritdoc IVotingEscrow
        uint256 permanentLockBalance;
        /*///////////////////////////////////////////////////////////////
                                    DAO VOTING
        //////////////////////////////////////////////////////////////*/

        /// @notice A record of each accounts delegate
        mapping(uint256 => uint256) _delegates;
        /// @notice A record of delegated token checkpoints for each tokenId, by index
        mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint)) _checkpoints;
        /// @inheritdoc IVotingEscrow
        mapping(uint256 => uint48) numCheckpoints;
        /// @inheritdoc IVotingEscrow
        mapping(address => uint256) nonces;
        /*///////////////////////////////////////////////////////////////
                                GAUGE VOTING
        //////////////////////////////////////////////////////////////*/

        /// @inheritdoc IVotingEscrow
        mapping(uint256 => bool) voted;
    }

    function setTeam(
        VotingEscrowState.Storage storage self,
        address _team,
        address _msgSender
    ) internal {
        if (_msgSender != self.team) revert IVotingEscrow.NotTeam();
        if (_team == address(0)) revert IVotingEscrow.ZeroAddress();
        self.team = _team;
    }

    function setArtProxy(
        VotingEscrowState.Storage storage self,
        address _proxy,
        address _msgSender
    ) internal {
        if (_msgSender != self.team) revert IVotingEscrow.NotTeam();
        self.artProxy = _proxy;
        emit IERC4906.BatchMetadataUpdate(0, type(uint256).max);
    }

    function setVoterAndDistributor(
        VotingEscrowState.Storage storage self,
        address _voter,
        address _distributor,
        address _msgSender
    ) internal {
        if (_msgSender != self.voter) revert IVotingEscrow.NotVoter();
        self.voter = _voter;
        self.distributor = _distributor;
    }

    function setVoting(
        VotingEscrowState.Storage storage self,
        uint256 _tokenId,
        bool _voted,
        address _msgSender
    ) internal {
        if (_msgSender != self.voter) revert IVotingEscrow.NotVoter();
        self.voted[_tokenId] = _voted;
    }
}
