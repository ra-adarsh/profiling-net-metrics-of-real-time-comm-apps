import pandas as pd
import matplotlib.pyplot as plt
import os
from datetime import datetime

# Load CSV file
df = pd.read_csv('network_metrics.csv')
df.fillna(0, inplace=True)

# Drop unwanted columns
df = df.drop(columns=['PID', 'PORT', 'IP'])

# Convert Timestamp to datetime and strip milliseconds
df['Timestamp'] = pd.to_datetime(df['Timestamp']).dt.floor('s')

# Split rtt into rtt and rtt_var
df[['rtt', 'rtt_var']] = df['rtt'].astype(str).str.extract(r'([\d\.]+)/([\d\.]+)').astype(float)

# Normalize bandwidth fields to Mbps
def convert_to_mbps(value):
    try:
        value = str(value).strip().lower()
        if value.endswith('mbps'):
            return float(value.replace('mbps', ''))
        elif value.endswith('kbps'):
            return float(value.replace('kbps', '')) / 1000
        elif value == '0' or value == '':
            return 0.0
        else:
            return float(value)  # fallback for already clean numbers
    except Exception:
        return 0.0

for field in ['send', 'pacing_rate', 'delivery_rate']:
    df[field] = df[field].apply(convert_to_mbps)

# Group by Timestamp only
grouped_by_timestamp = df.groupby('Timestamp', as_index=False).agg({
    "rto": "mean",
    "rtt": "mean",
    "rtt_var": "mean",
    "ato": "mean",
    "rcv_rtt": "mean",
    "send": "mean",
    "pacing_rate": "mean",
    "delivery_rate": "mean"
})

df = grouped_by_timestamp
df.to_csv('./net_log_processed.csv', index=False)

# Create plots directory with timestamp
timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
plots_dir = f"plots_{timestamp_str}"
os.makedirs(plots_dir, exist_ok=True)

# List of fields to plot
fields_to_plot = ["rto", "rtt", "rtt_var", "ato", "rcv_rtt", "send", "pacing_rate", "delivery_rate"]

# Plot each field
for field in fields_to_plot:
    plt.figure(figsize=(10, 4))
    plt.plot(df['Timestamp'], df[field], color='tab:blue', marker='o', linestyle='-')
    plt.title(f'{field.upper()} over Time', fontsize=14)
    plt.xlabel('Timestamp')
    plt.ylabel(f'{field} (Mean)')
    plt.grid(True)
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(f'{plots_dir}/{field}_plot.png')