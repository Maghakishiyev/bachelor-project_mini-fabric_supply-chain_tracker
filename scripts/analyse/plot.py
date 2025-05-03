import pandas as pd
import matplotlib.pyplot as plt
import sys
import os

# Ensure the output directory exists
os.makedirs("docs", exist_ok=True)

# Read the CSV file
df = pd.read_csv("docs/tps_latency.csv", parse_dates=["timestamp"], unit="ms")
df.set_index("timestamp", inplace=True)

# Calculate transactions per second
tps = df.resample("1S").count()
tps.columns = ["TPS"]  # Rename column

# Calculate average latency per second
latency = df.resample("1S").mean()
latency.columns = ["Avg Latency (ms)"]

# Plot TPS
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8), sharex=True)

# TPS plot
tps.plot(ax=ax1, color='blue')
ax1.set_title('Transactions Per Second')
ax1.set_ylabel('TPS')
ax1.grid(True)

# Latency plot
latency.plot(ax=ax2, color='red')
ax2.set_title('Average Transaction Latency')
ax2.set_ylabel('Latency (ms)')
ax2.set_xlabel('Time')
ax2.grid(True)

plt.tight_layout()
fig.savefig("docs/tps_latency.png", dpi=180, bbox_inches="tight")

# Additional detailed latency percentile plot
plt.figure(figsize=(10, 6))
plt.hist(df["latency_ms"], bins=50, alpha=0.75)
plt.axvline(df["latency_ms"].quantile(0.50), color='green', linestyle='dashed', linewidth=2, label=f'50th Percentile: {df["latency_ms"].quantile(0.50):.1f}ms')
plt.axvline(df["latency_ms"].quantile(0.90), color='orange', linestyle='dashed', linewidth=2, label=f'90th Percentile: {df["latency_ms"].quantile(0.90):.1f}ms')
plt.axvline(df["latency_ms"].quantile(0.95), color='red', linestyle='dashed', linewidth=2, label=f'95th Percentile: {df["latency_ms"].quantile(0.95):.1f}ms')
plt.title('Transaction Latency Distribution')
plt.xlabel('Latency (ms)')
plt.ylabel('Frequency')
plt.legend()
plt.tight_layout()
plt.savefig("docs/latency_distribution.png", dpi=180, bbox_inches="tight")

print(f"Generated TPS/latency plot: docs/tps_latency.png")
print(f"Generated latency distribution: docs/latency_distribution.png")

# Print some statistics
print("\nPerformance Statistics:")
print(f"Total Transactions: {len(df)}")
print(f"Peak TPS: {tps.max().values[0]:.1f}")
print(f"Average TPS: {tps.mean().values[0]:.1f}")
print(f"Average Latency: {df['latency_ms'].mean():.1f} ms")
print(f"Latency 50th Percentile: {df['latency_ms'].quantile(0.50):.1f} ms")
print(f"Latency 90th Percentile: {df['latency_ms'].quantile(0.90):.1f} ms")
print(f"Latency 95th Percentile: {df['latency_ms'].quantile(0.95):.1f} ms")