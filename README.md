# Mini-Fabric Supply Chain Tracker

A full-featured supply chain tracking system built on Hyperledger Fabric. It demonstrates managing shipments through multiple organizations (Manufacturer, Transporter, Warehouse, Retailer) using a blockchain network, including:

* **Fabric Network** with orderer, peers, CouchDB state databases, Prometheus metrics, and Grafana dashboards.
* **Go Chaincode** (`shipping`) for creating and updating shipment records.
* **Event Listener Service** broadcasting block events over WebSocket.
* **Next.js Frontend** showing real-time shipment status and history.
* **Load Testing** using a custom Go-based generator and k6.
* **Monitoring & Analytics** with Prometheus and Grafana provisioning.

---

## 📁 Repository Structure

```
├── Makefile
├── docker-compose.yml         # Compose for Fabric network, CouchDB, Prometheus, Grafana
├── network/                   # Fabric artifacts and scripts
│   ├── configtx.yaml          # Channel definitions
│   ├── crypto-config.yaml     # MSP and org definitions
│   ├── generate.sh            # Generates crypto materials and genesis block
│   └── scripts/               # Wallet preparation scripts
├── chaincode/                 # External chaincode package (Go)
│   └── shipping/              # `CreateShipment`, `UpdateStatus`, `QueryShipment`
├── services/                  # Auxiliary microservices
│   └── listener/              # Go service: listens for block events, broadcasts over WS
├── app/                       # Next.js 14 frontend application
├── monitoring/                # Prometheus & Grafana provisioning
│   ├── prometheus.yml         # scrape configs
│   ├── dashboards/            # JSON dashboard files
│   └── provisioning/          # Grafana data source & dashboard provisioning
├── scripts/                   # Load testing and analysis
│   ├── loadtest/              # Dockerized Go generator
│   └── analyse/               # Parsers & plotting scripts
└── README.md                  # This documentation
```

---

## 🛠️ Prerequisites

* [Docker](https://www.docker.com/) & [docker-compose](https://docs.docker.com/compose/)
* [Go 1.24+](https://golang.org/) (for building chaincode and listener)
* [Node.js 18+](https://nodejs.org/) (for frontend)
* [Make](https://www.gnu.org/software/make/) (optional but recommended)

---

## 🚀 Getting Started

### 1. Generate Crypto Material and Channel Artifacts

```bash
make generate
```

This runs `network/generate.sh` to create MSP folders and the system & application channel blocks.

### 2. Start Fabric Network

```bash
make network-up
```

Brings up:

* Orderer (`orderer.example.com:7050`)
* 4 x Peers (`peer0.<org>.example.com`)
* CouchDB instances
* CLI container

### 3. Create & Join Channel

```bash
make channel-create
make channel-join
```

Sets up the `supplychain` channel and joins all peers.

### 4. Deploy Chaincode (CCaaS)

```bash
make cc-deploy
```

Packages the Go chaincode externally, installs on peers, approves & commits the definition, and runs it as an external service on port `9999`.

### 5. Prepare Wallets

```bash
make wallets
```

Generates application identity wallets under `network/wallets` for all orgs.

### 6. Start Listener & Frontend

```bash
make listener-up
make app-up
```

* **Listener** exposes WebSocket on `localhost:3001/ws` with block event notifications.
* **Frontend** runs at `http://localhost:3000` showing shipment dashboard.

### 7. Enable Monitoring

```bash
make monitoring
```

* Prometheus on `http://localhost:9090`
* Grafana on `http://localhost:3002` (default `admin/admin`)

Grafana is provisioned with:

* **Data Source**: Prometheus
* **Dashboards**: Fabric performance metrics

---

## 📊 Monitoring & Dashboards

* **Prometheus** scrapes Fabric metrics (peers and orderer) via `/metrics` endpoints.
* **Grafana** automatically loads dashboards from `monitoring/dashboards` and data sources from `monitoring/provisioning`.

To troubleshoot:

1. Check Prometheus targets: `up{job="fabric_peers"}` in Prometheus UI.
2. Ensure Grafana provisioning files (`datasources.yaml`, `dashboards.yaml`) match your environment.

---

## 🧪 Load Testing

### Custom Go Transaction Generator

```bash
make loadtest RATE=20 SECONDS=300
```

* Spins up a Docker container that submits random `CreateShipment` and `UpdateStatus` transactions.
* Outputs raw logs to `docs/run.raw.json`.

Process logs & generate K8 charts:

```bash
make metrics
```

* Parses `run.raw.json` into `docs/tps_latency.csv`.
* Generates `docs/tps_latency.png`.

### k6 Test (Optional)

```bash
make k6-test
```

Runs a k6 script (`scripts/loadtest/k6.js`) for HTTP-based gateway testing.

> *Note:* Requires building a custom k6 binary with the Fabric extension or using `xk6`.

---

## 🧩 Application Components

* **Chaincode (`chaincode/shipping`)**:

  * `CreateShipment(id, origin, destination)` → stores a new record.
  * `UpdateStatus(id, status)` → appends status history.
  * `QueryShipment(id)` → retrieves shipment and status timeline.

* **Listener Service (`services/listener`)**:

  * Subscribes to block events using the Fabric Gateway.
  * Emits JSON payloads to WebSocket clients on new blocks.

* **Frontend (`app`)**:

  * Connects to the WebSocket listener.
  * Displays live shipment events and status.
  * Queries REST endpoints via Gateway for full shipment history.

* **CLI (`cli` container)**:

  * Utility for manually invoking peer commands, packaging chaincode, and troubleshooting.

---

## ⚙️ Makefile Targets

| Target            | Description                                        |
| ----------------- | -------------------------------------------------- |
| `generate`        | Generate crypto artifacts & genesis/application tx |
| `network-up`      | Start Fabric network via Docker Compose            |
| `network-down`    | Tear down network                                  |
| `channel-create`  | Create application channel                         |
| `channel-join`    | Join all peers to channel                          |
| `cc-deploy`       | Package, install, approve, commit, & launch CCaaS  |
| `cc-test-invoke`  | Invoke a test transaction                          |
| `cc-test-query`   | Query test shipment                                |
| `listener-up`     | Start event listener service                       |
| `app-up`          | Start Next.js frontend                             |
| `monitoring`      | Start Prometheus & Grafana                         |
| `monitoring-down` | Stop monitoring stack                              |
| `loadtest`        | Run Go-based transaction generator                 |
| `metrics`         | Parse & plot load test metrics                     |
| `k6-test`         | Run k6 load test script                            |
| `clean`           | Remove containers, volumes, generated artifacts    |
| `logs`            | Follow Docker Compose logs                         |

---

## 🛠️ Troubleshooting

* **DNS errors connecting to `orderer.example.com` or peers**: ensure all services share the same Docker network (`fabric_network`) and container names match environment variables.
* **Port conflicts**: free up ports `7050-7051`, `8051`, `9051`, `10051`, `9443-9448`, `3000-3002`, `9090`.
* **Invalid Grafana provisioning**: validate `monitoring/provisioning/*` against Grafana docs (no top-level `apiVersion` in YAML).
* **MVCC\_READ\_CONFLICT** in load tests: reduce concurrency or catch errors in generator code to retry failed transactions.

---

## 🚧 Contributing

1. Fork the repository and clone locally.
2. Make your changes on a feature branch.
3. Run `make test` to ensure chaincode tests pass.
4. Submit a Pull Request with detailed description.

---

Thank you for using **Mini-Fabric Supply Chain Tracker**! 🎉
