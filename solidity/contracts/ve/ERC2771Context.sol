// SPDX-License-Identifier: MIT
// Partially copied from openzeppelin-contracts/contracts/metatx/ERC2771Context.sol

pragma solidity 0.8.24;

import {VotingEscrowState} from "./VotingEscrowState.sol";

/**
 * @dev Context variant with ERC2771 support. Extracted to library to allow
 *      easy application inside libraries.
 */
library ERC2771Context {
    function isTrustedForwarder(
        VotingEscrowState.Storage storage self,
        address forwarder
    ) internal view returns (bool) {
        return forwarder == self.trustedForwarder;
    }

    function _msgSender(
        VotingEscrowState.Storage storage self
    ) internal view returns (address sender) {
        if (isTrustedForwarder(self, msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return msg.sender;
        }
    }

    function _msgData(
        VotingEscrowState.Storage storage self
    ) internal view returns (bytes calldata) {
        if (isTrustedForwarder(self, msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return msg.data;
        }
    }
}
