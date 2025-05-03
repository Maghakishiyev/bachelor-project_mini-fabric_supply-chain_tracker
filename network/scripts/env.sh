#!/usr/bin/env bash
# Usage:  source env.sh manufacturer  OR  env transporter

ORG=$1
if [ -z "$ORG" ]; then
    echo "Usage: source env.sh <organization>"
    echo "       where <organization> is one of: manufacturer, transporter, warehouse, retailer"
    return 1
fi

export ORDERER_CA=$PWD/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

case $ORG in
  manufacturer)
    export CORE_PEER_LOCALMSPID=ManufacturerMSP
    export CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051
    export CORE_PEER_MSPCONFIGPATH=$PWD/crypto-config/peerOrganizations/manufacturer.example.com/users/Admin@manufacturer.example.com/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/crypto-config/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt
    ;;
    
  transporter)
    export CORE_PEER_LOCALMSPID=TransporterMSP
    export CORE_PEER_ADDRESS=peer0.transporter.example.com:8051
    export CORE_PEER_MSPCONFIGPATH=$PWD/crypto-config/peerOrganizations/transporter.example.com/users/Admin@transporter.example.com/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/crypto-config/peerOrganizations/transporter.example.com/peers/peer0.transporter.example.com/tls/ca.crt
    ;;
    
  warehouse)
    export CORE_PEER_LOCALMSPID=WarehouseMSP
    export CORE_PEER_ADDRESS=peer0.warehouse.example.com:9051
    export CORE_PEER_MSPCONFIGPATH=$PWD/crypto-config/peerOrganizations/warehouse.example.com/users/Admin@warehouse.example.com/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/crypto-config/peerOrganizations/warehouse.example.com/peers/peer0.warehouse.example.com/tls/ca.crt
    ;;
    
  retailer)
    export CORE_PEER_LOCALMSPID=RetailerMSP
    export CORE_PEER_ADDRESS=peer0.retailer.example.com:10051
    export CORE_PEER_MSPCONFIGPATH=$PWD/crypto-config/peerOrganizations/retailer.example.com/users/Admin@retailer.example.com/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/crypto-config/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt
    ;;
    
  *)
    echo "Unknown organization: $ORG"
    echo "Usage: source env.sh <organization>"
    echo "       where <organization> is one of: manufacturer, transporter, warehouse, retailer"
    return 1
    ;;
esac

# Common settings for all organizations
export FABRIC_CFG_PATH=$PWD
export CORE_PEER_TLS_ENABLED=true

echo "Peer environment configured for $ORG organization"