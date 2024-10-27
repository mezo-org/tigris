// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.19;

import {IVoter} from "./interfaces/IVoter.sol";

import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Voter is IVoter, ERC2771Context, ReentrancyGuard {}
