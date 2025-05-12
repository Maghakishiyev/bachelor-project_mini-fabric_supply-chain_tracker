package main

import (
	"fmt"
	"os"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func NewChaincodeServer() (*shim.ChaincodeServer, error) {
	// Create a new chaincode implementation
	cc, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		return nil, fmt.Errorf("failed to create chaincode: %v", err)
	}

	// Get chaincode server config from environment variables
	address := os.Getenv("CHAINCODE_SERVER_ADDRESS")
	if address == "" {
		address = "0.0.0.0:9999" // default
	}

	chaincodeID := os.Getenv("CHAINCODE_ID")
	if chaincodeID == "" {
		return nil, fmt.Errorf("CHAINCODE_ID must be specified")
	}

	// Create the chaincode server
	server := &shim.ChaincodeServer{
		CCID:    chaincodeID,
		Address: address,
		CC:      cc,
		TLSProps: shim.TLSProperties{
			Disabled: true, // No TLS for this example
		},
	}

	return server, nil
}