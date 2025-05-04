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
curl -sSL https://github.com/hyperledger/fabric/releases/download/v${FABRIC_VERSION}/hyperledger-fabric-darwin-amd64-${FABRIC_VERSION}.tar.gz | tar xz -C ./tmp

# Check if binaries were downloaded
if [ ! -d "./tmp/bin" ]; then
    echo "Error: Failed to download Fabric binaries"
    exit 1
fi

# Create local bin directory
mkdir -p bin

# Move binaries to local bin directory
cp ./tmp/bin/* ./bin/

# Clean up
rm -rf ./tmp

# Add to PATH (optional)
echo "Binaries placed in ./bin directory"

# Check installation
echo "Installation complete. Binaries available in ./bin directory:"
ls -la ./bin/
echo "Please add $(pwd)/bin to your PATH"

echo "Hyperledger Fabric binaries have been installed successfully!"
echo "Please restart your terminal or run 'source ~/.bash_profile' (or ~/.zshrc) to update your PATH."