// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {VeERC2771Context} from "./VeERC2771Context.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";

library VotingEscrowState {
    using VeERC2771Context for Storage;

    struct Storage {
        /// @dev Address of Meta-tx Forwarder
        address trustedForwarder;
        /// @dev Address of FactoryRegistry.sol
        address factoryRegistry;
        /// @dev Address of token used to create a veNFT
        address token;
        /// @dev Address of RewardsDistributor.sol
        address distributor;
        /// @dev Address of Voter.sol
        address voter;
        /// @dev Address of Protocol Team multisig
        address team;
        /// @dev Address of art proxy used for on-chain art generation
        address artProxy;
        /// @dev Address which can create managed NFTs
        address allowedManager;
        /// @dev Global point history at a given index (epoch -> unsigned global point)
        mapping(uint256 => IVotingEscrow.GlobalPoint) _pointHistory;
        /// @dev Mapping of interface id to bool about whether or not it's supported
        mapping(bytes4 => bool) supportedInterfaces;
        /// @dev Current count of token
        uint256 tokenId;
        /*///////////////////////////////////////////////////////////////
                                MANAGED NFT
        //////////////////////////////////////////////////////////////*/

        /// @dev Mapping of token id to escrow type
        ///      Takes advantage of the fact default value is EscrowType.NORMAL
        mapping(uint256 => IVotingEscrow.EscrowType) escrowType;
        /// @dev Mapping of token id to managed id
        mapping(uint256 => uint256) idToManaged;
        /// @dev Mapping of user token id to managed token id to weight of token id
        mapping(uint256 => mapping(uint256 => uint256)) weights;
        /// @dev Mapping of managed id to deactivated state
        mapping(uint256 => bool) deactivated;
        /// @dev Mapping from managed nft id to locked managed rewards
        ///      `token` denominated rewards (rebases/rewards) stored in locked
        ///      managed rewards contract to prevent co-mingling of assets
        mapping(uint256 => address) managedToLocked;
        /// @dev Mapping from managed nft id to free managed rewards contract
        ///      these rewards can be freely withdrawn by users
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

        /// @dev Mapping from owner address to mapping of index to tokenId
        mapping(address => mapping(uint256 => uint256)) ownerToNFTokenIdList;
        /// @dev Mapping from NFT ID to index of owner
        mapping(uint256 => uint256) tokenToOwnerIndex;
        /*//////////////////////////////////////////////////////////////
                                    ESCROW
        //////////////////////////////////////////////////////////////*/

        /// @dev Total count of epochs witnessed since contract creation
        uint256 epoch;
        /// @dev Total amount of token() deposited
        uint256 supply;
        mapping(uint256 => IVotingEscrow.LockedBalance) _locked;
        mapping(uint256 => IVotingEscrow.UserPoint[1000000000]) _userPointHistory;
        mapping(uint256 => uint256) userPointEpoch;
        /// @dev time -> signed slope change
        mapping(uint256 => int128) slopeChanges;
        /// @dev account -> can split
        mapping(address => bool) canSplit;
        /// @dev Aggregate permanent locked balances
        uint256 permanentLockBalance;
        /*///////////////////////////////////////////////////////////////
                                    DAO VOTING
        //////////////////////////////////////////////////////////////*/

        /// @dev A record of each accounts delegate
        mapping(uint256 => uint256) _delegates;
        /// @dev A record of delegated token checkpoints for each tokenId, by index
        mapping(uint256 => mapping(uint48 => IVotingEscrow.Checkpoint)) _checkpoints;
        /// @dev The number of checkpoints for each tokenId
        mapping(uint256 => uint48) numCheckpoints;
        /// @dev A record of states for signing / validating signatures
        mapping(address => uint256) nonces;
        /*///////////////////////////////////////////////////////////////
                                GAUGE VOTING
        //////////////////////////////////////////////////////////////*/

        /// @dev Information on whether a tokenId has already voted
        mapping(uint256 => bool) voted;

        // Reserved storage space in case we need to add more variables.
        // The convention from OpenZeppelin suggests the storage space should
        // add up to 50 slots. Here we want to have more slots as there are
        // planned upgrades of the VotingEscrow contract. If more entires are
        // added to the struct in the upcoming versions we need to reduce
        // the array size.
        // See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
        uint256[49] __gap;
    }

    function setTeam(
        VotingEscrowState.Storage storage self,
        address _team
    ) internal {
        if (self._msgSender() != self.team) revert IVotingEscrow.NotTeam();
        if (_team == address(0)) revert IVotingEscrow.ZeroAddress();
        self.team = _team;
    }

    function setArtProxy(
        VotingEscrowState.Storage storage self,
        address _proxy
    ) internal {
        if (self._msgSender() != self.team) revert IVotingEscrow.NotTeam();
        self.artProxy = _proxy;
        emit IERC4906.BatchMetadataUpdate(0, type(uint256).max);
    }

    function setVoterAndDistributor(
        VotingEscrowState.Storage storage self,
        address _voter,
        address _distributor
    ) internal {
        if (self._msgSender() != self.voter) revert IVotingEscrow.NotVoter();
        self.voter = _voter;
        self.distributor = _distributor;
    }

    function setVoting(
        VotingEscrowState.Storage storage self,
        uint256 _tokenId,
        bool _voted
    ) internal {
        if (self._msgSender() != self.voter) revert IVotingEscrow.NotVoter();
        self.voted[_tokenId] = _voted;
    }
}
