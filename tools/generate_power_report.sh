#!/bin/bash
########################################################################
# generate_power_report.sh
# Generate HTML report with power consumption graph (generic version)
# 
# Usage: generate_power_report.sh <csv_file> <graph_file> <log_file> <output_html> <hostname> <duration> [title]
########################################################################

set -euo pipefail

CSV_FILE="$1"
GRAPH_FILE="$2"
LOG_FILE="$3"
OUTPUT_HTML="$4"
HOSTNAME="${5:-$(hostname -f)}"
DURATION="${6:-}"
REPORT_TITLE="${7:-Power Consumption Report}"

# Check if graph exists, if not generate it
if [[ ! -f "$GRAPH_FILE" ]] && [[ -f "$CSV_FILE" ]] && command -v python3 >/dev/null 2>&1; then
    MY_PATH="$(dirname "$0")"
    MY_PATH="$(cd "$MY_PATH" && pwd)"
    python3 "${MY_PATH}/generate_powerjoular_graph.py" \
        "$CSV_FILE" \
        "$GRAPH_FILE" \
        "$REPORT_TITLE - $HOSTNAME" 2>/dev/null || true
fi

# Convert graph to base64 if it exists
GRAPH_BASE64=""
if [[ -f "$GRAPH_FILE" ]]; then
    GRAPH_BASE64=$(base64 -w 0 "$GRAPH_FILE" 2>/dev/null || base64 "$GRAPH_FILE" 2>/dev/null || echo "")
fi

# Extract power statistics from CSV if available
POWER_STATS=""
if [[ -f "$CSV_FILE" ]] && command -v awk >/dev/null 2>&1; then
    avg_power=$(awk -F',' 'NR>0 {sum+=$2; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE" 2>/dev/null || echo "0")
    max_power=$(awk -F',' 'NR>0 {if($2>max || NR==1) max=$2} END {printf "%.2f", max}' "$CSV_FILE" 2>/dev/null || echo "0")
    min_power=$(awk -F',' 'NR>0 {if($2<min || NR==1) min=$2} END {printf "%.2f", min}' "$CSV_FILE" 2>/dev/null || echo "0")
    
    if [[ "$avg_power" != "0" ]]; then
        POWER_STATS="<div style='background: #e8f4fd; padding: 15px; border-radius: 5px; margin: 15px 0;'>
            <h3>⚡ Power Consumption Statistics</h3>
            <p><strong>Average Power:</strong> ${avg_power} W</p>
            <p><strong>Maximum Power:</strong> ${max_power} W</p>
            <p><strong>Minimum Power:</strong> ${min_power} W</p>
            ${DURATION:+<p><strong>Duration:</strong> ${DURATION}</p>}
        </div>"
    fi
fi

# Generate HTML report
cat > "$OUTPUT_HTML" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$REPORT_TITLE - Power Consumption</title>
    <style>
        body { 
            font-family: 'Courier New', monospace; 
            background: #f5f5f5; 
            margin: 0;
            padding: 20px;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto; 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .header { 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
            color: white; 
            padding: 20px; 
            border-radius: 8px 8px 0 0; 
            margin: -20px -20px 20px -20px; 
        }
        .header h1 { margin: 0; }
        .content { padding: 20px 0; }
        .graph-container {
            text-align: center;
            margin: 20px 0;
            padding: 20px;
            background: #fafafa;
            border-radius: 5px;
        }
        .graph-container img {
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .log-section {
            background: #f9f9f9;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
            max-height: 600px;
            overflow-y: auto;
        }
        .log-section pre {
            margin: 0;
            font-size: 11px;
            line-height: 1.4;
        }
        .footer { 
            margin-top: 20px; 
            padding-top: 15px; 
            border-top: 1px solid #eee; 
            font-size: 12px; 
            color: #666; 
        }
        .stats-box {
            background: #e8f4fd;
            padding: 15px;
            border-radius: 5px;
            margin: 15px 0;
        }
        .stats-box h3 { margin-top: 0; }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>⚡ $REPORT_TITLE</h1>
        <p>Power Consumption Analysis - $HOSTNAME</p>
        <p>Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
    </div>
    <div class="content">
        $POWER_STATS
        $([ -n "$GRAPH_BASE64" ] && echo "<div class='graph-container'>
            <h2>📊 Power Consumption Graph</h2>
            <img src='data:image/png;base64,$GRAPH_BASE64' alt='Power Consumption Graph' />
        </div>")
        $([ -f "$LOG_FILE" ] && [[ "$LOG_FILE" != "/dev/null" ]] && echo "<div class='log-section'>
            <h3>📋 Execution Log</h3>
            <pre>$(head -500 "$LOG_FILE" | sed 's/</\&lt;/g; s/>/\&gt;/g')</pre>
        </div>")
    </div>
    <div class="footer">
        <p>This report was generated automatically by Astroport.ONE power monitoring system.</p>
        <p>Power monitoring powered by <a href='https://www.noureddine.org/research/joular/powerjoular' target='_blank'>PowerJoular</a></p>
    </div>
</div>
</body>
</html>
EOF

echo "HTML report generated: $OUTPUT_HTML"
