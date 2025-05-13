import { HardhatUserConfig } from "hardhat/config"
import "@keep-network/hardhat-helpers"
import "@nomicfoundation/hardhat-toolbox"
import "@nomicfoundation/hardhat-chai-matchers"
// The @nomicfoundation/hardhat-foundry plugin provides the `hardhat init-foundry`
// command that was used to initialize foundry.toml. Moreover, this plugin
// allows Hardhat to use dependencies installed by Foundry (the `lib` directory)
// and understand Foundry dependency remappings. Last but not least, it lets
// Foundry use Hardhat dependencies from `node_modules`.
import "@nomicfoundation/hardhat-foundry"
import "@openzeppelin/hardhat-upgrades"
import "hardhat-deploy"
import "hardhat-contract-sizer"
import "hardhat-gas-reporter"

import dotenv from "dotenv-safer"

dotenv.config({
  allowEmptyValues: true,
  example: process.env.CI ? ".env.ci.example" : ".env.example",
})

const TESTNET_PRIVATE_KEY = process.env.TESTNET_PRIVATE_KEY
  ? [process.env.TESTNET_PRIVATE_KEY]
  : []

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100,
      },
      evmVersion: "london", // latest EVM version supported on Mezo is London
    },
  },
  typechain: {
    outDir: "typechain",
  },
  networks: {
    testnet: {
      url: "https://rpc.test.mezo.org",
      chainId: 31611,
      accounts: TESTNET_PRIVATE_KEY,
    },
  },
  external: {
    deployments: {
      testnet: ["./external/testnet"],
    },
  },
  etherscan: {
    apiKey: {
      testnet: "empty",
    },
    customChains: [
      {
        network: "testnet",
        chainId: 31611,
        urls: {
          apiURL: "https://api.explorer.test.mezo.org/api",
          browserURL: "https://explorer.test.mezo.org",
        },
      },
    ],
  },
  namedAccounts: {
    deployer: 0,
    governance: {
      default: 0,
      testnet: "0x6e80164ea60673d64d5d6228beb684a1274bb017", // testertesting.eth
      mainnet: "0x98d8899c3030741925be630c710a98b57f397c7a",
    },
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    strict: false,
  },
  gasReporter: {
    enabled: true,
  },
}

export default config
