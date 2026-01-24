# Power Consumption Monitoring System

## Overview

The Power Monitoring system provides a generic, reusable interface for measuring and reporting power consumption of processes using PowerJoular. It can be integrated into any script to track energy usage during execution.

**Important:** Files are stored in `/tmp/` by default (not `~/.zen/tmp/`) to avoid cleanup by scripts like `20h12.process.sh` which clean `~/.zen/tmp/` during execution. This ensures monitoring data persists throughout script execution.

## Components

### 1. `tools/power_monitor.sh` - Generic Monitoring Wrapper

Main script that provides a unified interface for power monitoring operations.

**Commands:**
- `start [csv_file] [pid_file]` - Start power monitoring
- `stop [pid_file]` - Stop power monitoring
- `status [pid_file]` - Get monitoring status
- `report <csv_file> <output_html> [title] [log_file] [hostname] [duration]` - Generate HTML report

### 2. `tools/generate_powerjoular_graph.py` - Graph Generator

Python script that generates power consumption graphs from CSV data using matplotlib.

### 3. `tools/generate_power_report.sh` - HTML Report Generator

Generates comprehensive HTML reports with embedded graphs and statistics. Generic version that accepts a custom report title.

## Usage

### Basic Usage

```bash
#!/bin/bash
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Start monitoring (PID file auto-derived from CSV)
MONITOR_OUTPUT=$("${MY_PATH}/tools/power_monitor.sh" start)
if [[ $? -eq 0 ]]; then
    PID=$(echo "$MONITOR_OUTPUT" | head -1)
    CSV=$(echo "$MONITOR_OUTPUT" | tail -1)
    echo "Monitoring started: PID=$PID, CSV=$CSV"
    
    # Your process here...
    sleep 60
    
    # Stop monitoring (using CSV file, PID file auto-detected)
    "${MY_PATH}/tools/power_monitor.sh" stop "$CSV"
    
    # Generate report
    "${MY_PATH}/tools/power_monitor.sh" report \
        "$CSV" \
        "power_report.html" \
        "My Process" \
        "process.log" \
        "$(hostname -f)" \
        "1m"
fi
```

### Advanced Usage with Custom CSV File

```bash
#!/bin/bash
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Custom CSV file (PID file automatically derived: my_process_power.pid)
CUSTOM_CSV="my_process_power.csv"

# Start with custom CSV (stored in /tmp/ by default to avoid cleanup)
"${MY_PATH}/tools/power_monitor.sh" start "$CUSTOM_CSV"

# Do your work...
your_script.sh

# Stop monitoring (using CSV file)
"${MY_PATH}/tools/power_monitor.sh" stop "$CUSTOM_CSV"

# Generate report
"${MY_PATH}/tools/power_monitor.sh" report \
    "$CUSTOM_CSV" \
    "my_report.html" \
    "Custom Process Report"
```

**Note:** 
- PID files are automatically derived from CSV files (same path with `.pid` extension). No need to manage them manually.

### Integration in Existing Scripts

#### Example 1: Simple Integration

```bash
#!/bin/bash
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Start monitoring at script start (PID file auto-derived)
POWER_CSV="my_script_power.csv"
"${MY_PATH}/tools/power_monitor.sh" start "$POWER_CSV" >/dev/null 2>&1

# Trap to ensure monitoring stops on exit
cleanup() {
    "${MY_PATH}/tools/power_monitor.sh" stop "$POWER_CSV" >/dev/null 2>&1
}
trap cleanup EXIT INT TERM

# Your script logic here...
echo "Running main process..."
sleep 30

# Generate report before exit
"${MY_PATH}/tools/power_monitor.sh" report \
    "$POWER_CSV" \
    "my_script_report.html" \
    "My Script Power Report" \
    "" \
    "$(hostname -f)" \
    "30s"
```

#### Example 2: With Error Handling

```bash
#!/bin/bash
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

POWER_CSV="process_power.csv"
POWER_REPORT="process_report.html"

# Start monitoring (PID file auto-derived)
if "${MY_PATH}/tools/power_monitor.sh" start "$POWER_CSV" >/dev/null 2>&1; then
    echo "Power monitoring started"
    
    # Ensure cleanup on exit
    cleanup() {
        "${MY_PATH}/tools/power_monitor.sh" stop "$POWER_CSV" >/dev/null 2>&1
        
        # Generate report if CSV has data
        if [[ -f "/tmp/$POWER_CSV" ]] && [[ -s "/tmp/$POWER_CSV" ]]; then
            "${MY_PATH}/tools/power_monitor.sh" report \
                "$POWER_CSV" \
                "$POWER_REPORT" \
                "Process Power Report" \
                "" \
                "$(hostname -f)" \
                "" >/dev/null 2>&1
        fi
    }
    trap cleanup EXIT INT TERM
    
    # Main process
    main_process
    
    exit_code=$?
    
    # Generate report
    "${MY_PATH}/tools/power_monitor.sh" report \
        "$POWER_CSV" \
        "$POWER_REPORT" \
        "Process Power Report" \
        "" \
        "$(hostname -f)" \
        ""
    
    exit $exit_code
else
    echo "Warning: Failed to start power monitoring"
    # Continue without monitoring
    main_process
fi
```

