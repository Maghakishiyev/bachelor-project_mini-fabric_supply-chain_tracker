package main

import (
	"encoding/json"
	"testing"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"github.com/hyperledger/fabric-chaincode-go/shimtest"
	"github.com/stretchr/testify/assert"
)

func TestHappyPath(t *testing.T) {
	cc, _ := contractapi.NewChaincode(&SmartContract{})
	stub := shimtest.NewMockStub("shipping", cc)
	stub.MockInvoke("1", [][]byte{[]byte("CreateShipment"), []byte("SHIP1"), []byte("Warsaw"), []byte("Berlin")})
	
	resp := stub.MockInvoke("2", [][]byte{[]byte("QueryShipment"), []byte("SHIP1")})
	assert.Equal(t, int32(200), resp.Status, "query should succeed")
	
	var ship Shipment
	err := json.Unmarshal(resp.Payload, &ship)
	assert.NoError(t, err)
	assert.Equal(t, "SHIP1", ship.ID)
	assert.Equal(t, "Warsaw", ship.Origin)
	assert.Equal(t, "Berlin", ship.Destination)
	assert.Equal(t, StatusCreated, ship.Status)
	
	// Test update status
	resp = stub.MockInvoke("3", [][]byte{[]byte("UpdateStatus"), []byte("SHIP1"), []byte(StatusInTransit)})
	assert.Equal(t, int32(200), resp.Status, "update should succeed")
	
	resp = stub.MockInvoke("4", [][]byte{[]byte("QueryShipment"), []byte("SHIP1")})
	err = json.Unmarshal(resp.Payload, &ship)
	assert.NoError(t, err)
	assert.Equal(t, StatusInTransit, ship.Status)
}

func TestCreateShipmentAlreadyExists(t *testing.T) {
	cc, _ := contractapi.NewChaincode(&SmartContract{})
	stub := shimtest.NewMockStub("shipping", cc)
	
	// Create a shipment
	resp := stub.MockInvoke("1", [][]byte{[]byte("CreateShipment"), []byte("SHIP2"), []byte("Paris"), []byte("London")})
	assert.Equal(t, int32(200), resp.Status, "create should succeed")
	
	// Try to create with the same ID
	resp = stub.MockInvoke("2", [][]byte{[]byte("CreateShipment"), []byte("SHIP2"), []byte("Madrid"), []byte("Rome")})
	assert.Equal(t, int32(500), resp.Status, "duplicate create should fail")
}

func TestGetAllShipments(t *testing.T) {
	cc, _ := contractapi.NewChaincode(&SmartContract{})
	stub := shimtest.NewMockStub("shipping", cc)
	
	// Create multiple shipments
	stub.MockInvoke("1", [][]byte{[]byte("CreateShipment"), []byte("SHIP3"), []byte("Tokyo"), []byte("Seoul")})
	stub.MockInvoke("2", [][]byte{[]byte("CreateShipment"), []byte("SHIP4"), []byte("Sydney"), []byte("Melbourne")})
	
	// Get all shipments
	resp := stub.MockInvoke("3", [][]byte{[]byte("GetAllShipments")})
	assert.Equal(t, int32(200), resp.Status, "get all should succeed")
	
	var shipments []*Shipment
	err := json.Unmarshal(resp.Payload, &shipments)
	assert.NoError(t, err)
	assert.GreaterOrEqual(t, len(shipments), 2, "should have at least 2 shipments")
}