import { Address } from "viem"

const abi = [
  {
    inputs: [],
    name: "updatePeriod",
    outputs: [
      {
        internalType: "uint256",
        name: "period",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const

const mainnetAddress: Address = "0xcb79aE130b0777993263D0cdb7890e6D9baBE117"
const testnetAddress: Address = "0x63aD4D014246eaD52408dF3BC8F046107cbf6065"

export default {
  abi,
  address: { mainnet: mainnetAddress, testnet: testnetAddress },
}
