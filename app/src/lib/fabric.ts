// app/src/lib/fabric.ts
import fs from 'fs';
import path from 'path';
import { createPrivateKey, KeyObject } from 'crypto';
import { credentials, ChannelCredentials, Client } from '@grpc/grpc-js';
import {
    connect,
    Gateway,
    Identity,
    Signer,
    Contract,
    signers,
} from '@hyperledger/fabric-gateway';

//
// Load all connection settings from env
//
const mspId = process.env.MSP_ID!; // e.g. "ManufacturerMSP"
const peerEndpoint = process.env.PEER_ENDPOINT!; // e.g. "peer0.manufacturer.example.com:7051"
const channelName = process.env.CHANNEL_NAME!; // e.g. "supplychain"
const chaincodeName = process.env.CHAINCODE_NAME!; // e.g. "shipping"
const cryptoPath = process.env.CRYPTO_PATH!; // e.g. "/crypto"

//
// Build a new Gateway + Contract for each call
//
function newGateway(): { gw: Gateway; contract: Contract } {
    // 1. Read TLS cert for the peer's CA
    const caPem = fs.readFileSync(path.join(cryptoPath, 'ca.pem'));
    // 2. Read our client identity cert + private key
    const certPem = fs.readFileSync(path.join(cryptoPath, 'admin-cert.pem'));
    const keyPem = fs.readFileSync(path.join(cryptoPath, 'admin-key.pem'));
    // 3. Create Identity object
    const identity: Identity = { mspId, credentials: certPem };
    // 4. Convert PEM → KeyObject for signer
    const privateKey: KeyObject = createPrivateKey({
        key: keyPem,
        format: 'pem',
    });
    const signer: Signer = signers.newPrivateKeySigner(privateKey);
    // 5. Build gRPC client with SSL
    const tlsCreds: ChannelCredentials = credentials.createSsl(caPem);
    const client = new Client(peerEndpoint, tlsCreds);
    // 6. Connect to the Gateway
    const gw = connect({ client, identity, signer });
    // 7. Grab our network & contract
    const network = gw.getNetwork(channelName);
    const contract = network.getContract(chaincodeName);
    return { gw, contract };
}

//
// Create a new shipment
//
export async function createShipment(
    id: string,
    origin: string,
    destination: string
): Promise<
    { success: true; result: string } | { success: false; error: string }
> {
    const { gw, contract } = newGateway();
    try {
        const resultBytes = await contract.submitTransaction(
            'CreateShipment',
            id,
            origin,
            destination
        );
        return { success: true, result: resultBytes.toString() };
    } catch (err: any) {
        console.error('createShipment error:', err);
        return { success: false, error: err.toString() };
    } finally {
        gw.close();
    }
}

//
// Get all shipments from the ledger
//
export async function getAllShipments(): Promise<any[]> {
    const { gw, contract } = newGateway();
    try {
        const resultBytes = await contract.evaluateTransaction(
            'GetAllShipments'
        );
        const raw = resultBytes.toString().trim();

        // If the chaincode returned literally "null" or an empty string, treat as []
        if (raw === '' || raw === 'null') {
            console.debug(
                'GetAllShipments → empty or null payload, returning []'
            );
            return [];
        }

        // Otherwise attempt to parse JSON
        try {
            return JSON.parse(raw);
        } catch (parseErr) {
            console.error('GetAllShipments: invalid JSON payload:', raw);
            return [];
        }
    } catch (err) {
        console.error('getAllShipments error:', err);
        return [];
    } finally {
        gw.close();
    }
}

//
// Query a single shipment by ID
//
export async function getShipment(id: string): Promise<any | null> {
    const { gw, contract } = newGateway();
    try {
        const resultBytes = await contract.evaluateTransaction(
            'QueryShipment',
            id
        );
        return JSON.parse(resultBytes.toString());
    } catch (err: any) {
        console.error(`getShipment(${id}) error:`, err);
        return null;
    } finally {
        gw.close();
    }
}

//
// Update just the status field of a shipment
//
export async function updateShipmentStatus(
    id: string,
    status: string
): Promise<{ success: true } | { success: false; error: string }> {
    const { gw, contract } = newGateway();
    try {
        await contract.submitTransaction('UpdateStatus', id, status);
        return { success: true };
    } catch (err: any) {
        console.error(`updateShipmentStatus(${id}) error:`, err);
        return { success: false, error: err.toString() };
    } finally {
        gw.close();
    }
}
