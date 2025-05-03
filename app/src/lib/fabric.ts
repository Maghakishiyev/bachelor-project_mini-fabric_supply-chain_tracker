import 'server-only';
import { Gateway, Identity, Signer, connect } from '@hyperledger/fabric-gateway';
import * as grpc from '@grpc/grpc-js';
import * as crypto from 'crypto';
import * as fs from 'fs/promises';
import * as path from 'path';

// Cache for gRPC connections to avoid creating new ones for each request
const connectionCache: Record<string, grpc.Client> = {};

export async function getGateway(): Promise<{ gw: Gateway; contract: any }> {
  try {
    // Environment variables for connection
    const mspId = process.env.MSP_ID!;
    const channelName = process.env.CHANNEL_NAME || 'supplychain';
    const chaincodeName = process.env.CHAINCODE_NAME || 'shipping';
    const peerEndpoint = process.env.PEER_ENDPOINT!;
    const cryptoPath = process.env.CRYPTO_PATH!;

    // Read crypto materials
    const certPath = path.join(cryptoPath, 'admin-cert.pem');
    const keyPath = path.join(cryptoPath, 'admin-key.pem');
    const tlsPath = path.join(cryptoPath, 'ca.pem');

    const cert = await fs.readFile(certPath);
    const key = await fs.readFile(keyPath);
    const tlsRootCert = await fs.readFile(tlsPath);

    // Create identity and signer
    const identity: Identity = {
      mspId,
      credentials: cert,
    };

    const privateKey = crypto.createPrivateKey(key);
    
    // Create a signer function that matches the Signer type
    const signer: Signer = async (digest: Uint8Array): Promise<Uint8Array> => {
      return crypto.sign(null, Buffer.from(digest), privateKey);
    };

    // Get or create gRPC connection
    let client = connectionCache[peerEndpoint];
    if (!client) {
      const tlsCredentials = grpc.credentials.createSsl(tlsRootCert);
      client = new grpc.Client(peerEndpoint, tlsCredentials, {});
      connectionCache[peerEndpoint] = client;
    }

    // Connect to gateway
    const gw = connect({
      client,
      identity,
      signer,
      evaluateOptions: () => {
        return { deadline: Date.now() + 5000 }; // 5 seconds
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

    // Get the contract
    const network = gw.getNetwork(channelName);
    const contract = network.getContract(chaincodeName);

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
      const result = await contract.evaluateTransaction('GetAllShipments');
      return JSON.parse(result.toString());
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