## CSV Format

PowerJoular CSV format (with `-f` append mode):
```
timestamp,power,cpu_power,gpu_power
2026-01-24 22:40:52,0.47466666666667,8.27213500000653,8.27213500000653,0.00000000000000
2026-01-24 22:40:54,0.34316353887399,8.16117300000042,8.16117300000042,0.00000000000000
```

**Fields:**
- `timestamp`: ISO format timestamp (YYYY-MM-DD HH:MM:SS)
- `power`: Total power consumption (Watts)
- `cpu_power`: CPU power consumption (Watts)
- `gpu_power`: GPU power consumption (Watts) - may be 0 if no GPU

## Report Format

The generated HTML report includes:

1. **Power Statistics Box:**
   - Average Power (W)
   - Maximum Power (W)
   - Minimum Power (W)
   - Duration (if provided)

2. **Power Consumption Graph:**
   - Total power over time (line chart with fill)
   - CPU/GPU breakdown (if available)
   - Statistics overlay

3. **Execution Log:**
   - Process log file content (if provided)
   - Formatted for readability

## Requirements

### System Requirements

- **PowerJoular**: Must be installed and available in PATH
  - Installation: `~/.zen/Astroport.ONE/tools/install_powerjoular.sh`
  - Requires: GNAT compiler, gprbuild
  - Supports: Intel RAPL, AMD Ryzen/EPYC, Raspberry Pi, Asus Tinker Board

### Python Requirements

- **Python 3** with:
  - `matplotlib` (for graph generation)
  - Standard library: `csv`, `datetime`, `os`, `sys`

Install dependencies:
```bash
pip install matplotlib
```

Or via Astroport.ONE install.sh (already included).

### Permissions

PowerJoular requires **root/sudo** access for RAPL monitoring on Linux kernels 5.10+:
```bash
sudo powerjoular
```

The `power_monitor.sh` script handles sudo automatically.

## API Reference

### `power_monitor.sh start [csv_file]`

Starts power monitoring. PID file is automatically derived from CSV file.

**Parameters:**
- `csv_file` (optional): Path to CSV output file (default: `/tmp/power_monitor_$$.csv`)
  - If relative path, stored in `/tmp/` (to avoid cleanup by scripts that clean `~/.zen/tmp/`)
  - PID file automatically created as `{csv_file%.csv}.pid`

**Returns:**
- Exit code: 0 on success, 1 on failure
- Stdout: PID on first line, CSV path on second line (if successful)

**Example:**
```bash
OUTPUT=$("${MY_PATH}/tools/power_monitor.sh" start "my_process.csv")
PID=$(echo "$OUTPUT" | head -1)
CSV=$(echo "$OUTPUT" | tail -1)
# PID file automatically created as /tmp/my_process.pid
```

### `power_monitor.sh stop [csv_file]`

Stops power monitoring. Can use CSV file (PID file auto-detected) or omit for default.

**Parameters:**
- `csv_file` (optional): CSV file path (PID file auto-derived) or omit for default

**Returns:**
- Exit code: 0 on success

**Example:**
```bash
# Stop using CSV file
"${MY_PATH}/tools/power_monitor.sh" stop "my_process.csv"

# Stop default monitoring
"${MY_PATH}/tools/power_monitor.sh" stop
```

### `power_monitor.sh status [csv_file]`

Gets monitoring status. Can use CSV file (PID file auto-detected) or omit for default.

**Parameters:**
- `csv_file` (optional): CSV file path (PID file auto-derived) or omit for default

**Returns:**
- `RUNNING:PID` if monitoring is active
- `NOT_RUNNING` if not active

**Example:**
```bash
STATUS=$("${MY_PATH}/tools/power_monitor.sh" status "my_process.csv")
if [[ "$STATUS" == RUNNING:* ]]; then
    PID="${STATUS#RUNNING:}"
    echo "Monitoring active: PID=$PID"
fi
```

### `power_monitor.sh report <csv_file> <output_html> [title] [log_file] [hostname] [duration]`

Generates HTML report with power consumption graph.

**Parameters:**
- `csv_file` (required): Path to PowerJoular CSV file
- `output_html` (required): Path to output HTML file
- `title` (optional): Report title (default: "Power Consumption Report")
- `log_file` (optional): Path to process log file to include
- `hostname` (optional): Hostname for report (default: `$(hostname -f)`)
- `duration` (optional): Process duration string (e.g., "1h 30m 15s")

**Returns:**
- Exit code: 0 on success, 1 on failure

**Example:**
```bash
"${MY_PATH}/tools/power_monitor.sh" report \
    "/tmp/power.csv" \
    "/tmp/report.html" \
    "My Process Report" \
    "/tmp/process.log" \
    "server.example.com" \
    "2h 15m"
```

