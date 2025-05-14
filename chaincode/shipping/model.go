package main

import "time"

// Canonical shipment statuses
const (
	StatusCreated     = "CREATED"
	StatusPickedUp    = "PICKED_UP"
	StatusInTransit   = "IN_TRANSIT"
	StatusDelivered   = "DELIVERED"
	StatusException   = "EXCEPTION"
)

type Shipment struct {
	ID          string    `json:"id"`
	OwnerMSP    string    `json:"owner_msp"`
	Origin      string    `json:"origin"`
	Destination string    `json:"destination"`
	Status      string    `json:"status"`
	LastUpdate  time.Time `json:"last_update"`
	DocsHash    string    `json:"docs_hash"` // Required by schema validation
}