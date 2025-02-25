// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import {IVeArtProxy} from "./interfaces/IVeArtProxy.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IReward} from "./interfaces/IReward.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {DelegationLogicLibrary} from "./libraries/DelegationLogicLibrary.sol";
import {BalanceLogicLibrary} from "./libraries/BalanceLogicLibrary.sol";
import {SafeCastLibrary} from "./libraries/SafeCastLibrary.sol";

import {VotingEscrowState} from "./libraries/VotingEscrowState.sol";
import {ManagedNFT} from "./libraries/ManagedNFT.sol";
import {NFT} from "./libraries/NFT.sol";
import {Escrow} from "./libraries/Escrow.sol";
import {Delegation} from "./libraries/Delegation.sol";

/// @title Voting Escrow
/// @notice veNFT implementation that escrows ERC-20 tokens in the form of an ERC-721 NFT
/// @notice Votes have a weight depending on time, so that users are committed to the future of (whatever they are voting for)
/// @author Modified from Solidly (https://github.com/solidlyexchange/solidly/blob/master/contracts/ve.sol)
/// @author Modified from Curve (https://github.com/curvefi/curve-dao-contracts/blob/master/contracts/VotingEscrow.vy)
/// @author velodrome.finance, @figs999, @pegahcarter
/// @dev Vote weight decays linearly over time. Lock time cannot be more than `MAXTIME` (4 years).
abstract contract VotingEscrow is
    IVotingEscrow,
    ERC2771Context,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    using SafeCastLibrary for uint256;
    using SafeCastLibrary for int128;
    using NFT for VotingEscrowState.Storage;
    using ManagedNFT for VotingEscrowState.Storage;
    using Escrow for VotingEscrowState.Storage;
    using Delegation for VotingEscrowState.Storage;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    VotingEscrowState.Storage internal self;

    /// @dev ERC165 interface ID of ERC165
    bytes4 internal constant ERC165_INTERFACE_ID = 0x01ffc9a7;

    /// @dev ERC165 interface ID of ERC721
    bytes4 internal constant ERC721_INTERFACE_ID = 0x80ac58cd;

    /// @dev ERC165 interface ID of ERC721Metadata
    bytes4 internal constant ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;

    /// @dev ERC165 interface ID of ERC4906
    bytes4 internal constant ERC4906_INTERFACE_ID = 0x49064906;

    /// @dev ERC165 interface ID of ERC6372
    bytes4 internal constant ERC6372_INTERFACE_ID = 0xda287a1d;

    /// @param _forwarder address of trusted forwarder
    /// @param _token token address
    /// @param _factoryRegistry Factory Registry address
    constructor(
        address _forwarder,
        address _token,
        address _factoryRegistry
    ) ERC2771Context(_forwarder) {
        self.forwarder = _forwarder;
        self.token = _token;
        self.factoryRegistry = _factoryRegistry;
        self.team = _msgSender();
        self.voter = _msgSender();

        self._pointHistory[0].blk = block.number;
        self._pointHistory[0].ts = block.timestamp;

        self.supportedInterfaces[ERC165_INTERFACE_ID] = true;
        self.supportedInterfaces[ERC721_INTERFACE_ID] = true;
        self.supportedInterfaces[ERC721_METADATA_INTERFACE_ID] = true;
        self.supportedInterfaces[ERC4906_INTERFACE_ID] = true;
        self.supportedInterfaces[ERC6372_INTERFACE_ID] = true;

        // mint-ish
        emit Transfer(address(0), address(this), self.tokenId);
        // burn-ish
        emit Transfer(address(this), address(0), self.tokenId);
    }

    /*///////////////////////////////////////////////////////////////
                            MANAGED NFT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotingEscrow
    function createManagedLockFor(
        address _to
    ) external nonReentrant returns (uint256 _mTokenId) {
        self.createManagedLockFor(_to, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function depositManaged(
        uint256 _tokenId,
        uint256 _mTokenId
    ) external nonReentrant {
        self.depositManaged(_tokenId, _mTokenId, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function withdrawManaged(uint256 _tokenId) external nonReentrant {
        self.withdrawManaged(_tokenId, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function setAllowedManager(address _allowedManager) external {
        self.setAllowedManager(_allowedManager, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function setManagedState(uint256 _mTokenId, bool _state) external {
        self.setManagedState(_mTokenId, _state, _msgSender());
    }

    /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    function setTeam(address _team) external {
        if (_msgSender() != self.team) revert NotTeam();
        if (_team == address(0)) revert ZeroAddress();
        self.team = _team;
    }

    function setArtProxy(address _proxy) external {
        if (_msgSender() != self.team) revert NotTeam();
        self.artProxy = _proxy;
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    /// @inheritdoc IVotingEscrow
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        if (NFT._ownerOf(self, _tokenId) == address(0)) revert NonExistentToken();
        return IVeArtProxy(self.artProxy).tokenURI(_tokenId);
    }

    /// @inheritdoc IVotingEscrow
    function ownerOf(uint256 _tokenId) external view returns (address) {
        return self._ownerOf(_tokenId);
    }

    /// @inheritdoc IVotingEscrow
    function balanceOf(address _owner) external view returns (uint256) {
        return self.ownerToNFTokenCount[_owner];
    }

    /// @inheritdoc IVotingEscrow
    function getApproved(uint256 _tokenId) external view returns (address) {
        return self.idToApprovals[_tokenId];
    }

    /// @inheritdoc IVotingEscrow
    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view returns (bool) {
        return (self.ownerToOperators[_owner])[_operator];
    }

    /// @inheritdoc IVotingEscrow
    function isApprovedOrOwner(
        address _spender,
        uint256 _tokenId
    ) external view returns (bool) {
        return self._isApprovedOrOwner(_spender, _tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotingEscrow
    function approve(address _approved, uint256 _tokenId) external {
        self.approve(_approved, _tokenId, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function setApprovalForAll(address _operator, bool _approved) external {
        self.setApprovalForAll(_operator, _approved, _msgSender());
    }

    /* TRANSFER FUNCTIONS */

    /// @inheritdoc IVotingEscrow
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        self._transferFrom(_from, _to, _tokenId, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    /// @inheritdoc IVotingEscrow
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    ) public {
        self.safeTransferFrom(_from, _to, _tokenId, _data, _msgSender());
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotingEscrow
    function supportsInterface(
        bytes4 _interfaceID
    ) external view returns (bool) {
        return self.supportedInterfaces[_interfaceID];
    }

    /// @inheritdoc IVotingEscrow
    function locked(
        uint256 _tokenId
    ) external view returns (LockedBalance memory) {
        return self._locked[_tokenId];
    }

    /// @inheritdoc IVotingEscrow
    function userPointHistory(
        uint256 _tokenId,
        uint256 _loc
    ) external view returns (UserPoint memory) {
        return self._userPointHistory[_tokenId][_loc];
    }

    /// @inheritdoc IVotingEscrow
    function pointHistory(
        uint256 _loc
    ) external view returns (GlobalPoint memory) {
        return self._pointHistory[_loc];
    }

    /*//////////////////////////////////////////////////////////////
                              ESCROW LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotingEscrow
    function checkpoint() external nonReentrant {
        self._checkpoint(0, LockedBalance(0, 0, false), LockedBalance(0, 0, false));
    }

    /// @inheritdoc IVotingEscrow
    function depositFor(
        uint256 _tokenId,
        uint256 _value
    ) external nonReentrant {
        self.depositFor(_tokenId, _value, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function createLock(
        uint256 _value,
        uint256 _lockDuration
    ) external nonReentrant returns (uint256) {
        return self._createLock(_value, _lockDuration, _msgSender(), _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function createLockFor(
        uint256 _value,
        uint256 _lockDuration,
        address _to
    ) external nonReentrant returns (uint256) {
        return self._createLock(_value, _lockDuration, _to, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function increaseAmount(
        uint256 _tokenId,
        uint256 _value
    ) external nonReentrant {
        self.increaseAmount(_tokenId, _value, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function increaseUnlockTime(
        uint256 _tokenId,
        uint256 _lockDuration
    ) external nonReentrant {
        self.increaseUnlockTime(_tokenId, _lockDuration, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function withdraw(uint256 _tokenId) external nonReentrant {
        self.withdraw(_tokenId, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function merge(uint256 _from, uint256 _to) external nonReentrant {
        self.merge(_from, _to, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function split(
        uint256 _from,
        uint256 _amount
    ) external nonReentrant returns (uint256 _tokenId1, uint256 _tokenId2) {
        return self.split(_from, _amount, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function toggleSplit(address _account, bool _bool) external {
        self.toggleSplit(_account, _bool, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function lockPermanent(uint256 _tokenId) external {
        self.lockPermanent(_tokenId, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function unlockPermanent(uint256 _tokenId) external {
        self.unlockPermanent(_tokenId, _msgSender());
    }

    /*///////////////////////////////////////////////////////////////
                           GAUGE VOTING STORAGE
    //////////////////////////////////////////////////////////////*/

    function _supplyAt(uint256 _timestamp) internal view returns (uint256) {
        return
            BalanceLogicLibrary.supplyAt(
                self.slopeChanges,
                self._pointHistory,
                self.epoch,
                _timestamp
            );
    }

    /// @inheritdoc IVotingEscrow
    function balanceOfNFT(uint256 _tokenId) public view returns (uint256) {
        if (self.ownershipChange[_tokenId] == block.number) return 0;
        return self._balanceOfNFTAt(_tokenId, block.timestamp);
    }

    /// @inheritdoc IVotingEscrow
    function balanceOfNFTAt(
        uint256 _tokenId,
        uint256 _t
    ) external view returns (uint256) {
        return self._balanceOfNFTAt(_tokenId, _t);
    }

    /// @inheritdoc IVotingEscrow
    function totalSupply() external view returns (uint256) {
        return _supplyAt(block.timestamp);
    }

    /// @inheritdoc IVotingEscrow
    function totalSupplyAt(uint256 _timestamp) external view returns (uint256) {
        return _supplyAt(_timestamp);
    }

    /*///////////////////////////////////////////////////////////////
                            GAUGE VOTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotingEscrow
    function setVoterAndDistributor(
        address _voter,
        address _distributor
    ) external {
        if (_msgSender() != self.voter) revert NotVoter();
        self.voter = _voter;
        self.distributor = _distributor;
    }

    /// @inheritdoc IVotingEscrow
    function voting(uint256 _tokenId, bool _voted) external {
        if (_msgSender() != self.voter) revert NotVoter();
        self.voted[_tokenId] = _voted;
    }

    /// @inheritdoc IVotingEscrow
    function delegates(uint256 delegator) external view returns (uint256) {
        return self._delegates[delegator];
    }

    /// @inheritdoc IVotingEscrow
    function checkpoints(
        uint256 _tokenId,
        uint48 _index
    ) external view returns (Checkpoint memory) {
        return self._checkpoints[_tokenId][_index];
    }

    /// @inheritdoc IVotingEscrow
    function getPastVotes(
        address _account,
        uint256 _tokenId,
        uint256 _timestamp
    ) external view returns (uint256) {
        return
            DelegationLogicLibrary.getPastVotes(
                self.numCheckpoints,
                self._checkpoints,
                _account,
                _tokenId,
                _timestamp
            );
    }

    /// @inheritdoc IVotingEscrow
    function getPastTotalSupply(
        uint256 _timestamp
    ) external view returns (uint256) {
        return _supplyAt(_timestamp);
    }

    /*///////////////////////////////////////////////////////////////
                             DAO VOTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotingEscrow
    function delegate(uint256 delegator, uint256 delegatee) external {
        return self.delegate(delegator, delegatee, _msgSender());
    }

    /// @inheritdoc IVotingEscrow
    function delegateBySig(
        uint256 delegator,
        uint256 delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        return self.delegateBySig(
            delegator,
            delegatee,
            nonce,
            expiry,
            v,
            r,
            s,
            this.name(),
            this.version(),
            address(this),
            _msgSender()
        );
    }

    /*//////////////////////////////////////////////////////////////
                              ERC6372 LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVotingEscrow
    function clock() external view returns (uint48) {
        return uint48(block.timestamp);
    }

    /// @inheritdoc IVotingEscrow
    function CLOCK_MODE() external pure returns (string memory) {
        return "mode=timestamp";
    }
}
