# Troubleshooting Guide for Mini-Fabric Supply Chain Project

## Common Issues and Solutions

### 1. Listener Service Issues

**Problem:** Listener container exits with error:
```
failed to create private key sign: unsupported key type: []uint8
```

**Solution:**
This issue occurs with Fabric Gateway v1.7.1 due to a change in the API. Fix the `connect.go` file:

```go
// Before (problematic code):
sign, err := identity.NewPrivateKeySign(keyPem)
if err != nil {
    log.Fatalf("failed to create private key sign: %v", err)
}

// After (fixed code):
privateKey, err := identity.PrivateKeyFromPEM(keyPem)
if err != nil {
    log.Fatalf("failed to parse private key: %v", err)
}

sign, err := identity.NewPrivateKeySign(privateKey)
if err != nil {
    log.Fatalf("failed to create private key sign: %v", err)
}
```

### 2. Peer Configuration Issues

**Problem:** Peer container exits with error:
```
Fatal error when initializing core config : error when reading core config file: Config File "core" Not Found in "[/var/hyperledger/fabric/config]"
```

**Solution:**
1. Create a `core.yaml` file in your project's `network/config` directory
2. Add the volume mount in docker-compose.yml:
   ```yaml
   volumes:
     - ./network/config:/etc/hyperledger/fabric
   ```
3. Add FABRIC_CFG_PATH environment variable to the peer configuration:
   ```yaml
   environment:
     - FABRIC_CFG_PATH=/etc/hyperledger/fabric
   ```

### 3. Chaincode Deployment Issues

**Problem:** Docker socket connectivity issues when deploying chaincode:
```
Error: chaincode install failed with status: 500 - failed to invoke backing implementation of 'InstallChaincode': could not build chaincode: docker build failed: docker image inspection failed: Get "http://unix.sock/images/...": dial unix /var/run/docker.sock: connect: no such file or directory
```

**Solution:**
Switch to a CCaaS (Chaincode as a Service) approach instead of the traditional Docker build approach:

1. Create a `connection.json` file for your chaincode:
   ```json
   {
     "address": "shipping-ccaas:9999",
     "dial_timeout": "10s",
     "tls_required": false
   }
   ```

2. Update your chaincode's `metadata.json` to include the CCaaS type:
   ```json
   {
     "type": "ccaas",
     "label": "shipping_1.0",
     // Other fields...
   }
   ```

3. Add a shipping-ccaas service to your docker-compose.yml:
   ```yaml
   shipping-ccaas:
     container_name: shipping-ccaas
     image: golang:1.24
     working_dir: /chaincode
     command: bash -c "cd shipping && go build -o chaincode && CORE_CHAINCODE_ID_NAME=shipping:1.0 CORE_PEER_TLS_ENABLED=false ./chaincode -peer.address peer0.manufacturer.example.com:7052"
     ports:
       - "9999:9999"
     volumes:
       - ./chaincode:/chaincode
     environment:
       - CORE_CHAINCODE_ID_NAME=shipping:1.0
       - CORE_PEER_TLS_ENABLED=false
       - CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999
       - CHAINCODE_AS_A_SERVICE=true
   ```

4. Update your chaincode's main.go to detect CCaaS mode using environment variables:
   ```go
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
     // ...
   }
   ```

### 4. Channel Creation and Joining Issues

**Problem:** Channel creation or join commands fail with connection issues:
```
failed to create deliver client for orderer: orderer client failed to connect to orderer.example.com:7050: failed to create new connection: connection error: desc = "transport: error while dialing: dial tcp 172.18.0.6:7050: connect: connection refused
```

**Solution:**
1. Ensure the orderer container is fully started before creating the channel:
   ```bash
   # Wait for the orderer to start completely
   sleep 20 && make channel-create
   ```

2. Check that TLS settings are correct in all command paths:
   ```bash
   # When creating channel
   peer channel create -o orderer.example.com:7050 -c supplychain -f /path/to/channel.tx --tls --cafile $ORDERER_CA
   
   # When joining channel
   peer channel join -b supplychain.block
   ```

3. Verify that all necessary peers join the channel:
   ```bash
   # For each peer (Manufacturer, Transporter, Warehouse, Retailer)
   docker exec -e CORE_PEER_LOCALMSPID=OrganizationMSP \
     -e CORE_PEER_TLS_ROOTCERT_FILE=/path/to/ca.crt \
     -e CORE_PEER_MSPCONFIGPATH=/path/to/msp \
     -e CORE_PEER_ADDRESS=peer0.organization.example.com:port \
     cli peer channel join -b supplychain.block
   ```

## Best Practices

1. **Check Container Logs**: Always check container logs to understand what is failing:
   ```bash
   docker logs <container_name>
   ```

2. **Environment Variables**: Ensure consistent environment variables across all containers:
   ```bash
   docker exec <container_name> env | grep <variable_name>
   ```

3. **TLS Consistency**: Make sure TLS settings are consistent across all components:
   - If using TLS, set `CORE_PEER_TLS_ENABLED=true` everywhere
   - If not using TLS, set `CORE_PEER_TLS_ENABLED=false` everywhere

4. **Network Connectivity**: Check that containers can reach each other:
   ```bash
   docker exec <container_name> ping <other_container_name>
   ```

5. **Chaincode Testing**: Test chaincode with the CLI before involving the webapp:
   ```bash
   docker exec cli peer chaincode invoke -C supplychain -n shipping -c '{"Args":["CreateShipment","ID001","Origin","Destination"]}'
   docker exec cli peer chaincode query -C supplychain -n shipping -c '{"Args":["GetAllShipments"]}'
   ```

## Additional Resources

- [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
- [Fabric Gateway Documentation](https://github.com/hyperledger/fabric-gateway)
- [Chaincode as a Service Documentation](https://hyperledger-fabric.readthedocs.io/en/latest/cc_service.html)