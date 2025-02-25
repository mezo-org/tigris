// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "./VotingEscrowState.sol";
import "./Escrow.sol";
import "./NFT.sol";
import {DelegationLogicLibrary} from "./DelegationLogicLibrary.sol";
import {BalanceLogicLibrary} from "./BalanceLogicLibrary.sol";
import "../interfaces/IVotingEscrow.sol";
import {IReward} from "../interfaces/IReward.sol";
import {IVoter} from "../interfaces/IVoter.sol";
import {IManagedRewardsFactory} from "../interfaces/factories/IManagedRewardsFactory.sol";
import {IFactoryRegistry} from "../interfaces/factories/IFactoryRegistry.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
library ManagedNFT {
    using SafeCastLibrary for uint256;
    using SafeCastLibrary for int128;

    function createManagedLockFor(
        VotingEscrowState.Storage storage self,
        address _to,
        address _msgSender
    ) external returns (uint256 _mTokenId) {
        if (_msgSender != self.allowedManager && _msgSender != IVoter(self.voter).governor())
            revert IVotingEscrow.NotGovernorOrManager();

        _mTokenId = ++self.tokenId;
        NFT._mint(self, _to, _mTokenId);
        Escrow._depositFor(
            self,
            _mTokenId,
            0,
            0,
            IVotingEscrow.LockedBalance(0, 0, true),
            IVotingEscrow.DepositType.CREATE_LOCK_TYPE,
            _msgSender
        );

        self.escrowType[_mTokenId] = IVotingEscrow.EscrowType.MANAGED;

        (
            address _lockedManagedReward,
            address _freeManagedReward
        ) = IManagedRewardsFactory(
                IFactoryRegistry(self.factoryRegistry).managedRewardsFactory()
            ).createRewards(self.forwarder, self.voter);
        self.managedToLocked[_mTokenId] = _lockedManagedReward;
        self.managedToFree[_mTokenId] = _freeManagedReward;

        emit IVotingEscrow.CreateManaged(
            _to,
            _mTokenId,
            _msgSender,
            _lockedManagedReward,
            _freeManagedReward
        );
    }

    function depositManaged(
        VotingEscrowState.Storage storage self,
        uint256 _tokenId,
        uint256 _mTokenId,
        address _msgSender
    ) external {
        if (_msgSender != self.voter) revert IVotingEscrow.NotVoter();
        if (self.escrowType[_mTokenId] != IVotingEscrow.EscrowType.MANAGED) revert IVotingEscrow.NotManagedNFT();
        if (self.escrowType[_tokenId] != IVotingEscrow.EscrowType.NORMAL) revert IVotingEscrow.NotNormalNFT();
        if (_balanceOfNFTAt(self, _tokenId, block.timestamp) == 0)
            revert IVotingEscrow.ZeroBalance();

        // adjust user nft
        int128 _amount = self._locked[_tokenId].amount;
        if (self._locked[_tokenId].isPermanent) {
            self.permanentLockBalance -= _amount.toUint256();
            Delegation._delegate(self, _tokenId, 0, _msgSender);
        }
        Escrow._checkpoint(self, _tokenId, self._locked[_tokenId], IVotingEscrow.LockedBalance(0, 0, false));
        self._locked[_tokenId] = IVotingEscrow.LockedBalance(0, 0, false);

        // adjust managed nft
        uint256 _weight = _amount.toUint256();
        self.permanentLockBalance += _weight;
        IVotingEscrow.LockedBalance memory newLocked = self._locked[_mTokenId];
        newLocked.amount += _amount;
        Delegation._checkpointDelegatee(self, self._delegates[_mTokenId], _weight, true);
        Escrow._checkpoint(self, _mTokenId, self._locked[_mTokenId], newLocked);
        self._locked[_mTokenId] = newLocked;

        self.weights[_tokenId][_mTokenId] = _weight;
        self.idToManaged[_tokenId] = _mTokenId;
        self.escrowType[_tokenId] = IVotingEscrow.EscrowType.LOCKED;

        address _lockedManagedReward = self.managedToLocked[_mTokenId];
        IReward(_lockedManagedReward)._deposit(_weight, _tokenId);
        address _freeManagedReward = self.managedToFree[_mTokenId];
        IReward(_freeManagedReward)._deposit(_weight, _tokenId);

        emit IVotingEscrow.DepositManaged(
            NFT._ownerOf(self, _tokenId),
            _tokenId,
            _mTokenId,
            _weight,
            block.timestamp
        );
        emit IERC4906.MetadataUpdate(_tokenId);
    }

    function withdrawManaged(
        VotingEscrowState.Storage storage self,
        uint256 _tokenId,
        address _msgSender
    ) external {
        uint256 _mTokenId = self.idToManaged[_tokenId];
        if (_msgSender != self.voter) revert IVotingEscrow.NotVoter();
        if (_mTokenId == 0) revert IVotingEscrow.InvalidManagedNFTId();
        if (self.escrowType[_tokenId] != IVotingEscrow.EscrowType.LOCKED) revert IVotingEscrow.NotLockedNFT();

        // update accrued rewards
        address _lockedManagedReward = self.managedToLocked[_mTokenId];
        address _freeManagedReward = self.managedToFree[_mTokenId];
        uint256 _weight = self.weights[_tokenId][_mTokenId];
        uint256 _reward = IReward(_lockedManagedReward).earned(
            address(self.token),
            _tokenId
        );
        uint256 _total = _weight + _reward;
        uint256 _unlockTime = ((block.timestamp + Escrow.MAXTIME) / Escrow.WEEK) * Escrow.WEEK;

        // claim locked rewards (rebases + compounded reward)
        address[] memory rewards = new address[](1);
        rewards[0] = address(self.token);
        IReward(_lockedManagedReward).getReward(_tokenId, rewards);

        // adjust user nft
        IVotingEscrow.LockedBalance memory newLockedNormal = IVotingEscrow.LockedBalance(
            _total.toInt128(),
            _unlockTime,
            false
        );
        Escrow._checkpoint(self, _tokenId, self._locked[_tokenId], newLockedNormal);
        self._locked[_tokenId] = newLockedNormal;

        // adjust managed nft
        IVotingEscrow.LockedBalance memory newLockedManaged = self._locked[_mTokenId];
        // do not expect _total > locked.amount / permanentLockBalance but just in case
        newLockedManaged.amount -= (
            _total.toInt128() < newLockedManaged.amount
                ? _total.toInt128()
                : newLockedManaged.amount
        );
        self.permanentLockBalance -= (
            _total < self.permanentLockBalance ? _total : self.permanentLockBalance
        );
        Delegation._checkpointDelegatee(self, self._delegates[_mTokenId], _total, false);
        Escrow._checkpoint(self, _mTokenId, self._locked[_mTokenId], newLockedManaged);
        self._locked[_mTokenId] = newLockedManaged;

        IReward(_lockedManagedReward)._withdraw(_weight, _tokenId);
        IReward(_freeManagedReward)._withdraw(_weight, _tokenId);

        delete self.idToManaged[_tokenId];
        delete self.weights[_tokenId][_mTokenId];
        delete self.escrowType[_tokenId];

        emit IVotingEscrow.WithdrawManaged(
            NFT._ownerOf(self, _tokenId),
            _tokenId,
            _mTokenId,
            _total,
            block.timestamp
        );
        emit IERC4906.MetadataUpdate(_tokenId);
    }

    function setAllowedManager(
        VotingEscrowState.Storage storage self,
        address _allowedManager,
        address _msgSender
    ) external {
        if (_msgSender != IVoter(self.voter).governor()) revert IVotingEscrow.NotGovernor();
        if (_allowedManager == self.allowedManager) revert IVotingEscrow.SameAddress();
        if (_allowedManager == address(0)) revert IVotingEscrow.ZeroAddress();
        self.allowedManager = _allowedManager;
        emit IVotingEscrow.SetAllowedManager(_allowedManager);
    }

    function setManagedState(
        VotingEscrowState.Storage storage self,
        uint256 _mTokenId,
        bool _state,
        address _msgSender
    ) external {
        if (
            _msgSender != IVoter(self.voter).emergencyCouncil() &&
            _msgSender != IVoter(self.voter).governor()
        ) revert IVotingEscrow.NotEmergencyCouncilOrGovernor();
        if (self.escrowType[_mTokenId] != IVotingEscrow.EscrowType.MANAGED) revert IVotingEscrow.NotManagedNFT();
        if (self.deactivated[_mTokenId] == _state) revert IVotingEscrow.SameState();
        self.deactivated[_mTokenId] = _state;
    }

    function _balanceOfNFTAt(
        VotingEscrowState.Storage storage self,
        uint256 _tokenId,
        uint256 _t
    ) internal view returns (uint256) {
        return
            BalanceLogicLibrary.balanceOfNFTAt(
                self.userPointEpoch,
                self._userPointHistory,
                _tokenId,
                _t
            );
    }
}