## Integration Examples

### In 20h12.process.sh

The `20h12.process.sh` script demonstrates full integration:

```bash
# Start monitoring (PID file auto-derived)
# Use /tmp/ to avoid cleanup by 20h12.process.sh which cleans ~/.zen/tmp/
POWER_CSV="/tmp/20h12_power_consumption.csv"
"${MY_PATH}/tools/power_monitor.sh" start "$POWER_CSV"

# ... script execution ...

# Stop and generate report (using CSV file, PID file auto-detected)
"${MY_PATH}/tools/power_monitor.sh" stop "$POWER_CSV"
"${MY_PATH}/tools/power_monitor.sh" report \
    "$POWER_CSV" \
    "/tmp/20h12_power_report.html" \
    "20H12 Process Power Consumption" \
    "/tmp/20h12.log" \
    "$(hostname -f)" \
    "${hours}h ${minutes}m ${seconds}s"
```

### In Custom Scripts

```bash
#!/bin/bash
# my_custom_script.sh

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Setup power monitoring (PID file auto-derived)
POWER_CSV="my_script_power.csv"

if "${MY_PATH}/tools/power_monitor.sh" start "$POWER_CSV" >/dev/null 2>&1; then
    # Cleanup function
    cleanup() {
        "${MY_PATH}/tools/power_monitor.sh" stop "$POWER_CSV" >/dev/null 2>&1
    }
    trap cleanup EXIT
    
    # Your script logic
    echo "Running process..."
    sleep 60
    
    # Generate report
    "${MY_PATH}/tools/power_monitor.sh" report \
        "$POWER_CSV" \
        "my_script_report.html" \
        "My Script Power Report"
else
    echo "Warning: Power monitoring unavailable"
fi
```

## Troubleshooting

### PowerJoular Not Found

**Error:** `PowerJoular is not available`

**Solution:**
```bash
~/.zen/Astroport.ONE/tools/install_powerjoular.sh
```

### Permission Denied

**Error:** `sudo: a password is required`

**Solution:** Ensure the script has sudo access or run with appropriate permissions. PowerJoular requires root for RAPL access.

### No Data in CSV

**Issue:** CSV file exists but has only 1 line or is empty

**Possible causes:**
- Monitoring started but stopped too quickly
- PowerJoular failed to initialize
- Insufficient permissions

**Solution:** Check PowerJoular logs and ensure monitoring runs for at least a few seconds.

### Graph Generation Fails

**Error:** `Python3 or generate_powerjoular_graph.py not available`

**Solution:**
```bash
pip install matplotlib
```

Or ensure matplotlib is installed via Astroport.ONE install.sh.

### Report Generation Fails

**Error:** `generate_power_report.sh not found`

**Solution:** Ensure all scripts are in `tools/` directory and paths are correct.

## Best Practices

1. **Always use cleanup traps:**
   ```bash
   cleanup() {
       "${MY_PATH}/tools/power_monitor.sh" stop "$POWER_CSV" >/dev/null 2>&1
   }
   trap cleanup EXIT INT TERM
   ```

2. **Use CSV file for stop/status (PID file auto-detected):**
   ```bash
   # Start
   "${MY_PATH}/tools/power_monitor.sh" start "$POWER_CSV"
   
   # Stop (using CSV, PID file auto-detected)
   "${MY_PATH}/tools/power_monitor.sh" stop "$POWER_CSV"
   ```

3. **Check monitoring status before generating reports:**
   ```bash
   # Files are in /tmp/ by default (not ~/.zen/tmp/)
   if [[ -f "/tmp/$POWER_CSV" ]] && [[ -s "/tmp/$POWER_CSV" ]]; then
       # Generate report
   fi
   ```

4. **Use descriptive titles for reports:**
   ```bash
   "${MY_PATH}/tools/power_monitor.sh" report \
       "$CSV" \
       "$OUTPUT" \
       "Descriptive Process Name - $(date +%Y-%m-%d)"
   ```

5. **Include log files when available:**
   ```bash
   "${MY_PATH}/tools/power_monitor.sh" report \
       "$CSV" \
       "$OUTPUT" \
       "Process Report" \
       "/var/log/process.log"
   ```

6. **Handle monitoring failures gracefully:**
   ```bash
   if ! "${MY_PATH}/tools/power_monitor.sh" start "$POWER_CSV"; then
       echo "Warning: Power monitoring unavailable, continuing without it"
   fi
   ```

7. **No need to manage PID files manually:**
   - PID files are automatically derived from CSV files
   - All files stored in `/tmp/` by default to avoid cleanup by scripts that clean `~/.zen/tmp/`
   - Just use the CSV file for all operations

## References

- **PowerJoular Documentation:** https://www.noureddine.org/research/joular/powerjoular
- **PowerJoular GitHub:** https://github.com/papiche/powerjoular
- **Installation Script:** `tools/install_powerjoular.sh`
- **Example Integration:** `20h12.process.sh`

## License

AGPL-3.0 (same as Astroport.ONE)
