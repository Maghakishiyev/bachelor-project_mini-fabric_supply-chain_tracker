package main

import (
	"fmt"
	"os"
	"strconv"

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

	chaincodeID := os.Getenv("CORE_CHAINCODE_ID_NAME")
	if chaincodeID == "" {
		return nil, fmt.Errorf("CORE_CHAINCODE_ID_NAME must be specified")
	}

	// Get TLS enabled flag
	tlsEnabled, _ := strconv.ParseBool(os.Getenv("CORE_PEER_TLS_ENABLED"))

	fmt.Printf("Starting chaincode server with ID: %s, address: %s, TLS: %v\n", 
		chaincodeID, address, tlsEnabled)

	// Create the chaincode server
	server := &shim.ChaincodeServer{
		CCID:    chaincodeID,
		Address: address,
		CC:      cc,
		TLSProps: shim.TLSProperties{
			Disabled: !tlsEnabled, // Disable TLS for development
		},
	}

	return server, nil
}