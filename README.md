# Mini-Fabric Supply Chain Tracker

[![build-and-test](https://github.com/yourusername/bachelor-project_mini-fabric_supply-chain_tracker/actions/workflows/test.yml/badge.svg)](https://github.com/yourusername/bachelor-project_mini-fabric_supply-chain_tracker/actions/workflows/test.yml)

This project implements a supply chain tracking system on Hyperledger Fabric with a Next.js frontend. It allows different organizations (Manufacturer, Transporter, Warehouse, and Retailer) to track shipments through the supply chain using blockchain technology.

## Project Structure

- **network/** - Hyperledger Fabric network configuration and scripts
  - `configtx.yaml` - Channel configuration
  - `crypto-config.yaml` - Organization definitions
  - `generate.sh` - Script to generate crypto materials
- **chaincode/shipping/** - Go chaincode for supply chain management
- **services/listener/** - Go service that listens for block events and broadcasts them via WebSocket
- **app/** - Next.js 14 frontend application
- **scripts/**
  - **loadtest/** - Load testing and transaction generation tools
  - **analyse/** - Scripts for metrics processing and visualization
- **monitoring/** - Prometheus and Grafana configuration for performance monitoring
- **docs/** - Project documentation and performance artifacts (CSV, PNG)

## Prerequisites

| Tool               | Min version | Install hint                                                     |
| ------------------ | ----------- | ---------------------------------------------------------------- |
| **Docker Engine**  | 25.0        | Linux, macOS, or WSL2 (Ubuntu 22.04)                             |
| **docker-compose** | 2.25+       | Bundled with Docker Desktop                                      |
| **Go**             | 1.24.x      | `go env -w GO111MODULE=on` after install                         |
| **Node.js**        | 20.x (LTS)  | use `nvm install 20`                                             |
| **Yarn Classic**   | 1.22        | `corepack enable` then `corepack prepare yarn@stable --activate` |
| **GNU make**       | 4.x         | Linux package manager                                            |
| **Python**         | 3.9+        | For metrics processing and visualization                         |
| **pip packages**   | latest      | `pip install pandas matplotlib`                                  |

## Quick Start

### Option 1: One-Command Deployment

```bash
# Start the entire stack with a single command
make full-stack

# Open the application at http://localhost:3000
# Grafana dashboard at http://localhost:3002 (admin/admin)
```

### Option 2: Custom Setup

```bash
# Clean up any previous runs and start fresh
make clean

# Generate crypto material, start network, create channel, deploy chaincode, and start services
make all

# Start monitoring stack (optional)
make monitoring

# Open the application at http://localhost:3000
```

### Running Load Tests and Collecting Metrics

```bash
# Run load test with default settings (20 tx/s for 300 seconds)
make loadtest

# Run with custom parameters
make RATE=40 SECONDS=600 loadtest

# Generate metrics and visualizations
make metrics

# Find results in the docs/ directory:
# - tps_latency.csv  (raw data)
# - tps_latency.png  (throughput and latency graphs)
# - latency_distribution.png (latency percentiles)
```

## Individual Commands

### Basic Network Operations

```bash
# Generate crypto material
make generate

# Start the network
make network-up

# Create and join the channel
make channel-create
make channel-join

# Deploy the chaincode (package, install, approve, commit)
make cc-deploy

# Start the event listener service
make listener-up

# Start the frontend application
make app-up

# View logs
make logs

# Stop all containers
make network-down
```

### Monitoring and Performance Testing

```bash
# Start Prometheus and Grafana monitoring
make monitoring

# Stop monitoring stack
make monitoring-down

# Run the k6 load test (alternative to Node.js generator)
make k6-test

# Create demo video placeholder
make video

# Start the complete stack with one command
make full-stack
```

## Hyperledger Fabric Network

The network consists of:
- 1 Orderer node (etcdraft consensus)
- 4 Organizations (Manufacturer, Transporter, Warehouse, Retailer)
- 1 Peer per organization
- CouchDB state database for each peer
- 1 Application channel (supplychain)

## Smart Contract (Chaincode)

The shipping chaincode provides the following capabilities:
- Creating shipments (restricted to Manufacturer)
- Updating shipment status
- Transferring shipment ownership between organizations
- Querying shipment details
- Retrieving all shipments

## Frontend Application

The Next.js 14 application provides:
- Dashboard with real-time shipment tracking
- Creation form for new shipments
- Detailed view of individual shipments
- Live updates via WebSocket from the blockchain

## Performance Monitoring

The project includes a comprehensive performance monitoring solution:
- **Prometheus**: Collects metrics from Fabric peers and orderer
- **Grafana**: Visualizes performance metrics with dashboards
- **Transaction Generator**: Creates load for performance testing
- **Metrics Analysis**: Processes results and generates visualization

## Thesis Integration

The artifacts generated by this project can be directly used in your thesis:
- `docs/tps_latency.png`: Throughput and latency graph
- `docs/latency_distribution.png`: Transaction latency distribution
- `docs/architecture.png`: System architecture diagram
- `docs/tps_latency.csv`: Raw data for custom analysis

## Troubleshooting

If you encounter errors:

1. Check that Docker is running
2. Ensure the necessary ports are free (3000-3002, 7050-10051, 9090)
3. Run `make clean` to reset the environment
4. Check the logs with `make logs`
5. For load testing issues, try reducing the transaction rate (e.g., `make RATE=10 loadtest`)