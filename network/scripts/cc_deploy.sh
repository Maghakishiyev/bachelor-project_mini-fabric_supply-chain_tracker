#!/usr/bin/env bash
set -euo pipefail

# Source environment variables if not set
if [ -z "${APP_CHANNEL:-}" ]; then
  if [ -f ../.env ]; then
    echo "Sourcing environment variables from ../.env"
    source ../.env
  else
    echo "Using default values"
    export APP_CHANNEL=supplychain
  fi
fi

CC_NAME=${CHAINCODE_NAME:-shipping}
CC_VERSION=1.0
CC_LABEL=${CC_NAME}_${CC_VERSION}
CC_PATH=../../chaincode/shipping # relative to network directory

# 1. Package chaincode
echo "→ Packaging chain-code"
peer lifecycle chaincode package ${CC_LABEL}.tar.gz \
     --path ${CC_PATH} \
     --lang golang --label ${CC_LABEL}

# 2. Install on each peer
for ORG in manufacturer transporter warehouse retailer; do
  echo "→ Installing on $ORG"
  source ./scripts/env.sh $ORG
  peer lifecycle chaincode install ${CC_LABEL}.tar.gz
done

# 3. Query package-ID (needed for approval)
source ./scripts/env.sh manufacturer
export PACKAGE_ID=$(peer lifecycle chaincode queryinstalled | \
     grep ${CC_LABEL} | awk -F '[, ]+' '{print $3}')
echo "→ Package ID: $PACKAGE_ID"

# 4. Approve from each org
for ORG in manufacturer transporter warehouse retailer; do
  echo "→ Approving from $ORG"
  source ./scripts/env.sh $ORG
  peer lifecycle chaincode approveformyorg \
     -o orderer.example.com:7050 \
     --channelID ${APP_CHANNEL} --name ${CC_NAME} \
     --version ${CC_VERSION} --package-id ${PACKAGE_ID} \
     --sequence 1 --tls --cafile ${ORDERER_CA}
done

# 5. Check commit readiness
echo "→ Checking commit readiness"
peer lifecycle chaincode checkcommitreadiness \
     --channelID ${APP_CHANNEL} --name ${CC_NAME} \
     --version ${CC_VERSION} --sequence 1 \
     --output json

# 6. Commit (only once, from manufacturer peer)
echo "→ Committing chaincode definition"
source ./scripts/env.sh manufacturer
peer lifecycle chaincode commit \
     -o orderer.example.com:7050 \
     --channelID ${APP_CHANNEL} --name ${CC_NAME} --version ${CC_VERSION} \
     --sequence 1 --tls --cafile ${ORDERER_CA} \
     --peerAddresses peer0.manufacturer.example.com:7051 --tlsRootCertFiles ${PWD}/crypto-config/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt \
     --peerAddresses peer0.transporter.example.com:8051 --tlsRootCertFiles ${PWD}/crypto-config/peerOrganizations/transporter.example.com/peers/peer0.transporter.example.com/tls/ca.crt \
     --peerAddresses peer0.warehouse.example.com:9051 --tlsRootCertFiles ${PWD}/crypto-config/peerOrganizations/warehouse.example.com/peers/peer0.warehouse.example.com/tls/ca.crt \
     --peerAddresses peer0.retailer.example.com:10051 --tlsRootCertFiles ${PWD}/crypto-config/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt

# 7. Query committed chaincode
echo "→ Querying committed chaincode"
peer lifecycle chaincode querycommitted \
     --channelID ${APP_CHANNEL} --name ${CC_NAME}

echo "✅ Chain-code '${CC_NAME}' successfully deployed to channel '${APP_CHANNEL}'"