// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.24;

import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";

import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract VotingEscrow is IVotingEscrow, IERC6372, ERC2771Context, ReentrancyGuard {}
