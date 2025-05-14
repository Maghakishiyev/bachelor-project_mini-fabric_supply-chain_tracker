package main

import (
	"encoding/json"
	"fmt"
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
	fmt.Printf("CreateShipment called with id=%s, origin=%s, destination=%s from MSP: %s\n", 
		id, origin, destination, callerMSP)
	
	if err != nil {
		fmt.Printf("Error getting MSP ID: %v\n", err)
		return fmt.Errorf("error getting caller MSP ID: %v", err)
	}
	
	if callerMSP != "ManufacturerMSP" { // only manufacturer starts the flow
		fmt.Printf("Access denied: caller MSP %s not permitted, only ManufacturerMSP allowed\n", callerMSP)
		return fmt.Errorf("caller MSP %s not permitted", callerMSP)
	}
	
	exists, err := s.shipmentExists(ctx, id)
	if err != nil {
		fmt.Printf("Error checking if shipment exists: %v\n", err)
		return fmt.Errorf("error checking if shipment exists: %v", err)
	}
	
	if exists {
		fmt.Printf("Shipment %s already exists\n", id)
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
		fmt.Printf("Error marshaling shipment: %v\n", err)
		return fmt.Errorf("error marshaling shipment: %v", err)
	}
	
	err = ctx.GetStub().PutState(id, bytes)
	if err != nil {
		fmt.Printf("Error putting state: %v\n", err)
		return fmt.Errorf("error saving shipment: %v", err)
	}
	
	fmt.Printf("Successfully created shipment: %s\n", id)
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

	fmt.Printf("QueryShipment called for id=%s\n", id)
	
	callerMSP, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		fmt.Printf("Error getting MSP ID: %v\n", err)
	} else {
		fmt.Printf("QueryShipment called by org: %s\n", callerMSP)
	}

	bytes, err := ctx.GetStub().GetState(id)
	if err != nil {
		fmt.Printf("Error getting state for shipment %s: %v\n", id, err)
		return nil, fmt.Errorf("error getting shipment %s: %v", id, err)
	}
	
	if bytes == nil {
		fmt.Printf("Shipment %s not found (no data)\n", id)
		return nil, fmt.Errorf("shipment %s not found", id)
	}
	
	var ship Shipment
	err = json.Unmarshal(bytes, &ship)
	if err != nil {
		fmt.Printf("Error unmarshaling shipment %s: %v\n", id, err)
		return nil, fmt.Errorf("error unmarshaling shipment %s: %v", id, err)
	}
	
	fmt.Printf("Successfully queried shipment: %s\n", id)
	return &ship, nil
}

func (s *SmartContract) GetAllShipments(ctx contractapi.TransactionContextInterface) ([]*Shipment, error) {
	callerMSP, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		fmt.Printf("Error getting MSP ID in GetAllShipments: %v\n", err)
	} else {
		fmt.Printf("GetAllShipments called by org: %s\n", callerMSP)
	}

	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		fmt.Printf("Error getting state by range: %v\n", err)
		return nil, fmt.Errorf("error querying all shipments: %v", err)
	}
	defer resultsIterator.Close()

	var shipments []*Shipment
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			fmt.Printf("Error getting next result: %v\n", err)
			return nil, fmt.Errorf("error iterating through shipments: %v", err)
		}

		var ship Shipment
		err = json.Unmarshal(queryResponse.Value, &ship)
		if err != nil {
			fmt.Printf("Error unmarshaling shipment: %v\n", err)
			return nil, fmt.Errorf("error parsing shipment data: %v", err)
		}
		shipments = append(shipments, &ship)
	}

	fmt.Printf("GetAllShipments returning %d shipments\n", len(shipments))
	return shipments, nil
}

func (s *SmartContract) shipmentExists(ctx contractapi.TransactionContextInterface,
	id string) (bool, error) {

	bytes, err := ctx.GetStub().GetState(id)
	return bytes != nil, err
}

/*  ───────  main  ───────  */
func main() {
	// Check if we should run as a server (CCAAS mode)
	if os.Getenv("CHAINCODE_SERVER_ADDRESS") != "" {
		// Run as a chaincode service
		server, err := NewChaincodeServer()
		if err != nil {
			fmt.Printf("Error creating chaincode server: %s", err)
			os.Exit(1)
		}
		
		fmt.Println("Starting chaincode server...")
		if err := server.Start(); err != nil {
			fmt.Printf("Error starting chaincode server: %s", err)
			os.Exit(1)
		}
	} else {
		// Run as a normal chaincode
		cc, err := contractapi.NewChaincode(&SmartContract{})
		if err != nil {
			panic(err)
		}
		cc.Info.Version = "1.0"
		cc.Info.Title = "ShippingContract"
		cc.Info.Description = "Proof-of-concept supply-chain chain-code"
		if err := cc.Start(); err != nil {
			panic(err)
		}
	}
}