import json, csv, sys
rows = []
for line in sys.stdin:
    try:
        obj = json.loads(line)
        rows.append((obj["ts"], obj["latency"]))
    except json.JSONDecodeError:
        # Skip lines that aren't valid JSON
        continue
    except KeyError:
        # Skip objects that don't have the required keys
        continue
rows.sort()
with open("docs/tps_latency.csv","w",newline="") as f:
    wr = csv.writer(f)
    wr.writerow(["timestamp","latency_ms"])
    wr.writerows(rows)
print(f"Processed {len(rows)} transaction records")