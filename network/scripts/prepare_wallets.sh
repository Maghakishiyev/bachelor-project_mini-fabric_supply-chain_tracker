#!/usr/bin/env bash
set -euo pipefail

# This script extracts the admin certificates from the crypto-config directory
# and creates wallet files for each organization's admin user

# Create directories for wallet storage
mkdir -p wallets/{manufacturer,transporter,warehouse,retailer}/admin

# Function to copy admin credentials to wallet directory
prepare_wallet() {
  local ORG=$1
  echo "→ Preparing wallet for $ORG"
  
  # Copy MSP credentials to wallet
  cp -r crypto-config/peerOrganizations/${ORG}.example.com/users/Admin@${ORG}.example.com/msp/signcerts/* \
    wallets/${ORG}/admin/cert.pem
  
  cp -r crypto-config/peerOrganizations/${ORG}.example.com/users/Admin@${ORG}.example.com/msp/keystore/* \
    wallets/${ORG}/admin/key.pem
  
  # Create metadata file
  cat > wallets/${ORG}/admin/metadata.json << EOF
{
  "version": 1,
  "mspId": "$(echo ${ORG} | sed 's/.*/\u&/')MSP",
  "type": "X.509",
  "label": "admin"
}
EOF
  echo "✅ Wallet for $ORG prepared"
}

# Prepare wallets for all organizations
for ORG in manufacturer transporter warehouse retailer; do
  prepare_wallet $ORG
done

echo "✅ All wallets prepared successfully"