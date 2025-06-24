// SPDX-License-Identifier: GPL-3.0-or-later

// solhint-disable not-rely-on-time

pragma solidity 0.8.24;

import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VestingWalletUpgradeable} from "@openzeppelin/contracts-upgradeable/finance/VestingWalletUpgradeable.sol";

contract TokenGrant is VestingWalletUpgradeable {
    using SafeERC20 for IERC20;

    error NotBeneficiary();

    IERC20 public token;
    IVotingEscrow public votingEscrow;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) external initializer {
        __VestingWallet_init(beneficiary, startTimestamp, durationSeconds);
    }

    /// @notice Converts TokenGrant to ve NFT with lock time equal to the
    ///         remaining vesting schedule duration rounded down to the nearest
    ///         week. The operation is irreversible.
    function convert() external {
        if (msg.sender != beneficiary()) {
            revert NotBeneficiary();
        }
        // TODO: check if not revoked, withdrawn, or not already converted

        // Any token transferred to this contract will follow the vesting
        // schedule as if they were locked from the beginning so we just take
        // the entire available amount.
        uint256 amount = token.balanceOf(address(this));
        // The time remaining for the grant to fully vest. The rounding happens
        // inside the veNFT logic.
        uint256 duration = end() - block.timestamp;

        _convert(beneficiary(), amount, duration);
    }

    function _convert(
        address beneficiary,
        uint256 amount,
        uint256 duration
    ) internal {
        // TODO: Here we may need to insert some logic that will expose grant
        // details to the ve NFT, as necessary.

        token.forceApprove(address(votingEscrow), amount);
        votingEscrow.createLockFor(amount, duration, beneficiary);
    }

    function end() public view returns (uint256) {
        return start() + duration();
    }
}
