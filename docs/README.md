# Documentation and Artifacts

This directory contains documentation and artifacts generated for the thesis:

## Contents

1. **tps_latency.csv** - Raw data from performance testing
2. **tps_latency.png** - Graph visualization of throughput and latency
3. **latency_distribution.png** - Histogram of transaction latency distribution
4. **architecture.png** - System architecture diagram
5. **demo.mp4** - Demo video of the system in action (to be recorded)

## How to Use These Artifacts

### Performance Data

The `tps_latency.csv` file contains timestamps and latency measurements for each transaction during load testing. This data can be imported into Excel or other data analysis tools to create custom graphs or tables for your thesis.

Format:
```
timestamp,latency_ms
1620000000000,150
1620000000050,175
...
```

### Images for Thesis

All PNG files in this directory are designed to be directly usable in your thesis document. The resolution (180 DPI) is suitable for print-quality documents.

Suggested captions:
- **tps_latency.png**: "Figure X: Observed throughput and latency during a 5-minute stress test with 40 tx/s input rate."
- **latency_distribution.png**: "Figure Y: Distribution of transaction latencies with 90th and 95th percentile markers."
- **architecture.png**: "Figure Z: Runtime architecture of the Hyperledger Fabric supply chain tracking system."

### Demo Video

Record a demonstration of the system running and place it in this directory as `demo.mp4`. The demo should show:

1. Starting the network
2. Creating a shipment
3. Tracking it through the supply chain
4. Running a load test
5. Viewing performance metrics

The video should be around 3 minutes in length and suitable for presentation during your defense.