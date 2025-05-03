#!/bin/bash
set -e

# Source .env file if it exists
if [ -f ./.env ]; then
    source ./.env
fi

# Set default values if not set in .env
FABRIC_VERSION=${FABRIC_VERSION:-3.1.0}
CA_VERSION=${CA_VERSION:-1.5.15}

echo "Downloading Hyperledger Fabric binaries version: ${FABRIC_VERSION}"
echo "Downloading Hyperledger Fabric CA version: ${CA_VERSION}"

# Create a temporary directory
mkdir -p ./tmp

# Download the Fabric binaries
curl -sSL https://github.com/hyperledger/fabric/releases/download/v${FABRIC_VERSION}/hyperledger-fabric-${FABRIC_VERSION}.tar.gz | tar xz -C ./tmp

# Check if binaries were downloaded
if [ ! -d "./tmp/bin" ]; then
    echo "Error: Failed to download Fabric binaries"
    exit 1
fi

# Move binaries to /usr/local/bin
sudo mv ./tmp/bin/* /usr/local/bin/

# Clean up
rm -rf ./tmp

# Add to PATH
echo "export PATH=\$PATH:/usr/local/bin" >> ~/.bash_profile
echo "export PATH=\$PATH:/usr/local/bin" >> ~/.zshrc

# Check installation
echo "Installation complete. Verifying binaries:"
peer version
configtxgen --version
cryptogen --version

echo "Hyperledger Fabric binaries have been installed successfully!"
echo "Please restart your terminal or run 'source ~/.bash_profile' (or ~/.zshrc) to update your PATH."