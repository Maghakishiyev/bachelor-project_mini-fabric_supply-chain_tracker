export FABRIC_VERSION := 2.5.8
export SYS_CHANNEL ?= system-channel
export APP_CHANNEL ?= supplychain
export CHAINCODE_NAME ?= shipping
export PATH := $(shell pwd)/bin:$(PATH)

# Default values for load testing
export RATE ?= 20
export SECONDS ?= 300

.PHONY: generate network-up network-down channel-create channel-join clean cc-vendor cc-package cc-install cc-approve cc-commit cc-deploy cc-test wallets logs all listener-up app-up loadtest metrics monitoring monitoring-down full-stack

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
		cli \
		prometheus grafana
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
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/users/Admin@manufacturer.example.com/msp" \
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
	@echo "Using external build for chaincode"
	@cd chaincode/shipping && tar -czf shipping.tar.gz --exclude=vendor --exclude=.git .
	@echo "Created external chaincode package at chaincode/shipping/shipping.tar.gz" 
	@docker cp chaincode/shipping/shipping.tar.gz cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz
	@docker exec cli peer lifecycle chaincode package /opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz \
		--path /opt/gopath/src/github.com/hyperledger/fabric/peer/chaincode/$(CHAINCODE_NAME) \
		--lang golang --label $(CHAINCODE_NAME)_1.0

# Install chaincode on all peers with external builder
cc-install:
	@echo "Installing chaincode on all peers..."
	@echo "Using external chaincode installation approach"
	@docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/users/Admin@manufacturer.example.com/msp" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz
	
	@docker exec -e "CORE_PEER_LOCALMSPID=TransporterMSP" \
		-e "CORE_PEER_ADDRESS=peer0.transporter.example.com:8051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/transporter.example.com/peers/peer0.transporter.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/transporter.example.com/users/Admin@transporter.example.com/msp" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz
	
	@docker exec -e "CORE_PEER_LOCALMSPID=WarehouseMSP" \
		-e "CORE_PEER_ADDRESS=peer0.warehouse.example.com:9051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.example.com/peers/peer0.warehouse.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.example.com/users/Admin@warehouse.example.com/msp" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/$(CHAINCODE_NAME).tar.gz
	
	@docker exec -e "CORE_PEER_LOCALMSPID=RetailerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.retailer.example.com:10051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/users/Admin@retailer.example.com/msp" \
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
		--tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt \
		--signature-policy "OR('ManufacturerMSP.member', 'TransporterMSP.member', 'WarehouseMSP.member', 'RetailerMSP.member')"

