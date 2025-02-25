// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import {VotingEscrowState} from "./VotingEscrowState.sol";
import {NFT} from "./NFT.sol";
import {DelegationLogicLibrary} from "./DelegationLogicLibrary.sol";
import {SafeCastLibrary} from "./SafeCastLibrary.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {IVotes} from "../governance/IVotes.sol";

library Delegation {
    using SafeCastLibrary for int128;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256(
            "Delegation(uint256 delegator,uint256 delegatee,uint256 nonce,uint256 expiry)"
        );

    function delegate(
        VotingEscrowState.Storage storage self,
        uint256 delegator,
        uint256 delegatee,
        address _msgSender
    ) external {
        if (!NFT._isApprovedOrOwner(self, _msgSender, delegator))
            revert IVotingEscrow.NotApprovedOrOwner();
        return _delegate(self, delegator, delegatee, _msgSender);
    }

    function delegateBySig(
        VotingEscrowState.Storage storage self,
        uint256 delegator,
        uint256 delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string calldata contractName,
        string calldata contractVersion,
        address contractAddress,
        address msgSender
    ) external {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) revert IVotingEscrow.InvalidSignatureS();
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(contractName)),
                keccak256(bytes(contractVersion)),
                block.chainid,
                contractAddress
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(DELEGATION_TYPEHASH, delegator, delegatee, nonce, expiry)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        if (!NFT._isApprovedOrOwner(self, signatory, delegator))
            revert IVotingEscrow.NotApprovedOrOwner();
        if (signatory == address(0)) revert IVotingEscrow.InvalidSignature();
        if (nonce != self.nonces[signatory]++) revert IVotingEscrow.InvalidNonce();
        if (block.timestamp > expiry) revert IVotingEscrow.SignatureExpired();
        return _delegate(self, delegator, delegatee, msgSender);
    }

    /// @notice Record user delegation checkpoints. Used by voting system.
    /// @dev Skips delegation if already delegated to `delegatee`.
    function _delegate(
        VotingEscrowState.Storage storage self,
        uint256 _delegator,
        uint256 _delegatee,
        address _msgSender
    ) internal {
        IVotingEscrow.LockedBalance memory delegateLocked = self._locked[_delegator];
        if (!delegateLocked.isPermanent) revert IVotingEscrow.NotPermanentLock();
        if (_delegatee != 0 && NFT._ownerOf(self, _delegatee) == address(0))
            revert IVotingEscrow.NonExistentToken();
        if (self.ownershipChange[_delegator] == block.number)
            revert IVotingEscrow.OwnershipChange();
        if (_delegatee == _delegator) _delegatee = 0;
        uint256 currentDelegate = self._delegates[_delegator];
        if (currentDelegate == _delegatee) return;

        uint256 delegatedBalance = delegateLocked.amount.toUint256();
        _checkpointDelegator(self, _delegator, _delegatee, NFT._ownerOf(self, _delegator));
        _checkpointDelegatee(self, _delegatee, delegatedBalance, true);

        emit IVotes.DelegateChanged(_msgSender, currentDelegate, _delegatee);
    }

    function _checkpointDelegatee(
        VotingEscrowState.Storage storage self,
        uint256 _delegatee,
        uint256 balance_,
        bool _increase
    ) internal {
        DelegationLogicLibrary.checkpointDelegatee(
            self.numCheckpoints,
            self._checkpoints,
            _delegatee,
            balance_,
            _increase
        );
    }

    function _checkpointDelegator(
        VotingEscrowState.Storage storage self,
        uint256 _delegator,
        uint256 _delegatee,
        address _owner
    ) internal {
        DelegationLogicLibrary.checkpointDelegator(
            self._locked,
            self.numCheckpoints,
            self._checkpoints,
            self._delegates,
            _delegator,
            _delegatee,
            _owner
        );
    }
}
