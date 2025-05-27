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

| Name            | Address                                    |
| --------------- | ------------------------------------------ |
| Router          | 0x16A76d3cd3C1e3CE843C6680d6B37E9116b5C706 |
| PoolFactory     | 0x83FE469C636C4081b87bA5b3Ae9991c6Ed104248 |
| MUSD/BTC Pool   | 0x52e604c44417233b6CcEDDDc0d640A405Caacefb |
| MUSD/mUSDC Pool | 0xEd812AEc0Fecc8fD882Ac3eccC43f3aA80A6c356 |
| MUSD/mUSDT Pool | 0x10906a9E9215939561597b4C8e4b98F93c02031A |

### Testnet contracts

| Name            | Address                                    |
| --------------- | ------------------------------------------ |
| Router          | 0xBb9b1E617d739ec3034537A48f8cB62f80a181C5 |
| PoolFactory     | 0xc316C9D57ae0966E5155Bf03007464C3F88da4Fe |
| MUSD/BTC Pool   | 0x7e6d67fD714194127973B7eF4748868a90392916 |
| MUSD/mUSDC Pool | 0x19916204edb20A46209C7FbEA508CEb292939730 |
| MUSD/mUSDT Pool | 0xdE1172b6F39712FcecF17edEbE272828f8428c1a |
