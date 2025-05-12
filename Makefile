export FABRIC_VERSION := 2.5.8
export SYS_CHANNEL ?= system-channel
export APP_CHANNEL ?= supplychain
export CHAINCODE_NAME ?= shipping
export PATH := $(shell pwd)/bin:$(PATH)

# Default values for load testing
export RATE ?= 20
export SECONDS ?= 300

.PHONY: generate network-up network-down channel-create channel-join clean cc-vendor cc-package cc-install cc-approve cc-commit cc-deploy cc-test wallets logs all listener-up app-up loadtest metrics video monitoring monitoring-down full-stack

# Generate crypto material
generate:
	@cd network && ./generate.sh
	@echo "Crypto material generated"

# Start the Fabric network
network-up:
	@echo "Starting Fabric network..."
	@docker-compose up -d --build orderer.example.com \
		peer0.manufacturer.example.com peer0.transporter.example.com \
		peer0.warehouse.example.com peer0.retailer.example.com \
		cli
	@echo "Fabric network started"

# Stop and remove containers
network-down:
	@echo "Stopping Fabric network..."
	@docker-compose down -v
	@echo "Fabric network stopped"

# Create application channel
channel-create:
	@echo "Creating channel: $(APP_CHANNEL)"
	@docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt" \
		cli peer channel create -o orderer.example.com:7050 \
		-c $(APP_CHANNEL) -f /opt/gopath/src/github.com/hyperledger/fabric/peer/configtx/channel.tx \
		--outputBlock /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$(APP_CHANNEL).block \
		--tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Join peers to the channel
channel-join:
	@echo "Joining peers to channel: $(APP_CHANNEL)"
	@echo "Attempting to join peer0.manufacturer.example.com..."
	@for i in {1..5}; do \
		docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
			-e "CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051" \
			-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt" \
			-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/users/Admin@manufacturer.example.com/msp" \
			-e "CORE_PEER_TLS_ENABLED=true" \
			cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$(APP_CHANNEL).block && break || { \
			echo "Attempt $$i failed. Retrying in 2 seconds..."; \
			sleep 2; \
		}; \
	done
	
	@echo "Attempting to join peer0.transporter.example.com..."
	@for i in {1..5}; do \
		docker exec -e "CORE_PEER_LOCALMSPID=TransporterMSP" \
			-e "CORE_PEER_ADDRESS=peer0.transporter.example.com:8051" \
			-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/transporter.example.com/peers/peer0.transporter.example.com/tls/ca.crt" \
			-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/transporter.example.com/users/Admin@transporter.example.com/msp" \
			-e "CORE_PEER_TLS_ENABLED=true" \
			cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$(APP_CHANNEL).block && break || { \
			echo "Attempt $$i failed. Retrying in 2 seconds..."; \
			sleep 2; \
		}; \
	done
	
	@echo "Attempting to join peer0.warehouse.example.com..."
	@for i in {1..5}; do \
		docker exec -e "CORE_PEER_LOCALMSPID=WarehouseMSP" \
			-e "CORE_PEER_ADDRESS=peer0.warehouse.example.com:9051" \
			-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.example.com/peers/peer0.warehouse.example.com/tls/ca.crt" \
			-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.example.com/users/Admin@warehouse.example.com/msp" \
			-e "CORE_PEER_TLS_ENABLED=true" \
			cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$(APP_CHANNEL).block && break || { \
			echo "Attempt $$i failed. Retrying in 2 seconds..."; \
			sleep 2; \
		}; \
	done
	
	@echo "Attempting to join peer0.retailer.example.com..."
	@for i in {1..5}; do \
		docker exec -e "CORE_PEER_LOCALMSPID=RetailerMSP" \
			-e "CORE_PEER_ADDRESS=peer0.retailer.example.com:10051" \
			-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt" \
			-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/users/Admin@retailer.example.com/msp" \
			-e "CORE_PEER_TLS_ENABLED=true" \
			cli peer channel join -b /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/$(APP_CHANNEL).block && break || { \
			echo "Attempt $$i failed. Retrying in 2 seconds..."; \
			sleep 2; \
		}; \
	done
	@echo "All peers have joined the channel"

