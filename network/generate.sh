#!/usr/bin/env bash
set -euo pipefail
export FABRIC_CFG_PATH=$PWD
export PATH=$PATH:$(cd .. && pwd)/bin

# Source environment variables if not set
if [ -z "${SYS_CHANNEL:-}" ]; then
  if [ -f ../.env ]; then
    echo "Sourcing environment variables from ../.env"
    source ../.env
  else
    echo "Using default system channel: system-channel"
    SYS_CHANNEL=system-channel
  fi
fi

if [ -z "${APP_CHANNEL:-}" ]; then
  APP_CHANNEL=supplychain
fi

# Clean previous material
rm -rf crypto-config genesis.block channel.tx *.pb

echo "→ Generating crypto material"
cryptogen generate --config=crypto-config.yaml

echo "→ Generating system-channel genesis block"
configtxgen -profile FourOrgsOrdererGenesis \
            -channelID ${SYS_CHANNEL} \
            -outputBlock genesis.block

echo "→ Generating application-channel create-tx"
configtxgen -profile FourOrgsChannel \
            -channelID ${APP_CHANNEL} \
            -outputCreateChannelTx channel.tx
echo "✔ Done"