import { HardhatUserConfig } from "hardhat/config"
import "@keep-network/hardhat-helpers"
import "@nomicfoundation/hardhat-toolbox"
import "@nomicfoundation/hardhat-chai-matchers"
import "@openzeppelin/hardhat-upgrades"
import "hardhat-deploy"
import "hardhat-contract-sizer"
import "hardhat-gas-reporter"
import "@tenderly/hardhat-tenderly"

import dotenv from "dotenv-safer"

dotenv.config({
  allowEmptyValues: true,
  example: process.env.CI ? ".env.ci.example" : ".env.example",
})

const MATSNET_PRIVATE_KEY = process.env.MATSNET_PRIVATE_KEY
  ? [process.env.MATSNET_PRIVATE_KEY]
  : []

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100,
      },
    },
  },
  typechain: {
    outDir: "typechain",
  },
  networks: {
    matsnet: {
      url: "https://rpc.test.mezo.org",
      chainId: 31611,
      accounts: MATSNET_PRIVATE_KEY,
    },
  },
  external: {
    deployments: {
      matsnet: ["./external/matsnet"],
    },
  },
  namedAccounts: {
    deployer: 0,
    governance: {
      default: 0,
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
  tenderly: {
    username: "thesis",
    project: "",
  },
}

export default config
