# RFC-1: Using veBTC as mUSD collateral

## Background

Holders of liquid BTC have two primary paths to utilize it on the Mezo chain:

- Lock BTC in a veBTC NFT to participate in [Tigris], the incentive system for Mezo.
  Holders of veBTC receive voting power and earn rewards and fee shares.
- Use BTC as collateral to borrow the [mUSD] stablecoin.

Currently, these paths are mutually exclusive, forcing holders to choose between them.
This RFC proposes a solution to combine both options by enabling the use of veBTC as collateral for mUSD.

### Current functionality

#### veBTC overview

To lock BTC in a veBTC NFT, users must call the `createLock` function on the [VeBTC] contract.
The underlying BTC is locked for a specified duration, and the lock creator receives ownership of the
newly minted veBTC NFT.

The veBTC owner has the following capabilities:

- Voting:
  - Vote on swap pool gauges
  - Vote on the [ChainFeeSplitter]'s needle parameter, which determines
    how BTC rewards are distributed between pool gauges and veBTC holders
- Earning:
  - Earn a proportional share of swap fees from pools they voted for
  - Receive a portion of BTC rewards specifically allocated to veBTC holders
- Management:
  - Extend the lock duration
  - Increase the amount of locked BTC
  - Transfer veBTC ownership to another address
  - Withdraw the underlying BTC after the lock expires

The veBTC owner cannot access or use the underlying locked BTC in any way, as it remains fully controlled
by the veBTC contract until the lock expires.

#### mUSD overview

To borrow mUSD against BTC, users must call the `openTrove` function on the [BorrowerOperations] contract.
Since the function is `payable`, users need to include the appropriate amount of liquid BTC with their transaction.
Upon execution, the BTC is transferred to the [ActivePool] contract as collateral, mUSD is minted,
and the caller becomes the borrower controlling the newly opened trove. Each borrower is limited to one active trove at a time.

The trove owner has the following capabilities:

- Borrow additional mUSD against their existing trove
- Add more BTC collateral to increase their collateral ratio
- Withdraw excess BTC collateral while maintaining required ratios
- Refinance their trove to align with the current global interest rate
- Close their trove by fully repaying the borrowed mUSD

Additionally, troves are subject to:

- Redemptions by other users
- Liquidation events resulting in collateral seizure

It's worth noting that all trove operations can be executed either through regular transactions or via gasless
EIP-712 signatures (implemented in the [BorrowerOperationsSignatures] contract).

The mUSD protocol is currently designed to only accept the chain's native token as collateral. On Mezo,
this means liquid BTC. The protocol does not support using other assets as collateral.

## Proposal

This RFC proposes a functionality that enables users to utilize veBTC as collateral for mUSD borrowing.
The solution preserves the voting and earning capabilities of veBTC owners while remaining transparent
to the mUSD protocol.

### Goal

The goal of this proposal is to eliminate the current trade-off where users must choose between locking
BTC for protocol governance and fees/rewards, or using it as collateral for mUSD loans. By enabling both
use cases simultaneously, users can maximize the utility and benefits of their BTC position.

### Implementation

_Under construction._

### Limitations

_Under construction._

## Related Links

- [Tigris]: The incentive system for Mezo.
- [mUSD]: The BTC-backed stablecoin on Mezo.
- [VeBTC]: The veBTC NFT contract.
- [ChainFeeSplitter]: Contract distributing BTC rewards between gauges and veBTC holders.
- [BorrowerOperations]: Contract managing mUSD borrows.
- [ActivePool]: Contract holding the BTC collateral of active troves.
- [BorrowerOperationsSignatures]: Contract managing gas-less EIP-712 signatures for borrower operations.

<!-- Links definitions -->

[Tigris]: https://blog.mezo.org/mezo-the-2025-roadmap/#3-tigris
[mUSD]: https://github.com/mezo-org/musd
[VeBTC]: https://github.com/mezo-org/mezodrome/blob/e5a24828e645474cb284a3f16c1272286f491bbc/solidity/contracts/VeBTC.sol
[ChainFeeSplitter]: https://github.com/mezo-org/mezodrome/blob/e5a24828e645474cb284a3f16c1272286f491bbc/solidity/contracts/ChainFeeSplitter.sol
[BorrowerOperations]: https://github.com/mezo-org/musd/blob/0c4b3e42c903e1a4602e473e6c1ddd446f20fc4e/solidity/contracts/BorrowerOperations.sol
[ActivePool]: https://github.com/mezo-org/musd/blob/0c4b3e42c903e1a4602e473e6c1ddd446f20fc4e/solidity/contracts/ActivePool.sol
[BorrowerOperationsSignatures]: https://github.com/mezo-org/musd/blob/0c4b3e42c903e1a4602e473e6c1ddd446f20fc4e/solidity/contracts/BorrowerOperationsSignatures.sol
