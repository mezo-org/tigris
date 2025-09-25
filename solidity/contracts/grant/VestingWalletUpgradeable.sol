// This file is a copy of the original file from OpenZeppelin Contracts v5
// https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/dca291a7e9c13ffe9faf0477824e35b735ea6078/contracts/finance/VestingWalletUpgradeable.sol
// With the following changes:
// - The storage structure is aligned with the pattern used in OpenZeppelin Contracts v4:
//   - Defined variables instead of using storage struct.
//   - Added beneficiary() getter to return the owner.
//   - Removed multi-asset support, the contract supports only a single token it
//     was initialized with.

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (finance/VestingWallet.sol)
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev A vesting wallet is an ownable contract that can receive native currency and ERC-20 tokens, and release these
 * assets to the wallet owner, also referred to as "beneficiary", according to a vesting schedule.
 *
 * Any assets transferred to this contract will follow the vesting schedule as if they were locked from the beginning.
 * Consequently, if the vesting has already started, any amount of tokens sent to this contract will (at least partly)
 * be immediately releasable.
 *
 * By setting the duration to 0, one can configure this contract to behave like an asset timelock that holds tokens for
 * a beneficiary until a specified time.
 *
 * NOTE: Since the wallet is {Ownable}, and ownership can be transferred, it is possible to sell unvested tokens.
 * Preventing this in a smart contract is difficult, considering that: 1) a beneficiary address could be a
 * counterfactually deployed contract, 2) there is likely to be a migration path for EOAs to become contracts in the
 * near future.
 *
 * NOTE: When using this contract with any token whose balance is adjusted automatically (i.e. a rebase token), make
 * sure to account the supply/balance adjustment in the vesting schedule to ensure the vested amount is as intended.
 *
 * NOTE: Chains with support for native ERC20s may allow the vesting wallet to withdraw the underlying asset as both an
 * ERC20 and as native currency. For example, if chain C supports token A and the wallet gets deposited 100 A, then
 * at 50% of the vesting period, the beneficiary can withdraw 50 A as ERC20 and 25 A as native currency (totaling 75 A).
 * Consider disabling one of the withdrawal methods.
 */
contract VestingWalletUpgradeable is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable
{
    event ERC20Released(address indexed token, uint256 amount);

    address private _token;
    uint256 private _released;
    uint64 private _start;
    uint64 private _duration;

    /**
     * @dev Sets the beneficiary (owner), the start timestamp and the vesting duration (in seconds) of the vesting
     * wallet.
     */
    function __VestingWallet_init(
        address beneficiary,
        address token,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) internal onlyInitializing {
        __Ownable_init_unchained();
        __VestingWallet_init_unchained(
            beneficiary,
            token,
            startTimestamp,
            durationSeconds
        );
    }

    function __VestingWallet_init_unchained(
        address beneficiary,
        address token,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) internal onlyInitializing {
        require(token != address(0), "VestingWallet: token is zero address");

        _token = token;
        _start = startTimestamp;
        _duration = durationSeconds;

        _transferOwnership(beneficiary);
    }

    /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable virtual {}

    /**
     * @dev Getter for the beneficiary address.
     */
    function beneficiary() public view virtual returns (address) {
        return owner();
    }

    /**
     * @dev Getter for the token address.
     */
    function token() public view virtual returns (address) {
        return _token;
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Getter for the end timestamp.
     */
    function end() public view virtual returns (uint256) {
        return start() + duration();
    }

    /**
     * @dev Amount of token already released
     */
    function released() public view virtual returns (uint256) {
        return _released;
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * {IERC20} contract.
     */
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release() public virtual {
        uint256 amount = releasable();
        _released += amount;
        emit ERC20Released(_token, amount);
        SafeERC20.safeTransfer(IERC20(_token), owner(), amount);
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(
        uint64 timestamp
    ) public view virtual returns (uint256) {
        return
            _vestingSchedule(
                IERC20(_token).balanceOf(address(this)) + released(),
                timestamp
            );
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= end()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
