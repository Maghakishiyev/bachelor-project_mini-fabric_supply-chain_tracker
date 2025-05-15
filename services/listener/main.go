package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

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
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return fallback
}

func main() {
	// 1) Bootstrap Gateway
	mspID := getEnvOr("MSP_ID", "ManufacturerMSP")
	certPath := getEnvOr("CERT_PATH", "/crypto/signcerts/Admin@manufacturer.example.com-cert.pem")
	keyPath := getEnvOr("KEY_PATH", "/crypto/keystore/priv_sk")
	peerURL := getEnvOr("PEER_ENDPOINT", "peer0.manufacturer.example.com:7051")
	tlsCAPath := getEnvOr("TLS_CA", "/crypto/ca.pem")

	log.Printf("Listener starting (MSP=%s, peer=%s)", mspID, peerURL)
	caPEM, err := os.ReadFile(tlsCAPath)
	if err != nil {
		log.Fatalf("read TLS CA: %v", err)
	}
	gw := newGateway(mspID, certPath, keyPath, peerURL, caPEM)
	defer gw.Close()
	network := gw.GetNetwork(channelName)

	// 2) WebSocket endpoint
	hub := NewHub()
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Printf("ws upgrade: %v", err)
			return
		}
		hub.Add(conn)
		log.Println("WS client connected")
		defer func() {
			hub.Remove(conn)
			conn.Close()
			log.Println("WS client disconnected")
		}()
		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				return
			}
		}
	})
	go func() {
		addr := ":" + wsPort
		log.Printf("WS listening on %s", addr)
		log.Fatal(http.ListenAndServe(addr, nil))
	}()

	// 3) Graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigs
		log.Println("shutting down")
		cancel()
	}()

	// 4) Subscribe to chaincode events, not block events
	events, err := network.ChaincodeEvents(ctx, ccName)
	if err != nil {
		log.Fatalf("failed to register for chaincode events: %v", err)
	}
	log.Println("listening for chaincode events…")

	for {
		select {
		case <-ctx.Done():
			return
		case ccEvent, ok := <-events:
			if !ok {
				return
			}
			// ccEvent.Payload is exactly what your chaincode emitted via SetEvent()
			// Forward it straight to all WS clients.
			envelope := struct {
				TxID    string          `json:"txId"`
				Name    string          `json:"eventName"`
				Payload json.RawMessage `json:"payload"`
				Block   uint64          `json:"blockNumber"`
			}{
				TxID:    ccEvent.TransactionID,
				Name:    ccEvent.EventName,
				Payload: ccEvent.Payload,
				Block:   ccEvent.BlockNumber,
			}
			b, _ := json.Marshal(envelope)
			hub.Broadcast(b)
		}
	}
}
