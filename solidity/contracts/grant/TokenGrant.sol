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
    error EmptyGrant();
    error MaxDurationExceeded();

    uint256 internal constant MAX_DURATION = 4 * 365 days;

    IERC20 public token;
    IVotingEscrow public votingEscrow;
    address public grantManager;

    event Converted(uint256 indexed tokenId, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _token,
        address _votingEscrow,
        address _grantManager,
        address _beneficiary,
        uint64 _startTimestamp,
        uint64 _durationSeconds,
        uint64 _cliffSeconds
    ) external initializer {
        if (_durationSeconds > MAX_DURATION) {
            revert MaxDurationExceeded();
        }

        __VestingWallet_init(_beneficiary, _startTimestamp, _durationSeconds);
        __VestingWalletCliff_init(_cliffSeconds);

        token = IERC20(_token);
        votingEscrow = IVotingEscrow(_votingEscrow);
        grantManager = _grantManager;
    }

    /// @notice Converts token grant to a veNFT with lock time equal to the
    ///         remaining vesting schedule duration rounded down to the nearest
    ///         week. The operation is irreversible and takes the entire token
    ///         balance of TokenGrant. The function fails if the token balance
    ///         is zero. Only grant beneficiary can perform the conversion.
    ///         The function can be called more than one time if the TokenGrant
    ///         token balance increased after the previous conversion. For each
    ///         convert() call, a new veNFT is created. The veNFT will use the
    ///         same vesting schedule end, no matter when it is called.
    /// @return tokenId The token ID of the created veNFT
    function convert() external returns (uint256 tokenId) {
        if (msg.sender != beneficiary()) {
            revert NotBeneficiary();
        }

        // Note we take the current balance of TokenGrant so nothing stops the
        // grantee for converting at any moment, even after they withdrawn
        // some portion of tokens from TokenGrant. This is fine.
        uint256 amount = token.balanceOf(address(this));
        if (amount == 0) {
            revert EmptyGrant();
        }

        token.forceApprove(address(votingEscrow), amount);
        tokenId = votingEscrow.createGrantLockFor(
                amount,
                beneficiary(),
                grantManager,
                end()
            );

        emit Converted(tokenId, amount);
    }
}
