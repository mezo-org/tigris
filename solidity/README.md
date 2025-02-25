\_\_# Mezodrome Contracts

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
