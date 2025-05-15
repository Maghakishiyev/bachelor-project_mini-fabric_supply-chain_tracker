package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// SmartContract fulfils ContractInterface
type SmartContract struct {
	contractapi.Contract
}

/*  ───────  create  ───────  */
func (s *SmartContract) CreateShipment(ctx contractapi.TransactionContextInterface,
	id, origin, destination string) error {

	callerMSP, err := ctx.GetClientIdentity().GetMSPID()
	log.Printf("CreateShipment called with id=%s, origin=%s, destination=%s from MSP: %s",
		id, origin, destination, callerMSP)

	if err != nil {
		log.Printf("Error getting MSP ID: %v", err)
		return fmt.Errorf("error getting caller MSP ID: %v", err)
	}

	if callerMSP != "ManufacturerMSP" { // only manufacturer starts the flow
		log.Printf("Access denied: caller MSP %s not permitted, only ManufacturerMSP allowed", callerMSP)
		return fmt.Errorf("caller MSP %s not permitted", callerMSP)
	}

	exists, err := s.shipmentExists(ctx, id)
	if err != nil {
		log.Printf("Error checking if shipment exists: %v", err)
		return fmt.Errorf("error checking if shipment exists: %v", err)
	}

	if exists {
		log.Printf("Shipment %s already exists", id)
		return fmt.Errorf("shipment %s already exists", id)
	}

	ship := Shipment{
		ID:          id,
		OwnerMSP:    callerMSP,
		Origin:      origin,
		Destination: destination,
		Status:      StatusCreated,
		LastUpdate:  time.Now(),
		DocsHash:    "", // Empty string but not omitted
	}

	bytes, err := json.Marshal(ship)
	if err != nil {
		log.Printf("Error marshaling shipment: %v", err)
		return fmt.Errorf("error marshaling shipment: %v", err)
	}

	err = ctx.GetStub().PutState(id, bytes)
	if err != nil {
		log.Printf("Error putting state: %v", err)
		return fmt.Errorf("error saving shipment: %v", err)
	}

	log.Printf("Successfully created shipment: %s", id)
	return nil
}

/*  ───────  update status  ───────  */
func (s *SmartContract) UpdateStatus(ctx contractapi.TransactionContextInterface,
	id, newStatus string) error {

	ship, err := s.QueryShipment(ctx, id)
	if err != nil {
		return err
	}
	if newStatus == "" {
		return fmt.Errorf("empty status")
	}
	ship.Status = newStatus
	ship.LastUpdate = time.Now()
	ship.OwnerMSP, _ = ctx.GetClientIdentity().GetMSPID() // transfer of custody
	bytes, _ := json.Marshal(ship)
	return ctx.GetStub().PutState(id, bytes)
}

/*  ───────  transfer ownership  ───────  */
func (s *SmartContract) TransferOwnership(ctx contractapi.TransactionContextInterface,
	id, newOwnerMSP string) error {

	ship, err := s.QueryShipment(ctx, id)
	if err != nil {
		return err
	}
	if newOwnerMSP == "" {
		return fmt.Errorf("empty owner MSP")
	}
	callerMSP, _ := ctx.GetClientIdentity().GetMSPID()
	if ship.OwnerMSP != callerMSP {
		return fmt.Errorf("caller %s is not current owner", callerMSP)
	}
	ship.OwnerMSP = newOwnerMSP
	ship.LastUpdate = time.Now()
	bytes, _ := json.Marshal(ship)
	return ctx.GetStub().PutState(id, bytes)
}

/*  ───────  query helpers  ───────  */
func (s *SmartContract) QueryShipment(ctx contractapi.TransactionContextInterface,
	id string) (*Shipment, error) {

	log.Printf("QueryShipment called for id=%s", id)

	callerMSP, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		log.Printf("Error getting MSP ID: %v", err)
	} else {
		log.Printf("QueryShipment called by org: %s", callerMSP)
	}

	bytes, err := ctx.GetStub().GetState(id)
	if err != nil {
		log.Printf("Error getting state for shipment %s: %v", id, err)
		return nil, fmt.Errorf("error getting shipment %s: %v", id, err)
	}

	if bytes == nil {
		log.Printf("Shipment %s not found (no data)", id)
		return nil, fmt.Errorf("shipment %s not found", id)
	}

	var ship Shipment
	err = json.Unmarshal(bytes, &ship)
	if err != nil {
		log.Printf("Error unmarshaling shipment %s: %v", id, err)
		return nil, fmt.Errorf("error unmarshaling shipment %s: %v", id, err)
	}

	log.Printf("Successfully queried shipment: %s", id)
	return &ship, nil
}

