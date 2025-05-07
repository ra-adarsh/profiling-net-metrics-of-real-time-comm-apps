# Overview
This repo contains the script and Python code for recording network metrics of real time communication applications on Linux based system.

# Introduction
- The Bash script monitors network-related TCP connection metrics for a specific process (given by PID) and its child processes, using Linux's `ss` command.
- It extracts details such as RTT, RTO, pacing rate, and delivery rate, and logs them to a CSV file. The script runs continuously in a loop with a 0.5-second interval between checks.
- Running the script generates a CSV file named `network_metrics_YYYYMMDD_HHMMSS.csv`, where the timestamp reflects the script's start time. Each row in the CSV contains: `Timestamp, PID, IP, Port, rto, rtt, ato, rcv_rtt, send, pacing_rate, delivery_rate`.
- Uses `ss -tnpi` to identify TCP connections owned by the given PID or its children. For each unique connection, uses `ss -ti` to extract extended TCP info (like RTT, delivery rate, etc.).
- Parses key-value pairs from the ss output, supporting both colon-separated and space-separated formats. Appends the parsed metrics to the CSV file with a timestamp.
- Recursively finds child processes of the target PID using `pgrep -P`. Monitors connections for all descendant processes.
# Steps to run
- Give permissions to the script.
```
chmod +x network_monitor.sh
```
- Assign the value of Parent PID to `target_pid`. If using the script on Zoom
```
target_pid=$(pgrep zoom | head -n 1)
```
- Since other real time communication applications (Google Meet, Microsoft Teams) do not have apps for Ubuntu, run those applications on Google Chrome. Use Chrome's Task Manager to find the PID of the tab running the application.
```
target_pid=<PID from Chrome’s Task Manager>
```
- Run the script with target Parent PID to generate the CSV file containing metrics.
```
./network_monitor.sh $target_pid
```
- Provide the name of the CSV file generated to `pd.read_csv(‘<file_name>’)` to load it. Then, run the Python file to generate graphs. It’ll generate plots in a directory with a name in the format `plots_YYYYMMDD_HHMMSS`.
```
python3 network_plotting.py
```
# Limitations:
- Only supports TCP connections.
- High CPU usage possible with very frequent polling or high process tree depth.
