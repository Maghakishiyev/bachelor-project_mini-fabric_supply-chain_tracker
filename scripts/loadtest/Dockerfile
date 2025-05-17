FROM node:20-alpine

WORKDIR /app

# Copy package files and install dependencies
COPY package.json ./
RUN npm install @grpc/grpc-js @hyperledger/fabric-gateway ts-node typescript

# Copy load testing scripts
COPY . .

# Default environment variables
ENV RATE=20
ENV SECONDS=300
ENV CHANNEL_NAME=supplychain
ENV CHAINCODE_NAME=shipping
ENV MSP_ID=ManufacturerMSP
ENV PEER_ENDPOINT=peer0.manufacturer.example.com:7051
ENV CERT_PATH=/crypto/admin-cert.pem
ENV KEY_PATH=/crypto/admin-key.pem
ENV TLS_CERT_PATH=/crypto/ca.pem

# Script that runs on container start
CMD ["sh", "-c", "npx ts-node --project tsconfig.json gen.ts"]