// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import {VotingEscrowState} from "./VotingEscrowState.sol";
import {Escrow} from "./Escrow.sol";
import {NFT} from "./NFT.sol";
import {Delegation} from "./Delegation.sol";
import {Balance} from "./Balance.sol";
import {ERC2771Context} from "./ERC2771Context.sol";
import {SafeCastLibrary} from "../libraries/SafeCastLibrary.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {IReward} from "../interfaces/IReward.sol";
import {IVoter} from "../interfaces/IVoter.sol";
import {IManagedRewardsFactory} from "../interfaces/factories/IManagedRewardsFactory.sol";
import {IFactoryRegistry} from "../interfaces/factories/IFactoryRegistry.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";

library ManagedNFT {
    using SafeCastLibrary for uint256;
    using SafeCastLibrary for int128;
    using NFT for VotingEscrowState.Storage;
    using Escrow for VotingEscrowState.Storage;
    using Delegation for VotingEscrowState.Storage;
    using Balance for VotingEscrowState.Storage;
    using ERC2771Context for VotingEscrowState.Storage;

    function createManagedLockFor(
        VotingEscrowState.Storage storage self,
        address _to
    ) external returns (uint256 _mTokenId) {
        address sender = self._msgSender();
        if (
            sender != self.allowedManager &&
            sender != IVoter(self.voter).governor()
        ) revert IVotingEscrow.NotGovernorOrManager();

        _mTokenId = ++self.tokenId;
        self._mint(_to, _mTokenId);
        self._depositFor(
            _mTokenId,
            0,
            0,
            IVotingEscrow.LockedBalance(0, 0, true),
            IVotingEscrow.DepositType.CREATE_LOCK_TYPE
        );

        self.escrowType[_mTokenId] = IVotingEscrow.EscrowType.MANAGED;

        (
            address _lockedManagedReward,
            address _freeManagedReward
        ) = IManagedRewardsFactory(
                IFactoryRegistry(self.factoryRegistry).managedRewardsFactory()
            ).createRewards(self.trustedForwarder, self.voter);
        self.managedToLocked[_mTokenId] = _lockedManagedReward;
        self.managedToFree[_mTokenId] = _freeManagedReward;

        emit IVotingEscrow.CreateManaged(
            _to,
            _mTokenId,
            sender,
            _lockedManagedReward,
            _freeManagedReward
        );
    }

    function depositManaged(
        VotingEscrowState.Storage storage self,
        uint256 _tokenId,
        uint256 _mTokenId
    ) external {
        if (self._msgSender() != self.voter) revert IVotingEscrow.NotVoter();
        if (self.escrowType[_mTokenId] != IVotingEscrow.EscrowType.MANAGED)
            revert IVotingEscrow.NotManagedNFT();
        if (self.escrowType[_tokenId] != IVotingEscrow.EscrowType.NORMAL)
            revert IVotingEscrow.NotNormalNFT();
        if (self._balanceOfNFTAt(_tokenId, block.timestamp) == 0)
            revert IVotingEscrow.ZeroBalance();

        // adjust user nft
        int128 _amount = self._locked[_tokenId].amount;
        if (self._locked[_tokenId].isPermanent) {
            self.permanentLockBalance -= _amount.toUint256();
            self._delegate(_tokenId, 0);
        }
        self._checkpoint(
            _tokenId,
            self._locked[_tokenId],
            IVotingEscrow.LockedBalance(0, 0, false)
        );
        self._locked[_tokenId] = IVotingEscrow.LockedBalance(0, 0, false);

        // adjust managed nft
        uint256 _weight = _amount.toUint256();
        self.permanentLockBalance += _weight;
        IVotingEscrow.LockedBalance memory newLocked = self._locked[_mTokenId];
        newLocked.amount += _amount;
        self._checkpointDelegatee(self._delegates[_mTokenId], _weight, true);
        self._checkpoint(_mTokenId, self._locked[_mTokenId], newLocked);
        self._locked[_mTokenId] = newLocked;

        self.weights[_tokenId][_mTokenId] = _weight;
        self.idToManaged[_tokenId] = _mTokenId;
        self.escrowType[_tokenId] = IVotingEscrow.EscrowType.LOCKED;

        address _lockedManagedReward = self.managedToLocked[_mTokenId];
        IReward(_lockedManagedReward)._deposit(_weight, _tokenId);
        address _freeManagedReward = self.managedToFree[_mTokenId];
        IReward(_freeManagedReward)._deposit(_weight, _tokenId);

        emit IVotingEscrow.DepositManaged(
            self._ownerOf(_tokenId),
            _tokenId,
            _mTokenId,
            _weight,
            block.timestamp
        );
        emit IERC4906.MetadataUpdate(_tokenId);
    }

    function withdrawManaged(
        VotingEscrowState.Storage storage self,
        uint256 _tokenId
    ) external {
        uint256 _mTokenId = self.idToManaged[_tokenId];
        if (self._msgSender() != self.voter) revert IVotingEscrow.NotVoter();
        if (_mTokenId == 0) revert IVotingEscrow.InvalidManagedNFTId();
        if (self.escrowType[_tokenId] != IVotingEscrow.EscrowType.LOCKED)
            revert IVotingEscrow.NotLockedNFT();

        // update accrued rewards
        address _lockedManagedReward = self.managedToLocked[_mTokenId];
        address _freeManagedReward = self.managedToFree[_mTokenId];
        uint256 _weight = self.weights[_tokenId][_mTokenId];
        uint256 _reward = IReward(_lockedManagedReward).earned(
            address(self.token),
            _tokenId
        );
        uint256 _total = _weight + _reward;
        uint256 _unlockTime = ((block.timestamp + Escrow.MAXTIME) /
            Escrow.WEEK) * Escrow.WEEK;

        // claim locked rewards (rebases + compounded reward)
        address[] memory rewards = new address[](1);
        rewards[0] = address(self.token);
        IReward(_lockedManagedReward).getReward(_tokenId, rewards);

        _adjustUserNFT(self, _tokenId, _total, _unlockTime);
        _adjustManagedNFT(self, _mTokenId, _total);

        IReward(_lockedManagedReward)._withdraw(_weight, _tokenId);
        IReward(_freeManagedReward)._withdraw(_weight, _tokenId);

        delete self.idToManaged[_tokenId];
        delete self.weights[_tokenId][_mTokenId];
        delete self.escrowType[_tokenId];

        emit IVotingEscrow.WithdrawManaged(
            self._ownerOf(_tokenId),
            _tokenId,
            _mTokenId,
            _total,
            block.timestamp
        );
        emit IERC4906.MetadataUpdate(_tokenId);
    }

    function _adjustUserNFT(
        VotingEscrowState.Storage storage self,
        uint256 _tokenId,
        uint256 _total,
        uint256 _unlockTime
    ) internal {
        IVotingEscrow.LockedBalance memory newLockedNormal = IVotingEscrow
            .LockedBalance(_total.toInt128(), _unlockTime, false);
        self._checkpoint(_tokenId, self._locked[_tokenId], newLockedNormal);
        self._locked[_tokenId] = newLockedNormal;
    }

    function _adjustManagedNFT(
        VotingEscrowState.Storage storage self,
        uint256 _mTokenId,
        uint256 _total
    ) internal {
        IVotingEscrow.LockedBalance memory newLockedManaged = self._locked[
            _mTokenId
        ];
        // do not expect _total > locked.amount / permanentLockBalance but just in case
        newLockedManaged.amount -= (
            _total.toInt128() < newLockedManaged.amount
                ? _total.toInt128()
                : newLockedManaged.amount
        );
        self.permanentLockBalance -= (
            _total < self.permanentLockBalance
                ? _total
                : self.permanentLockBalance
        );
        self._checkpointDelegatee(self._delegates[_mTokenId], _total, false);
        self._checkpoint(_mTokenId, self._locked[_mTokenId], newLockedManaged);
        self._locked[_mTokenId] = newLockedManaged;
    }

    function setAllowedManager(
        VotingEscrowState.Storage storage self,
        address _allowedManager
    ) external {
        if (self._msgSender() != IVoter(self.voter).governor())
            revert IVotingEscrow.NotGovernor();
        if (_allowedManager == self.allowedManager)
            revert IVotingEscrow.SameAddress();
        if (_allowedManager == address(0)) revert IVotingEscrow.ZeroAddress();
        self.allowedManager = _allowedManager;
        emit IVotingEscrow.SetAllowedManager(_allowedManager);
    }

    function setManagedState(
        VotingEscrowState.Storage storage self,
        uint256 _mTokenId,
        bool _state
    ) external {
        if (
            self._msgSender() != IVoter(self.voter).emergencyCouncil() &&
            self._msgSender() != IVoter(self.voter).governor()
        ) revert IVotingEscrow.NotEmergencyCouncilOrGovernor();
        if (self.escrowType[_mTokenId] != IVotingEscrow.EscrowType.MANAGED)
            revert IVotingEscrow.NotManagedNFT();
        if (self.deactivated[_mTokenId] == _state)
            revert IVotingEscrow.SameState();
        self.deactivated[_mTokenId] = _state;
    }
}