# Run chaincode unit tests
cc-test:
	@echo "Running chaincode unit tests..."
	@cd chaincode/shipping && go test -v
	@echo "Chaincode tests completed"

# Vendor chaincode dependencies
cc-vendor:
	@echo "Vendoring chaincode dependencies on host..."
	@cd chaincode/shipping && go mod tidy && go mod vendor

# Package chaincode
cc-package:
	@echo "Vendoring + packaging chaincode: $(CHAINCODE_NAME)"
	@$(MAKE) cc-vendor
	@docker exec cli peer lifecycle chaincode package /opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz \
		--path /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode/$(CHAINCODE_NAME) \
		--lang golang --label $(CHAINCODE_NAME)_1.0

# Install chaincode on all peers
cc-install:
	@echo "Installing chaincode on all peers..."
	@docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz
	
	@docker exec -e "CORE_PEER_LOCALMSPID=TransporterMSP" \
		-e "CORE_PEER_ADDRESS=peer0.transporter.example.com:8051" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz
	
	@docker exec -e "CORE_PEER_LOCALMSPID=WarehouseMSP" \
		-e "CORE_PEER_ADDRESS=peer0.warehouse.example.com:9051" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz
	
	@docker exec -e "CORE_PEER_LOCALMSPID=RetailerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.retailer.example.com:10051" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz

# Approve chaincode by all organizations
cc-approve:
	@echo "Approving chaincode for all organizations..."
	@PACKAGE_ID=$$(docker exec cli peer lifecycle chaincode queryinstalled | grep "$(CHAINCODE_NAME)_1.0" | awk '{print $$3}' | sed 's/,//') && \
	docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051" \
		cli peer lifecycle chaincode approveformyorg \
		--channelID $(APP_CHANNEL) --name $(CHAINCODE_NAME) --version 1.0 --package-id $$PACKAGE_ID \
		--sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
	
	@PACKAGE_ID=$$(docker exec cli peer lifecycle chaincode queryinstalled | grep "$(CHAINCODE_NAME)_1.0" | awk '{print $$3}' | sed 's/,//') && \
	docker exec -e "CORE_PEER_LOCALMSPID=TransporterMSP" \
		-e "CORE_PEER_ADDRESS=peer0.transporter.example.com:8051" \
		cli peer lifecycle chaincode approveformyorg \
		--channelID $(APP_CHANNEL) --name $(CHAINCODE_NAME) --version 1.0 --package-id $$PACKAGE_ID \
		--sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
	
	@PACKAGE_ID=$$(docker exec cli peer lifecycle chaincode queryinstalled | grep "$(CHAINCODE_NAME)_1.0" | awk '{print $$3}' | sed 's/,//') && \
	docker exec -e "CORE_PEER_LOCALMSPID=WarehouseMSP" \
		-e "CORE_PEER_ADDRESS=peer0.warehouse.example.com:9051" \
		cli peer lifecycle chaincode approveformyorg \
		--channelID $(APP_CHANNEL) --name $(CHAINCODE_NAME) --version 1.0 --package-id $$PACKAGE_ID \
		--sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
	
	@PACKAGE_ID=$$(docker exec cli peer lifecycle chaincode queryinstalled | grep "$(CHAINCODE_NAME)_1.0" | awk '{print $$3}' | sed 's/,//') && \
	docker exec -e "CORE_PEER_LOCALMSPID=RetailerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.retailer.example.com:10051" \
		cli peer lifecycle chaincode approveformyorg \
		--channelID $(APP_CHANNEL) --name $(CHAINCODE_NAME) --version 1.0 --package-id $$PACKAGE_ID \
		--sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Commit chaincode definition
cc-commit:
	@echo "Committing chaincode definition..."
	@docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051" \
		cli peer lifecycle chaincode commit \
		--channelID $(APP_CHANNEL) --name $(CHAINCODE_NAME) --version 1.0 \
		--sequence 1 \
		--tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
		--peerAddresses peer0.manufacturer.example.com:7051 \
		--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt \
		--peerAddresses peer0.transporter.example.com:8051 \
		--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/transporter.example.com/peers/peer0.transporter.example.com/tls/ca.crt \
		--peerAddresses peer0.warehouse.example.com:9051 \
		--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.example.com/peers/peer0.warehouse.example.com/tls/ca.crt \
		--peerAddresses peer0.retailer.example.com:10051 \
		--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt

