package main

import (
	"encoding/json"
	"fmt"
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

	callerMSP, _ := ctx.GetClientIdentity().GetMSPID()
	if callerMSP != "ManufacturerMSP" { // only manufacturer starts the flow
		return fmt.Errorf("caller MSP %s not permitted", callerMSP)
	}
	exists, _ := s.shipmentExists(ctx, id)
	if exists {
		return fmt.Errorf("shipment %s already exists", id)
	}
	ship := Shipment{
		ID:          id,
		OwnerMSP:    callerMSP,
		Origin:      origin,
		Destination: destination,
		Status:      StatusCreated,
		LastUpdate:  time.Now(),
	}
	bytes, _ := json.Marshal(ship)
	return ctx.GetStub().PutState(id, bytes)
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

	bytes, err := ctx.GetStub().GetState(id)
	if err != nil || bytes == nil {
		return nil, fmt.Errorf("shipment %s not found", id)
	}
	var ship Shipment
	_ = json.Unmarshal(bytes, &ship)
	return &ship, nil
}

func (s *SmartContract) GetAllShipments(ctx contractapi.TransactionContextInterface) ([]*Shipment, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var shipments []*Shipment
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var ship Shipment
		err = json.Unmarshal(queryResponse.Value, &ship)
		if err != nil {
			return nil, err
		}
		shipments = append(shipments, &ship)
	}

	return shipments, nil
}

func (s *SmartContract) shipmentExists(ctx contractapi.TransactionContextInterface,
	id string) (bool, error) {

	bytes, err := ctx.GetStub().GetState(id)
	return bytes != nil, err
}

/*  ───────  main  ───────  */
func main() {
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