# Simple external chaincode deployment target
# Skipping the build/install process by using a pure external CCaaS approach
cc-deploy:
	@echo "Using pure CCaaS approach (external chaincode service)..."
	@mkdir -p /tmp/shipping_ccaas
	
	@echo "1. Creating CCaaS metadata.json and connection.json..."
	@echo '{"type":"ccaas","label":"shipping_1.0"}' > /tmp/shipping_ccaas/metadata.json
	@echo '{"address":"shipping-ccaas:9999","dial_timeout":"10s","tls_required":false}' > /tmp/shipping_ccaas/connection.json
	@cd /tmp/shipping_ccaas && tar czf code.tar.gz connection.json
	@cd /tmp/shipping_ccaas && tar czf shipping_1.0.tar.gz metadata.json code.tar.gz
	@docker cp /tmp/shipping_ccaas/shipping_1.0.tar.gz cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/shipping_1.0.tar.gz
	
	@echo "2. Installing CCaaS package on all peers..."
	@docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/users/Admin@manufacturer.example.com/msp" \
		-e "CORE_PEER_TLS_ENABLED=true" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/shipping_1.0.tar.gz
	
	@docker exec -e "CORE_PEER_LOCALMSPID=TransporterMSP" \
		-e "CORE_PEER_ADDRESS=peer0.transporter.example.com:8051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/transporter.example.com/peers/peer0.transporter.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/transporter.example.com/users/Admin@transporter.example.com/msp" \
		-e "CORE_PEER_TLS_ENABLED=true" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/shipping_1.0.tar.gz
	
	@docker exec -e "CORE_PEER_LOCALMSPID=WarehouseMSP" \
		-e "CORE_PEER_ADDRESS=peer0.warehouse.example.com:9051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.example.com/peers/peer0.warehouse.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.example.com/users/Admin@warehouse.example.com/msp" \
		-e "CORE_PEER_TLS_ENABLED=true" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/shipping_1.0.tar.gz
	
	@docker exec -e "CORE_PEER_LOCALMSPID=RetailerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.retailer.example.com:10051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/users/Admin@retailer.example.com/msp" \
		-e "CORE_PEER_TLS_ENABLED=true" \
		cli peer lifecycle chaincode install /opt/gopath/src/github.com/hyperledger/fabric/peer/shipping_1.0.tar.gz
	
	@echo "3. Getting packageID from queryinstalled..."
	@docker exec cli peer lifecycle chaincode queryinstalled > /tmp/shipping_ccaas/queryinstalled.txt
	@PKG_ID=$$(cat /tmp/shipping_ccaas/queryinstalled.txt | grep -o "shipping_1.0:[^,]*" | head -1); \
	echo "Package ID: $$PKG_ID"; \
	docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/users/Admin@manufacturer.example.com/msp" \
		-e "CORE_PEER_TLS_ENABLED=true" \
		cli peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 \
		--channelID $(APP_CHANNEL) --name $(CHAINCODE_NAME) --version 1.0 --package-id $$PKG_ID \
		--sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
	
	@echo "4. Approving for all other organizations..."
	@PKG_ID=$$(cat /tmp/shipping_ccaas/queryinstalled.txt | grep -o "shipping_1.0:[^,]*" | head -1); \
	docker exec -e "CORE_PEER_LOCALMSPID=TransporterMSP" \
		-e "CORE_PEER_ADDRESS=peer0.transporter.example.com:8051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/transporter.example.com/peers/peer0.transporter.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/transporter.example.com/users/Admin@transporter.example.com/msp" \
		-e "CORE_PEER_TLS_ENABLED=true" \
		cli peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 \
		--channelID $(APP_CHANNEL) --name $(CHAINCODE_NAME) --version 1.0 --package-id $$PKG_ID \
		--sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
	
	@PKG_ID=$$(cat /tmp/shipping_ccaas/queryinstalled.txt | grep -o "shipping_1.0:[^,]*" | head -1); \
	docker exec -e "CORE_PEER_LOCALMSPID=WarehouseMSP" \
		-e "CORE_PEER_ADDRESS=peer0.warehouse.example.com:9051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.example.com/peers/peer0.warehouse.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/warehouse.example.com/users/Admin@warehouse.example.com/msp" \
		-e "CORE_PEER_TLS_ENABLED=true" \
		cli peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 \
		--channelID $(APP_CHANNEL) --name $(CHAINCODE_NAME) --version 1.0 --package-id $$PKG_ID \
		--sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
	
	@PKG_ID=$$(cat /tmp/shipping_ccaas/queryinstalled.txt | grep -o "shipping_1.0:[^,]*" | head -1); \
	docker exec -e "CORE_PEER_LOCALMSPID=RetailerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.retailer.example.com:10051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/users/Admin@retailer.example.com/msp" \
		-e "CORE_PEER_TLS_ENABLED=true" \
		cli peer lifecycle chaincode approveformyorg -o orderer.example.com:7050 \
		--channelID $(APP_CHANNEL) --name $(CHAINCODE_NAME) --version 1.0 --package-id $$PKG_ID \
		--sequence 1 --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
	
	@echo "5. Committing chaincode definition..."
	@docker exec -e "CORE_PEER_LOCALMSPID=ManufacturerMSP" \
		-e "CORE_PEER_ADDRESS=peer0.manufacturer.example.com:7051" \
		-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls/ca.crt" \
		-e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/manufacturer.example.com/users/Admin@manufacturer.example.com/msp" \
		-e "CORE_PEER_TLS_ENABLED=true" \
		cli peer lifecycle chaincode commit -o orderer.example.com:7050 \
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
	
	@echo "6. Start chaincode server..."
	@docker run -d --name shipping-ccaas \
		-v $(PWD)/chaincode/shipping:/app \
		-e CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999 \
		-e CORE_CHAINCODE_ID_NAME=$$(cat /tmp/shipping_ccaas/queryinstalled.txt | grep -o "shipping_1.0:[^,]*" | head -1) \
		-p 9999:9999 \
		--network fabric_network \
		golang:1.24 /bin/bash -c "cd /app && go mod vendor && go build -o /app/chaincode && /app/chaincode"
	
	@echo "✅ External chaincode service started. Deployment complete!"

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
		-c '{"function":"CreateShipment","Args":["SHIP33", "Warsaw", "Berlin"]}'
	@echo "Test shipment created"