# Chaincode deployment (package, install, approve, commit)
cc-deploy: cc-package cc-install cc-approve cc-commit

# Create test shipment
cc-test-invoke:
	@echo "Creating test shipment..."
	@docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt" \
		cli peer chaincode invoke -o orderer.example.com:7050 \
		--tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
		-C $(APP_CHANNEL) -n $(CHAINCODE_NAME) \
		--peerAddresses peer0.manufacturer.example.com:7051 \
		--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt \
		-c '{"function":"CreateShipment","Args":["SHIP001", "Warsaw", "Berlin"]}'
	@echo "Test shipment created"

# Query test shipment
cc-test-query:
	@echo "Querying test shipment..."
	@docker exec -e "CORE_PEER_LOCALMSPID=RetailerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.retailer.example.com:10051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt" \
		cli peer chaincode query -C $(APP_CHANNEL) -n $(CHAINCODE_NAME) \
		-c '{"function":"QueryShipment","Args":["SHIP001"]}'

# Prepare wallet files for all organizations
wallets:
	@echo "Preparing wallet files..."
	@cd network && ./scripts/prepare_wallets.sh
	@echo "Wallet files prepared"

# Clean up
clean:
	@echo "Cleaning up..."
	@docker-compose down -v
	@rm -rf network/crypto-config
	@rm -f network/genesis.block network/channel.tx network/*.pb
	@rm -rf network/wallets/*
	@echo "Cleanup complete"

# Show logs
logs:
	@docker-compose logs -f

# Test deployed chaincode
test: cc-test-invoke cc-test-query

# Start the event listener service
listener-up:
	@echo "Starting event listener service..."
	@docker-compose up -d listener
	@echo "Event listener service started"

# Start the frontend application
app-up:
	@echo "Starting frontend application..."
	@docker-compose up -d app
	@echo "Frontend application started"

# Full setup
all: generate network-up 
	@sleep 45
	@$(MAKE) channel-create
	@sleep 10
	@$(MAKE) channel-join
	@$(MAKE) cc-deploy
	@$(MAKE) wallets
	@$(MAKE) listener-up
	@$(MAKE) app-up

# ============ NEW TARGETS FOR PART 4 ============

# Run load testing with transaction generator
loadtest:
	@echo "▶ running generator ($(RATE) tx/s for $(SECONDS)s)"
	@mkdir -p docs
	@cd app && RATE=$(RATE) SECONDS=$(SECONDS) node -r ts-node/register ../scripts/loadtest/gen.ts \
		| tee ../docs/run.raw.json

# Process metrics and generate visualizations
metrics: loadtest
	@mkdir -p docs
	@cat docs/run.raw.json | python scripts/analyse/parse_logs.py
	@python scripts/analyse/plot.py
	@echo "CSV → docs/tps_latency.csv  |  PNG → docs/tps_latency.png"

# Run k6 load test (optional)
k6-test:
	@echo "▶ running k6 load test"
	@docker run --network host --rm -v $(PWD):/scripts grafana/k6:latest run /scripts/loadtest/k6.js

# Video demo placeholder command
video:
	@echo "🎥  Record with OBS → docs/demo.mp4"
	@echo "Please record a demonstration video of your supply chain system"
	@echo "Save it as docs/demo.mp4"

# Start Prometheus and Grafana for monitoring
monitoring:
	@echo "Starting monitoring stack..."
	@docker-compose -f monitoring/docker-compose.yml up -d
	@echo "Monitoring stack started"
	@echo "Grafana: http://localhost:3002 (admin/admin)"
	@echo "Prometheus: http://localhost:9090"

# Stop monitoring stack
monitoring-down:
	@echo "Stopping monitoring stack..."
	@docker-compose -f monitoring/docker-compose.yml down -v
	@echo "Monitoring stack stopped"

# Start the full stack with one command
full-stack:
	@echo "Starting complete supply chain system..."
	@docker-compose -f docker-compose.full.yml up -d --build
	@echo "Supply chain system started"
	@echo "Frontend: http://localhost:3000"
	@echo "Event WebSocket: ws://localhost:3001/ws"
	@echo "Grafana: http://localhost:3002 (admin/admin)"