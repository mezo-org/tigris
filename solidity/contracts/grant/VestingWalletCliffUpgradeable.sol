// This file is a copy of the original file from OpenZeppelin Contracts v5
// https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/dca291a7e9c13ffe9faf0477824e35b735ea6078/contracts/finance/VestingWalletCliffUpgradeable.sol
// With the following changes:
// - The storage structure is aligned with the pattern used in OpenZeppelin Contracts v4:
//   - Defined _cliff as a variable instead of storage struct.
// - The `end` function is added to the contract.

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (finance/VestingWalletCliff.sol)

pragma solidity ^0.8.20;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {VestingWalletUpgradeable} from "@openzeppelin/contracts-upgradeable/finance/VestingWalletUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Extension of {VestingWallet} that adds a cliff to the vesting schedule.
 *
 * _Available since v5.1._
 */
abstract contract VestingWalletCliffUpgradeable is
    Initializable,
    VestingWalletUpgradeable
{
    using SafeCast for *;

    uint64 private _cliff;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;

    /// @dev The specified cliff duration is larger than the vesting duration.
    error InvalidCliffDuration(uint64 cliffSeconds, uint64 durationSeconds);

    /**
     * @dev Set the duration of the cliff, in seconds. The cliff starts vesting schedule (see {VestingWallet}'s
     * constructor) and ends `cliffSeconds` later.
     */
    function __VestingWalletCliff_init(
        uint64 cliffSeconds
    ) internal onlyInitializing {
        __VestingWalletCliff_init_unchained(cliffSeconds);
    }

    function __VestingWalletCliff_init_unchained(
        uint64 cliffSeconds
    ) internal onlyInitializing {
        if (cliffSeconds > duration()) {
            revert InvalidCliffDuration(cliffSeconds, duration().toUint64());
        }
        _cliff = start().toUint64() + cliffSeconds;
    }

    /**
     * @dev Getter for the cliff timestamp.
     */
    function cliff() public view virtual returns (uint256) {
        return _cliff;
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation. Returns 0 if the {cliff} timestamp is not met.
     *
     * IMPORTANT: The cliff not only makes the schedule return 0, but it also ignores every possible side
     * effect from calling the inherited implementation (i.e. `super._vestingSchedule`). Carefully consider
     * this caveat if the overridden implementation of this function has any (e.g. writing to memory or reverting).
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view virtual override returns (uint256) {
        return
            timestamp < cliff()
                ? 0
                : super._vestingSchedule(totalAllocation, timestamp);
    }

    /**
     * @dev Getter for the end timestamp.
     * @dev Added to VestingWalletUpgradeable in OpenZeppelin Contracts v5.
     */
    function end() public view returns (uint256) {
        return start() + duration();
    }
}
