// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import {TokenGrant} from "./TokenGrant.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/// @title Token Grant Factory
/// @notice Factory for creating truly upgradable TokenGrant instances using beacon proxy pattern.
/// @dev All instances automatically use the new implementation when upgraded.
contract TokenGrantFactory is Ownable2StepUpgradeable {
    error ZeroAddress();

    event TokenGrantCreated(
        address indexed tokenGrant,
        address indexed beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffSeconds,
        bool isRevocable
    );

    event ImplementationUpgraded(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    /// @notice The beacon contract that holds the implementation address.
    UpgradeableBeacon public beacon;

    /// @notice The token to be vested.
    address public token;
    /// @notice The voting escrow contract for conversion.
    address public votingEscrow;
    /// @notice The address that can revoke the grant.
    address public grantManager;

    /// @notice Initializes the factory.
    /// @param _token The ERC20 token to be vested.
    /// @param _votingEscrow The voting escrow contract for conversion.
    /// @param _grantManager The address that can revoke the grant.
    /// @param _implementation The TokenGrant implementation contract address.
    function initialize(
        address _token,
        address _votingEscrow,
        address _grantManager,
        address _implementation
    ) public initializer {
        __Ownable2Step_init();
        __Ownable_init();

        if (_token == address(0)) revert ZeroAddress();
        if (_votingEscrow == address(0)) revert ZeroAddress();
        if (_grantManager == address(0)) revert ZeroAddress();
        if (_implementation == address(0)) revert ZeroAddress();

        token = _token;
        votingEscrow = _votingEscrow;
        grantManager = _grantManager;

        // Create beacon with initial implementation.
        beacon = new UpgradeableBeacon(_implementation);

        // Transfer beacon ownership to this contract so we can upgrade it.
        beacon.transferOwnership(address(this));
    }

    /// @notice Get the current implementation address from the beacon.
    function implementation() external view returns (address) {
        return beacon.implementation();
    }

    /// @notice Create a new TokenGrant instance.
    /// @param _beneficiary The address that will receive the vested tokens.
    /// @param _startTimestamp When the vesting starts.
    /// @param _durationSeconds Total vesting duration in seconds.
    /// @param _cliffSeconds Cliff period in seconds.
    /// @param _isRevocable Whether the grant can be revoked.
    /// @return grant The address of the created TokenGrant instance.
    function createGrant(
        address _beneficiary,
        uint64 _startTimestamp,
        uint64 _durationSeconds,
        uint64 _cliffSeconds,
        bool _isRevocable
    ) external returns (address grant) {
        if (_beneficiary == address(0)) revert ZeroAddress();

        // Create initialization data.
        bytes memory initData = abi.encodeWithSelector(
            TokenGrant.initialize.selector,
            token,
            votingEscrow,
            grantManager,
            _beneficiary,
            _startTimestamp,
            _durationSeconds,
            _cliffSeconds,
            _isRevocable
        );

        // Create beacon proxy instance.
        grant = address(new BeaconProxy(address(beacon), initData));

        emit TokenGrantCreated(
            grant,
            _beneficiary,
            _startTimestamp,
            _durationSeconds,
            _cliffSeconds,
            _isRevocable
        );
    }

    /// @notice Upgrade the implementation contract.
    /// @dev Only callable by owner. ALL existing grants will automatically use the new implementation.
    /// @param _newImplementation The address of the new implementation contract.
    function upgradeImplementation(
        address _newImplementation
    ) external onlyOwner {
        if (_newImplementation == address(0)) revert ZeroAddress();

        emit ImplementationUpgraded(
            beacon.implementation(),
            _newImplementation
        );

        beacon.upgradeTo(_newImplementation);
    }
}
