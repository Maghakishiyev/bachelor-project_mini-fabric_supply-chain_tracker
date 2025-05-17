import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys
import os
import pathlib

# Ensure the output directory exists
os.makedirs("docs", exist_ok=True)

# Read the main CSV file
df = pd.read_csv("docs/tps_latency.csv")
# Convert timestamp to datetime (pandas uses seconds by default)
df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms")
df.set_index("timestamp", inplace=True)

# Calculate transactions per second
tps = df.resample("1S").count()
tps.columns = ["TPS"]  # Rename column

# Calculate average latency per second
latency = df.resample("1S").mean()
latency.columns = ["Avg Latency (ms)"]

# Plot TPS and Latency
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

# Overall latency distribution 
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

# Load the operation-specific data if available
create_file = pathlib.Path("docs/create_ops.csv")
update_file = pathlib.Path("docs/update_ops.csv")

if create_file.exists() and update_file.exists():
    # Create operations analysis
    df_create = pd.read_csv("docs/create_ops.csv")
    df_create["timestamp"] = pd.to_datetime(df_create["timestamp"], unit="ms")
    df_create.set_index("timestamp", inplace=True)
    
    # Update operations analysis
    df_update = pd.read_csv("docs/update_ops.csv")
    df_update["timestamp"] = pd.to_datetime(df_update["timestamp"], unit="ms")
    df_update.set_index("timestamp", inplace=True)
    
    # Plot comparison between Create vs Update latency
    plt.figure(figsize=(10, 6))
    
    # Side-by-side boxplot comparing Create vs Update latency
    plt.boxplot(
        [df_create["latency_ms"], df_update["latency_ms"]],
        labels=["Create Operations", "Update Operations"],
        patch_artist=True,
        boxprops=dict(facecolor="lightblue"),
        medianprops=dict(color="red")
    )
    
    plt.title('Create vs Update Operations: Latency Comparison')
    plt.ylabel('Latency (ms)')
    plt.grid(axis='y', linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig("docs/create_vs_update_latency.png", dpi=180, bbox_inches="tight")
    
    # Create TPS over time
    create_tps = df_create.resample("1S").count()
    create_tps.columns = ["Create TPS"]
    
    # Update TPS over time
    update_tps = df_update.resample("1S").count()
    update_tps.columns = ["Update TPS"]
    
    # Combined TPS graph
    plt.figure(figsize=(12, 6))
    create_tps.plot(color='blue', label='Create Operations')
    update_tps.plot(color='green', label='Update Operations')
    plt.title('Transaction Types Over Time')
    plt.xlabel('Time')
    plt.ylabel('Transactions Per Second')
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.savefig("docs/transaction_types_tps.png", dpi=180, bbox_inches="tight")
    
    # Print type-specific statistics
    print("\nOperation Type Statistics:")
    print(f"Create Operations: {len(df_create)}")
    print(f"  - Average Latency: {df_create['latency_ms'].mean():.1f} ms")
    print(f"  - 95th Percentile: {df_create['latency_ms'].quantile(0.95):.1f} ms")
    print(f"Update Operations: {len(df_update)}")
    print(f"  - Average Latency: {df_update['latency_ms'].mean():.1f} ms")
    print(f"  - 95th Percentile: {df_update['latency_ms'].quantile(0.95):.1f} ms")
    
    print(f"Generated create vs update comparison: docs/create_vs_update_latency.png")
    print(f"Generated transaction types over time: docs/transaction_types_tps.png")

# Print general statistics
print(f"Generated TPS/latency plot: docs/tps_latency.png")
print(f"Generated latency distribution: docs/latency_distribution.png")

print("\nOverall Performance Statistics:")
print(f"Total Transactions: {len(df)}")
print(f"Peak TPS: {tps.max().values[0]:.1f}")
print(f"Average TPS: {tps.mean().values[0]:.1f}")
print(f"Average Latency: {df['latency_ms'].mean():.1f} ms")
print(f"Latency 50th Percentile: {df['latency_ms'].quantile(0.50):.1f} ms")
print(f"Latency 90th Percentile: {df['latency_ms'].quantile(0.90):.1f} ms")
print(f"Latency 95th Percentile: {df['latency_ms'].quantile(0.95):.1f} ms")