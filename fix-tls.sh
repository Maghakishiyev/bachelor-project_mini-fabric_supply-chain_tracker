#!/bin/bash
set -e

# This script modifies the core.yaml inside the peer container to enable TLS

for peer in peer0.manufacturer.example.com peer0.transporter.example.com peer0.warehouse.example.com peer0.retailer.example.com
do
  echo "Fixing TLS configuration for $peer..."
  # Create a sed script to inject the right TLS settings
  docker exec $peer /bin/sh -c "sed -i 's/enabled:  false/enabled:  true/g' /var/hyperledger/fabric/config/core.yaml"
  # Verify the change
  docker exec $peer /bin/sh -c "grep -A3 'tls:' /var/hyperledger/fabric/config/core.yaml"
done

echo "TLS configuration fixed for all peers."