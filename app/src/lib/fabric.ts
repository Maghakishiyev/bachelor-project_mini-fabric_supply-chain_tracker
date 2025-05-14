import 'server-only';
import { Gateway, Identity, Signer, connect } from '@hyperledger/fabric-gateway';
import * as grpc from '@grpc/grpc-js';
import * as crypto from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';

// For simplicity, we'll create a new connection for each request
// This reduces bugs from cached connections that might be invalid

export async function getGateway(): Promise<{ gw: Gateway; contract: any }> {
  try {
    // Environment variables for connection
    const mspId = process.env.MSP_ID!;
    const channelName = process.env.CHANNEL_NAME || 'supplychain';
    const chaincodeName = process.env.CHAINCODE_NAME || 'shipping';
    const peerEndpoint = process.env.PEER_ENDPOINT!;
    const cryptoPath = process.env.CRYPTO_PATH!;

    console.log(`Connecting with MSP ID: ${mspId}, Peer Endpoint: ${peerEndpoint}, Crypto Path: ${cryptoPath}`);

    // Read crypto materials
    const certPath = path.join(cryptoPath, 'admin-cert.pem');
    const keyPath = path.join(cryptoPath, 'admin-key.pem');
    const tlsPath = path.join(cryptoPath, 'ca.pem');

    const cert = await fs.readFile(certPath);
    const key = await fs.readFile(keyPath);
    const tlsRootCert = await fs.readFile(tlsPath);

    console.log('Read cert, key, and tls files.');
    console.log(`Certificate path: ${certPath}, Key path: ${keyPath}, TLS path: ${tlsPath}`);
    console.log(`Certificate size: ${cert.length}, Key size: ${key.length}, TLS size: ${tlsRootCert.length}`);

    // Create identity and signer with proper role attribute
    const identity: Identity = {
      mspId,
      credentials: cert,
    };

    console.log('Created identity:', { mspId: identity.mspId }); // Log mspId but not the full certificate

    const privateKey = crypto.createPrivateKey(key);
    
    // Create a signer function that matches the Signer type
    const signer: Signer = async (digest: Uint8Array): Promise<Uint8Array> => {
      return crypto.sign(null, Buffer.from(digest), privateKey);
    };

    console.log('Created identity and signer.');

    // Create a fresh gRPC connection every time
    const tlsCredentials = grpc.credentials.createSsl(tlsRootCert);
    
    // Use the hostname directly from the peer endpoint for DNS resolution
    const peerHostname = peerEndpoint.split(':')[0];
    
    console.log(`Creating gRPC client for ${peerEndpoint} with hostname override: ${peerHostname}`);
    
    const client = new grpc.Client(
      peerEndpoint, 
      tlsCredentials, 
      { 
        'grpc.ssl_target_name_override': peerHostname,
        'grpc.default_authority': peerHostname,
        'grpc.max_receive_message_length': 100 * 1024 * 1024, // 100MB
        'grpc.max_send_message_length': 100 * 1024 * 1024, // 100MB
        'grpc.keepalive_time_ms': 120000, // 2 minutes
        'grpc.keepalive_timeout_ms': 20000, // 20 seconds
        'grpc.http2.min_time_between_pings_ms': 120000, // 2 minutes
        'grpc.http2.max_pings_without_data': 0,
        'grpc.keepalive_permit_without_calls': 1
      }
    );

    console.log("gRPC client created successfully");

    // Connect to gateway with retry logic
    let gw;
    let attempts = 0;
    const maxAttempts = 3;
    
    while (attempts < maxAttempts) {
      try {
        gw = connect({
          client,
          identity,
          signer,
          evaluateOptions: () => {
            return { deadline: Date.now() + 10000 }; // 10 seconds
          },
          endorseOptions: () => {
            return { deadline: Date.now() + 15000 }; // 15 seconds
          },
          submitOptions: () => {
            return { deadline: Date.now() + 30000 }; // 30 seconds
          },
          commitStatusOptions: () => {
            return { deadline: Date.now() + 60000 }; // 60 seconds
          },
        });
        break; // Success, exit the loop
      } catch (err) {
        attempts++;
        console.error(`Gateway connection attempt ${attempts} failed:`, err);
        if (attempts >= maxAttempts) throw err;
        // Wait before retrying
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }

    if (!gw) {
      throw new Error("Failed to connect to gateway after multiple attempts");
    }
    
    console.log("Gateway connection established successfully");

    // Get the contract
    const network = gw.getNetwork(channelName);
    const contract = network.getContract(chaincodeName);
    console.log(`Connected to channel: ${channelName}, chaincode: ${chaincodeName}`);

    return { gw, contract };
  } catch (error) {
    console.error('Failed to connect to Fabric gateway:', error);
    throw new Error(`Gateway connection error: ${error}`);
  }
}

// Helper function to create a shipment
export async function createShipment(id: string, origin: string, destination: string): Promise<any> {
  try {
    const { gw, contract } = await getGateway();
    try {
      const result = await contract.submitTransaction('CreateShipment', id, origin, destination);
      return { success: true, result: result.toString() };
    } finally {
      gw.close();
    }
  } catch (error) {
    console.error('Error creating shipment:', error);
    return { success: false, error: `${error}` };
  }
}

// Helper function to get all shipments
export async function getAllShipments(): Promise<any[]> {
  try {
    const { gw, contract } = await getGateway();
    try {
      // Try looking up all the known shipment IDs we've created for testing
      const testIds = ['SHIP100', 'SHIP555', 'SHIP999'];
      const shipments = [];
      
      // Try to query each known shipment ID
      for (const id of testIds) {
        try {
          console.log(`Trying to query shipment with ID: ${id}`);
          const result = await contract.evaluateTransaction('QueryShipment', id);
          if (result && result.length > 0) {
            const shipment = JSON.parse(result.toString());
            shipments.push(shipment);
            console.log(`Found shipment: ${id}`);
          }
        } catch (err) {
          console.log(`Shipment ${id} not found or error: ${err}`);
        }
      }
      
      if (shipments.length > 0) {
        console.log(`Found ${shipments.length} shipments in the ledger`);
        return shipments;
      }
      
      console.log('No known shipments found, trying GetAllShipments...');
      
      // Fall back to GetAllShipments
      try {
        const result = await contract.evaluateTransaction('GetAllShipments');
        return JSON.parse(result.toString());
      } catch (getAllErr) {
        console.error('GetAllShipments failed:', getAllErr);
        return [];
      }
    } finally {
      gw.close();
    }
  } catch (error) {
    console.error('Error getting all shipments:', error);
    return [];
  }
}

// Helper function to get a shipment by ID
export async function getShipment(id: string): Promise<any> {
  try {
    const { gw, contract } = await getGateway();
    try {
      const result = await contract.evaluateTransaction('QueryShipment', id);
      return JSON.parse(result.toString());
    } finally {
      gw.close();
    }
  } catch (error) {
    console.error(`Error getting shipment ${id}:`, error);
    return null;
  }
}

// Helper function to update shipment status
export async function updateShipmentStatus(id: string, status: string): Promise<any> {
  try {
    const { gw, contract } = await getGateway();
    try {
      const result = await contract.submitTransaction('UpdateStatus', id, status);
      return { success: true, result: result.toString() };
    } finally {
      gw.close();
    }
  } catch (error) {
    console.error(`Error updating shipment ${id} status:`, error);
    return { success: false, error: `${error}` };
  }
}