func (s *SmartContract) GetAllShipments(ctx contractapi.TransactionContextInterface) ([]*Shipment, error) {
	callerMSP, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		log.Printf("Error getting MSP ID in GetAllShipments: %v\n", err)
	} else {
		log.Printf("GetAllShipments called by org: %s\n", callerMSP)
	}

	// IMPORTANT: Explicitly allow access for all MSPs
	// There's no access control for this function - all organizations should be able to query all shipments
	log.Printf("GetAllShipments granted to organization: %s", callerMSP)

	// This function has no access control checks intentionally
	// If your MSP is still getting "access denied" errors, there may be an issue with:
	// 1. Certificate/identity configuration
	// 2. Channel ACL policies
	// 3. Endorsement policies at the chaincode level
	shipments := make([]*Shipment, 0)

	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("error querying all shipments: %v", err)
	}
	defer resultsIterator.Close()

	for resultsIterator.HasNext() {
		resp, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("error iterating through shipments: %v", err)
		}
		var ship Shipment
		if err := json.Unmarshal(resp.Value, &ship); err != nil {
			return nil, fmt.Errorf("error parsing shipment data: %v", err)
		}
		shipments = append(shipments, &ship)
	}

	// Now shipments is always a non-nil slice ([]*Shipment{}), even if zero-length
	log.Printf("GetAllShipments returning %d shipments\n", len(shipments))
	log.Print("Shipments", shipments)
	return shipments, nil
}

func (s *SmartContract) shipmentExists(ctx contractapi.TransactionContextInterface,
	id string) (bool, error) {

	bytes, err := ctx.GetStub().GetState(id)
	return bytes != nil, err
}

/*  ───────  main  ───────  */
func main() {
	// Force all output to stderr for Docker to capture
	// This ensures logs are captured by the Docker container
	log.SetOutput(os.Stderr)
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)

	// Write directly to stderr for immediate feedback
	os.Stderr.WriteString("===== CHAINCODE STARTING UP =====\n")
	log.Println("Chaincode starting up with verbose logging")

	// Enable debug and verbose mode
	debugMode := true

	// Check if we should run as a server (CCAAS mode)
	if os.Getenv("CHAINCODE_SERVER_ADDRESS") != "" {
		os.Stderr.WriteString("===== RUNNING IN CCAAS MODE =====\n")
		log.Println("Running in CCAAS mode")

		// Run as a chaincode service
		server, err := NewChaincodeServer()
		if err != nil {
			errorMsg := fmt.Sprintf("Error creating chaincode server: %s", err)
			os.Stderr.WriteString("ERROR: " + errorMsg + "\n")
			log.Printf(errorMsg)
			os.Exit(1)
		}

		log.Println("Starting chaincode server...")
		os.Stderr.WriteString("===== STARTING CHAINCODE SERVER =====\n")

		// Log configuration details for debugging
		if debugMode {
			log.Printf("Server config: ID=%s, Address=%s",
				os.Getenv("CORE_CHAINCODE_ID_NAME"),
				os.Getenv("CHAINCODE_SERVER_ADDRESS"))
		}

		if err := server.Start(); err != nil {
			errorMsg := fmt.Sprintf("Error starting chaincode server: %s", err)
			os.Stderr.WriteString("ERROR: " + errorMsg + "\n")
			log.Printf(errorMsg)
			os.Exit(1)
		}
	} else {
		os.Stderr.WriteString("===== RUNNING IN STANDARD MODE =====\n")
		log.Println("Running in standard chaincode mode")

		// Run as a normal chaincode
		cc, err := contractapi.NewChaincode(&SmartContract{})
		if err != nil {
			errorMsg := fmt.Sprintf("Error creating chaincode: %v", err)
			os.Stderr.WriteString("ERROR: " + errorMsg + "\n")
			log.Printf(errorMsg)
			os.Exit(1)
		}
		cc.Info.Version = "1.0"
		cc.Info.Title = "ShippingContract"
		cc.Info.Description = "Proof-of-concept supply-chain chain-code"

		log.Println("Starting chaincode in standard mode...")
		os.Stderr.WriteString("===== STARTING CHAINCODE IN STANDARD MODE =====\n")

		if err := cc.Start(); err != nil {
			errorMsg := fmt.Sprintf("Error starting chaincode: %v", err)
			os.Stderr.WriteString("ERROR: " + errorMsg + "\n")
			log.Printf(errorMsg)
			os.Exit(1)
		}
	}
}
