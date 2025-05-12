package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gorilla/websocket"
)

var (
	channelName = "supplychain"
	ccName      = "shipping"
	wsPort      = getEnvOr("WS_PORT", "3001")
	upgrader    = websocket.Upgrader{
		ReadBufferSize:  1024,
		WriteBufferSize: 1024,
		CheckOrigin:     func(r *http.Request) bool { return true },
	}
)

func getEnvOr(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}

func main() {
	// Get environment variables
	mspID := getEnvOr("MSP_ID", "ManufacturerMSP")
	certPath := getEnvOr("CERT_PATH", "/crypto/admin-cert.pem")
	keyPath := getEnvOr("KEY_PATH", "/crypto/admin-key.pem")
	peerURL := getEnvOr("PEER_ENDPOINT", "peer0.manufacturer.example.com:7051")
	tlsCAPath := getEnvOr("TLS_CA", "/crypto/ca.pem")
	
	log.Printf("Starting blockchain event listener with MSP ID: %s, connecting to: %s", mspID, peerURL)
	
	// Read TLS CA certificate
	caPEM, err := os.ReadFile(tlsCAPath)
	if err != nil {
		log.Fatalf("Failed to read TLS CA certificate: %v", err)
	}

	// Create gateway connection
	gw := newGateway(mspID, certPath, keyPath, peerURL, caPEM)
	defer gw.Close()
	
	// Get network
	network := gw.GetNetwork(channelName)
	
	// Create WebSocket hub
	hub := NewHub()
	
	// Setup WebSocket handler
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("WebSocket upgrade failed: %v", err)
			return
		}
		
		log.Println("Client connected to WebSocket")
		hub.Add(conn)
		
		// Handle disconnection
		defer func() {
			hub.Remove(conn)
			conn.Close()
			log.Println("Client disconnected from WebSocket")
		}()
		
		// Keep the connection alive
		for {
			_, _, err := conn.ReadMessage()
			if err != nil {
				break
			}
		}
	})
	
	// Start HTTP server for WebSocket
	go func() {
		addr := "0.0.0.0:" + wsPort
		log.Printf("WebSocket server listening on %s", addr)
		if err := http.ListenAndServe(addr, nil); err != nil {
			log.Fatalf("Failed to start WebSocket server: %v", err)
		}
	}()
	
	// Setup graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	// Handle OS signals
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		log.Println("Received shutdown signal")
		cancel()
	}()
	
	// Register for block events
	log.Println("Listening for block events...")
	events, err := network.BlockEvents(ctx)
	if err != nil {
		log.Fatalf("Failed to register for block events: %v", err)
	}
	
	// Process block events
	for {
		select {
		case <-ctx.Done():
			log.Println("Shutting down")
			return
		case event, ok := <-events:
			if !ok {
				log.Println("Event channel closed")
				return
			}
			
			// Convert block event to JSON
			blockData, err := json.Marshal(event)
			if err != nil {
				log.Printf("Failed to marshal block: %v", err)
				continue
			}
			
			// Log block number
			blockNum := event.GetHeader().GetNumber()
			log.Printf("Received block #%d - broadcasting to %d clients", blockNum, len(hub.clients))
			
			// Broadcast to all WebSocket clients
			hub.Broadcast(blockData)
			
			// Small delay to prevent CPU hogging
			time.Sleep(10 * time.Millisecond)
		}
	}
}