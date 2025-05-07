#!/bin/bash

# Check if a PID was provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <PID>"
    exit 1
fi

PARENT_PID=$1

# Generate an output file name with a timestamp
OUTPUT_FILE="network_metrics_$(date +%Y%m%d_%H%M%S).csv"

# Check if the given process ID exists
if ! ps -p "$PARENT_PID" > /dev/null 2>&1; then
    echo "Process with PID $PARENT_PID does not exist."
    exit 1
fi

# Declare associative arrays for tracking seen connections and metrics per connection
declare -A seen_connections
declare -A connection_metrics

# Define a list of network metrics to extract from `ss -i` output
metric_keys=("rto" "rtt" "ato" "rcv_rtt" "send" "pacing_rate" "delivery_rate")

# Initialize the CSV file with a header line if it doesn't already exist
if [ ! -f "$OUTPUT_FILE" ]; then
    {
        echo -n "Timestamp,PID,IP,PORT"
        for key in "${metric_keys[@]}"; do
            echo -n ",$key"
        done
        echo
    } > "$OUTPUT_FILE"
fi

# Function to parse `ss -i` output and extract network metrics
parse_ss_output() {
    local pid=$1
    local ip=$2
    local port=$3

    # Initialize metric values to empty for current connection
    for key in "${metric_keys[@]}"; do
        connection_metrics["$key"]=""
    done

    # Read all lines into one concatenated string (ss -i output spans multiple lines)
    local full_line=""
    while read -r line; do
        full_line="$full_line $line"
    done

    # Split the string into words
    read -ra words <<< "$full_line"
    for ((i=0; i<${#words[@]}; i++)); do
        word="${words[$i]}"

        # Handle colon-separated metrics like rtt:100ms
        if [[ "$word" == *:* ]]; then
            key="${word%%:*}"  # extract key before colon
            val="${word#*:}"   # extract value after colon
            if [[ " ${metric_keys[*]} " == *" $key "* ]]; then
                connection_metrics["$key"]="$val"
            fi

        # Handle space-separated metrics like "send 123456"
        elif [[ "$word" == "send" || "$word" == "pacing_rate" || "$word" == "delivery_rate" ]]; then
            next_index=$((i + 1))
            val="${words[$next_index]}"
            connection_metrics["$word"]="$val"
        fi
    done

    # Write the extracted metrics into the CSV file with timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S.%3N")
    {
        echo -n "$timestamp,$pid,$ip,$port"
        for key in "${metric_keys[@]}"; do
            echo -n ",${connection_metrics[$key]}"
        done
        echo
    } >> "$OUTPUT_FILE"
}

# Function to extract network connections owned by a given PID
process_pid_connections() {
    local pid=$1

    # Get TCP connections with process info, filter for the current PID
    ss -tnpi | grep "pid=$pid" | while read -r line; do
        # Extract the local IP and port
        local local_addr=$(echo "$line" | awk '{print $4}')
        local ip=""
        local port=""

        # Handle IPv6 addresses ([::1]:PORT)
        if [[ "$local_addr" =~ ^\[.*\]:[0-9]+$ ]]; then
            ip=$(echo "$local_addr" | sed -E 's/^\[([0-9a-fA-F:]+)\]:[0-9]+$/\1/')
            port=$(echo "$local_addr" | sed -E 's/^\[[0-9a-fA-F:]+\]:([0-9]+)$/\1/')
        else
            # Handle IPv4 addresses (IP:PORT)
            ip=$(echo "$local_addr" | cut -d':' -f1)
            port=$(echo "$local_addr" | cut -d':' -f2)
        fi

        # Avoid processing the same connection multiple times
        key="${pid}:${ip}:${port}"
        if [[ -n "${seen_connections[$key]}" ]]; then
            continue
        fi
        seen_connections["$key"]=1

        # Use `ss -ti` to get detailed TCP info for this connection
        ss -ti | awk -v ip="$ip" -v port="$port" '
            $0 ~ ip && $0 ~ ":"port {capture=1; print; next}
            capture && $0 ~ /^[[:space:]]/ { print; next }
            capture { capture=0 }
        ' | parse_ss_output "$pid" "$ip" "$port"
    done
}

# Recursive function to process all child processes of a given parent
get_descendants() {
    local parent=$1
    local children=$(pgrep -P "$parent")
    for child in $children; do
        process_pid_connections "$child"
        get_descendants "$child"
    done
}

# Main monitoring loop — run until script is stopped
while true; do
    # Monitor parent PID
    process_pid_connections "$PARENT_PID"

    # Monitor all child processes recursively
    get_descendants "$PARENT_PID"

    # Wait for 0.5 seconds before repeating
    sleep 0.5
done
