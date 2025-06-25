// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.24;

import {VotingEscrowState} from "./VotingEscrowState.sol";
import {Escrow} from "./Escrow.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";

library Grant {
    using Escrow for VotingEscrowState.Storage;

    function _createGrantLockFor(
        VotingEscrowState.Storage storage self,
        uint256 _value,
        address _grantee,
        address _grantManager,
        uint256 _vestingEnd
    ) external returns (uint256) {
        uint256 lockDuration = _vestingEnd - block.timestamp;

        uint256 tokenId = self._createLock(_value, lockDuration, _grantee);
        self.grantManager[tokenId] = _grantManager;
        self.vestingEnd[tokenId] = _vestingEnd;

        emit IVotingEscrow.CreateGrant(
            tokenId,
            _grantee,
            _grantManager,
            _vestingEnd
        );

        return tokenId;
    }

    function _setGrantManager(
        VotingEscrowState.Storage storage self,
        uint256 _tokenId,
        address _newGrantManager
    ) external {
        if (msg.sender != self.grantManager[_tokenId]) {
            revert IVotingEscrow.NotGrantManager();
        }

        self.grantManager[_tokenId] = _newGrantManager;
        emit IVotingEscrow.SetGrantManager(_newGrantManager);
    }
}
