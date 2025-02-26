#!/bin/bash

HH_NODE_HOSTNAME=localhost
HH_NODE_PORT=8545
# This mnemonic is used by Hardhat node to generate accounts for the Hardhat network.
HH_MNEMONIC="test test test test test test test test test test test junk"
HH_ACCOUNTS_COUNT=20

npx hardhat node \
  --hostname $HH_NODE_HOSTNAME \
  --port $HH_NODE_PORT \
  &

function cleanup {
  # Kill HH node by port as killing by PID just kills the npx process
  # and leaves the underlying node intact.
  kill $(lsof -t -i:$HH_NODE_PORT)
  echo "hardhat node shut down"
}

trap cleanup EXIT

sleep 10

FOUNDRY_PROFILE=system-test \
  FORK_RPC_URL=http://$HH_NODE_HOSTNAME:$HH_NODE_PORT \
  DEPLOYMENT_ARTIFACTS=deployments/localhost \
  MNEMONIC=$HH_MNEMONIC \
  ACCOUNTS_COUNT=$HH_ACCOUNTS_COUNT \
  forge test -vvv
