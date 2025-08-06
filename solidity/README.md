# Tigris Contracts

Smart contracts powering the Mezo gauge system and DEX, inspired by Solidly.

## Development

### Installation

This project uses [pnpm](https://pnpm.io/) as a package manager ([installation documentation](https://pnpm.io/installation)).

To install dependencies run:

```bash
pnpm install
```

Install slither locally

```bash
brew install slither
```

Install Foundry locally by following [this guide](https://book.getfoundry.sh/getting-started/installation).
See the [Hardhat and Foundry](#hardhat-and-foundry-) section for more information.

### Testing

```
$ pnpm test
```

```
slither .
```

### Environment Setup

This project uses [dotenv-safer](https://github.com/vincentvella/dotenv-safer),
which provides environment variable checking. If there is a field in
`.env.example` but not `.env`, execution will halt early with an error.

Both `pnpm run deploy` and `pnpm test` will automatically create a blank `.env`
from the `.env.example` template, if `.env` does not exist.

To do this manually:

```
$ pnpm run prepare:env
```

### Deploying

We deploy our contracts with
[hardhat-deploy](https://www.npmjs.com/package/hardhat-deploy) via

```
$ pnpm run deploy [--network <network>]
```

Check the `"networks"` entry of `hardhat.config.ts` for supported networks.

Deploying to real chains will require configuring the `.env` environment,
detailed in `.env.example`.

#### Examples:

**In-Memory Hardhat** (great for development)

```
pnpm run deploy
```

**Sepolia**

To deploy contracts on Sepolia run:

```
$ pnpm run deploy --network sepolia
```

Or, alternatively, manually trigger the [`Solidity`
workflow](https://github.com/thesis/mezo-portal/actions/workflows/solidity.yml)
(this will not only deploy the contracts, but also update the values of
`TBTC_CONTRACT_ADDRESS`, `WBTC_CONTRACT_ADDRESS` and `PORTAL_CONTRACT_ADDRESS`
environment variables in the settings of Netlify builds deploying dApp and its
previews).

### Hardhat and Foundry

We use a hybrid approach with both Hardhat and Foundry for this project.

Hardhat is considered the project's main build tool. It is used to compile and
deploy contracts. Hardhat deployment scripts are the main deployment mechanism
for real chains.

Foundry is used as test platform. Unit tests are written and run entirely using
Foundry. System tests are written using Foundry but run in fork mode against
a Hardhat network with deployment scripts applied.

Note that Foundry test runner expects specific compilation artifacts so Foundry
is used to compile contracts for this concrete use case instead of Hardhat.

## Contract Addresses

Here are the addresses of the most important contracts on Mezo mainnet and testnet.
For the full list of deployed contracts, see the [deployments](./deployments) directory.

### Mainnet contracts

| Name                    | Address                                    |
| ----------------------- | ------------------------------------------ |
| Router                  | 0x16A76d3cd3C1e3CE843C6680d6B37E9116b5C706 |
| PoolFactory             | 0x83FE469C636C4081b87bA5b3Ae9991c6Ed104248 |
| MUSD/BTC Pool           | 0x52e604c44417233b6CcEDDDc0d640A405Caacefb |
| MUSD/mUSDC Pool         | 0xEd812AEc0Fecc8fD882Ac3eccC43f3aA80A6c356 |
| MUSD/mUSDT Pool         | 0x10906a9E9215939561597b4C8e4b98F93c02031A |
| VeBTC                   | 0x7D807e9CE1ef73048FEe9A4214e75e894ea25914 |
| VeBTCVoter              | 0x3A4a6919F70e5b0aA32401747C471eCfe2322C1b |
| VeBTCRewardsDistributor | 0x535E01F948458E0b64F9dB2A01Da6F32E240140f |
| VeBTCEpochGovernor      | 0x1494102fa1b240c3844f02e0810002125fb5F054 |
| ChainFeeSplitter        | 0xcb79aE130b0777993263D0cdb7890e6D9baBE117 |

### Testnet contracts

| Name                    | Address                                    |
| ----------------------- | ------------------------------------------ |
| Router                  | 0x9a1ff7FE3a0F69959A3fBa1F1e5ee18e1A9CD7E9 |
| PoolFactory             | 0x4947243CC818b627A5D06d14C4eCe7398A23Ce1A |
| MUSD/BTC Pool           | 0xd16A5Df82120ED8D626a1a15232bFcE2366d6AA9 |
| MUSD/mUSDC Pool         | 0x525F049A4494dA0a6c87E3C4df55f9929765Dc3e |
| MUSD/mUSDT Pool         | 0x27414B76CF00E24ed087adb56E26bAeEEe93494e |
| VeBTC                   | 0xB63fcCd03521Cf21907627bd7fA465C129479231 |
| VeBTCVoter              | 0x72F8dd7F44fFa19E45955aa20A5486E8EB255738 |
| VeBTCRewardsDistributor | 0x10B0E7b3411F4A38ca2F6BB697aA28D607924729 |
| VeBTCEpochGovernor      | 0x12fda93041aD8aB6d133aE4d038b5159033d937a |
| ChainFeeSplitter        | 0x63aD4D014246eaD52408dF3BC8F046107cbf6065 |
