import {
    connect,
    Gateway,
    Identity,
    signers,
} from '@hyperledger/fabric-gateway';
import { randomUUID } from 'crypto';
import { credentials, ChannelCredentials, Client } from '@grpc/grpc-js';
import { createPrivateKey, KeyObject } from 'crypto';
import fs from 'fs';
import path from 'path';

const RATE = Number(process.env.RATE || 20); // tx/s
const DURATION = Number(process.env.SECONDS || 300);
const CC_NAME = process.env.CHAINCODE_NAME || 'shipping';
const CHANNEL_NAME = process.env.CHANNEL_NAME || 'supplychain';

// Sample data for more realistic load testing
const CITIES = [
    'Warsaw',
    'Berlin',
    'Paris',
    'Madrid',
    'Rome',
    'London',
    'Amsterdam',
    'Vienna',
    'Brussels',
    'Copenhagen',
    'Helsinki',
    'Oslo',
    'Stockholm',
    'Zurich',
    'Prague',
    'Budapest',
    'Athens',
    'Dublin',
    'Lisbon',
    'Bucharest',
];

// Use the actual status values from the system
const STATUSES = [
    'CREATED',
    'PICKED_UP',
    'IN_TRANSIT',
    'DELIVERED',
    'EXCEPTION',
];

// Get random city from list
function getRandomCity(): string {
    return CITIES[Math.floor(Math.random() * CITIES.length)];
}

// Get random origin-destination pair (different cities)
function getRandomRoute(): [string, string] {
    const origin = getRandomCity();
    let destination;
    do {
        destination = getRandomCity();
    } while (destination === origin);
    return [origin, destination];
}

// Get random status for updates
function getRandomStatus(): string {
    return STATUSES[Math.floor(Math.random() * STATUSES.length)];
}

// Store created shipment IDs for later updates
const createdShipments: string[] = [];

// Connection settings from environment variables (similar to app/src/lib/fabric.ts)
const mspId = process.env.MSP_ID || 'ManufacturerMSP';
const peerEndpoint =
    process.env.PEER_ENDPOINT || 'peer0.manufacturer.example.com:7051';
const certPath = process.env.CERT_PATH || '/crypto/admin-cert.pem';
const keyPath = process.env.KEY_PATH || '/crypto/admin-key.pem';
const tlsCertPath = process.env.TLS_CERT_PATH || '/crypto/ca.pem';

async function getGatewayFromEnv(): Promise<Gateway> {
    // 1. Read TLS cert for the peer's CA
    const caPem = fs.readFileSync(tlsCertPath);

    // 2. Read our client identity cert + private key
    const certPem = fs.readFileSync(certPath);
    const keyPem = fs.readFileSync(keyPath);

    // 3. Create Identity object
    const identity: Identity = { mspId, credentials: certPem };

    // 4. Convert PEM → KeyObject for signer
    const privateKey: KeyObject = createPrivateKey({
        key: keyPem,
        format: 'pem',
    });
    const signer = signers.newPrivateKeySigner(privateKey);

    // 5. Build gRPC client with SSL
    const tlsCreds: ChannelCredentials = credentials.createSsl(caPem);
    const client = new Client(peerEndpoint, tlsCreds);

    // 6. Connect to the Gateway
    return connect({ client, identity, signer });
}

(async () => {
    // === gateway boiler-plate (reuse Next lib) ===
    const gw = await getGatewayFromEnv();
    const net = gw.getNetwork(CHANNEL_NAME);
    const cc = net.getContract(CC_NAME);

    const start = Date.now();
    let sent = 0;
    const timer = setInterval(async () => {
        if (Date.now() - start > DURATION * 1000) {
            clearInterval(timer);
            gw.close();
            return;
        }

        const t0 = Date.now();
        let transactionType = 'CREATE';
        let id = '';

        try {
            // After we've created at least 10 shipments, start mixing in some updates
            if (createdShipments.length > 10 && Math.random() > 0.6) {
                // 40% chance to do an update instead of create
                transactionType = 'UPDATE';
                // Select a random existing shipment
                id =
                    createdShipments[
                        Math.floor(Math.random() * createdShipments.length)
                    ];
                const status = getRandomStatus();

                // Update the status
                await cc.submitTransaction('UpdateStatus', id, status);
            } else {
                // Create a new shipment with random origin and destination
                id = randomUUID().slice(0, 8);
                const [origin, destination] = getRandomRoute();

                await cc.submitTransaction(
                    'CreateShipment',
                    id,
                    origin,
                    destination
                );

                // Store the ID for future updates
                createdShipments.push(id);

                // Keep the array at a manageable size
                if (createdShipments.length > 100) {
                    createdShipments.shift(); // Remove oldest
                }
            }
        } catch (err: any) {
            console.error('Transaction failed:', err.message || err);
        }

        const latency = Date.now() - t0;
        console.log(
            JSON.stringify({ id, type: transactionType, latency, ts: t0 })
        );
        sent++;
    }, 1000 / RATE);
})();
