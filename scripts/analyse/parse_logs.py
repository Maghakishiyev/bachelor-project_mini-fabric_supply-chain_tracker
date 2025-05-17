import json, csv, sys
rows = []
create_rows = []
update_rows = []

for line in sys.stdin:
    try:
        obj = json.loads(line)
        # Basic row for main metrics
        rows.append((obj["ts"], obj["latency"]))
        
        # Store tx type info for additional analysis 
        if "type" in obj:
            if obj["type"] == "CREATE":
                create_rows.append((obj["ts"], obj["latency"]))
            elif obj["type"] == "UPDATE":
                update_rows.append((obj["ts"], obj["latency"]))
        else:
            # For backward compatibility with old logs
            create_rows.append((obj["ts"], obj["latency"]))
            
    except json.JSONDecodeError:
        # Skip lines that aren't valid JSON
        continue
    except KeyError:
        # Skip objects that don't have the required keys
        continue

# Sort by timestamp
rows.sort()
create_rows.sort()
update_rows.sort()

# Write main TPS/latency file
with open("docs/tps_latency.csv","w",newline="") as f:
    wr = csv.writer(f)
    wr.writerow(["timestamp","latency_ms"])
    wr.writerows(rows)

# Write create operations file
with open("docs/create_ops.csv","w",newline="") as f:
    wr = csv.writer(f)
    wr.writerow(["timestamp","latency_ms"])
    wr.writerows(create_rows)

# Write update operations file
with open("docs/update_ops.csv","w",newline="") as f:
    wr = csv.writer(f)
    wr.writerow(["timestamp","latency_ms"])
    wr.writerows(update_rows)

print(f"Processed {len(rows)} transaction records")
print(f" - Create operations: {len(create_rows)}")
print(f" - Update operations: {len(update_rows)}")