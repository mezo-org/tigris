// SPDX-License-Identifier: GPL-3.0-or-later

// solhint-disable not-rely-on-time

pragma solidity 0.8.24;

import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VestingWalletCliffUpgradeable} from "./VestingWalletCliffUpgradeable.sol";

contract TokenGrant is VestingWalletCliffUpgradeable {
    using SafeERC20 for IERC20;

    error NotBeneficiary();

    IERC20 public token;
    IVotingEscrow public votingEscrow;
    address public grantManager;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffSeconds
    ) public initializer {
        __VestingWallet_init(beneficiary, startTimestamp, durationSeconds);
        __VestingWalletCliff_init(cliffSeconds);
    }

    /// @notice Converts TokenGrant to ve NFT with lock time equal to the
    ///         remaining vesting schedule duration rounded down to the nearest
    ///         week. The operation is irreversible.
    function convert() external {
        if (msg.sender != beneficiary()) {
            revert NotBeneficiary();
        }
        // TODO: check if not revoked, withdrawn, or not already converted

        uint256 amount = token.balanceOf(address(this));

        token.forceApprove(address(votingEscrow), amount);
        votingEscrow.createGrantLockFor(
            amount,
            beneficiary(),
            grantManager,
            end()
        );
    }
}