# Query test shipment
cc-test-query:
	@echo "Querying test shipment (as Retailer)..."
	@sleep 10
	@docker exec \
	  -e "CORE_PEER_LOCALMSPID=RetailerMSP" \
	  -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/users/Admin@retailer.example.com/msp" \
	  -e "CORE_PEER_ADDRESS=peer0.retailer.example.com:10051" \
	  -e "CORE_PEER_TLS_ENABLED=true" \
	  -e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt" \
	  cli peer chaincode query \
	    --tls \
	    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/retailer.example.com/peers/peer0.retailer.example.com/tls/ca.crt \
	    -C $(APP_CHANNEL) -n $(CHAINCODE_NAME) \
	    -c '{"function":"QueryShipment","Args":["SHIP33"]}'

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
	@sleep 10
	@docker cp network/crypto-config cli:/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto-config
	@$(MAKE) channel-create
	@sleep 10
	@$(MAKE) channel-join
	@$(MAKE) cc-deploy
	@$(MAKE) wallets
	@$(MAKE) listener-up
	@$(MAKE) app-up
	@$(MAKE) monitoring

# ============ NEW TARGETS FOR PART 4 ============

# Run load testing with transaction generator in Docker
loadtest:
	@echo "▶ running generator ($(RATE) tx/s for $(SECONDS)s)"
	@mkdir -p docs
	@echo "Building loadtest container..."
	@cd scripts/loadtest && docker build -t fabric-loadtest .
	@echo "Running load test..."
	@docker run --rm \
		--network=fabric_network \
		-v $(PWD)/network/wallets/manufacturer/admin:/crypto \
		-v $(PWD)/network/crypto-config/peerOrganizations/manufacturer.example.com/peers/peer0.manufacturer.example.com/tls:/tls \
		-e RATE=$(RATE) \
		-e SECONDS=$(SECONDS) \
		-e MSP_ID=ManufacturerMSP \
		-e PEER_ENDPOINT=peer0.manufacturer.example.com:7051 \
		-e CERT_PATH=/crypto/cert.pem \
		-e KEY_PATH=/crypto/key.pem \
		-e TLS_CERT_PATH=/tls/ca.crt \
		fabric-loadtest | tee docs/run.raw.json

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


# Start Prometheus and Grafana for monitoring
monitoring:
	@echo "Starting monitoring stack..."
	@docker-compose up -d prometheus grafana
	@echo "Monitoring stack started"
	@echo "Grafana: http://localhost:3002 (admin/admin)"
	@echo "Prometheus: http://localhost:9090"

# Stop monitoring stack
monitoring-down:
	@echo "Stopping monitoring stack..."
	@docker-compose stop prometheus grafana
	@echo "Monitoring stack stopped"
