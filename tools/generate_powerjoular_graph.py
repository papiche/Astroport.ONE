#!/usr/bin/env python3
########################################################################
# generate_powerjoular_graph.py
# Generate power consumption graph from PowerJoular CSV data
########################################################################

import sys
import csv
import os
from datetime import datetime
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

def parse_powerjoular_csv(csv_file):
    """Parse PowerJoular CSV file and extract power consumption data"""
    timestamps = []
    power_values = []
    cpu_power = []
    gpu_power = []
    
    if not os.path.exists(csv_file):
        print(f"ERROR: CSV file not found: {csv_file}", file=sys.stderr)
        return None, None, None, None
    
    try:
        with open(csv_file, 'r') as f:
            # PowerJoular CSV format with -f (append mode):
            # timestamp,power,cpu_power,gpu_power
            # Format can vary: timestamp might be ISO format or Unix timestamp
            reader = csv.reader(f)
            for row in reader:
                if len(row) < 2:
                    continue
                
                try:
                    # Parse timestamp - PowerJoular uses ISO format: "YYYY-MM-DD HH:MM:SS"
                    ts_str = row[0].strip()
                    
                    # Try ISO format first (PowerJoular default)
                    try:
                        timestamp = datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S')
                    except ValueError:
                        # Try with microseconds
                        try:
                            timestamp = datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S.%f')
                        except ValueError:
                            # Fallback to Unix timestamp
                            if ts_str.replace('.', '').isdigit():
                                timestamp = datetime.fromtimestamp(float(ts_str))
                            else:
                                # Try ISO format with timezone
                                timestamp = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                    
                    # Parse power values
                    power = float(row[1].strip())
                    
                    timestamps.append(timestamp)
                    power_values.append(power)
                    
                    # Parse CPU and GPU power if available
                    if len(row) >= 3:
                        cpu_val = row[2].strip()
                        cpu_power.append(float(cpu_val) if cpu_val else 0.0)
                    else:
                        cpu_power.append(power)  # Use total power as CPU if not separated
                    
                    if len(row) >= 4:
                        gpu_val = row[3].strip()
                        gpu_power.append(float(gpu_val) if gpu_val else 0.0)
                    else:
                        gpu_power.append(0.0)
                        
                except (ValueError, IndexError) as e:
                    continue  # Skip invalid rows
        
        if not timestamps:
            print(f"ERROR: No valid data found in CSV file: {csv_file}", file=sys.stderr)
            return None, None, None, None
            
        return timestamps, power_values, cpu_power, gpu_power
        
    except Exception as e:
        print(f"ERROR: Failed to parse CSV file: {e}", file=sys.stderr)
        return None, None, None, None

def generate_graph(csv_file, output_file, title="Power Consumption"):
    """Generate power consumption graph from CSV data"""
    timestamps, power_values, cpu_power, gpu_power = parse_powerjoular_csv(csv_file)
    
    if timestamps is None:
        return False
    
    # Create figure with subplots
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
    
    # Plot 1: Total power consumption over time
    ax1.plot(timestamps, power_values, 'b-', linewidth=2, label='Total Power')
    ax1.fill_between(timestamps, power_values, alpha=0.3, color='blue')
    ax1.set_ylabel('Power (W)', fontsize=12, fontweight='bold')
    ax1.set_title(f'{title} - Total Power Consumption', fontsize=14, fontweight='bold')
    ax1.grid(True, alpha=0.3)
    ax1.legend(loc='upper right')
    
    # Calculate and display statistics
    avg_power = sum(power_values) / len(power_values)
    max_power = max(power_values)
    min_power = min(power_values)
    
    # Calculate total energy (integral of power over time)
    total_energy_joules = 0.0
    for i in range(1, len(timestamps)):
        dt = (timestamps[i] - timestamps[i-1]).total_seconds()
        avg_power_interval = (power_values[i] + power_values[i-1]) / 2.0
        total_energy_joules += avg_power_interval * dt
    
    total_energy_kwh = total_energy_joules / 3600000.0  # Convert Joules to kWh
    
    # Add statistics text box
    stats_text = f'Average: {avg_power:.2f} W\nMax: {max_power:.2f} W\nMin: {min_power:.2f} W\nTotal Energy: {total_energy_kwh:.4f} kWh'
    ax1.text(0.02, 0.98, stats_text, transform=ax1.transAxes, 
             fontsize=10, verticalalignment='top',
             bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    # Plot 2: CPU and GPU power breakdown (if available)
    if any(gpu_power):
        ax2.plot(timestamps, cpu_power, 'g-', linewidth=2, label='CPU Power', alpha=0.7)
        ax2.plot(timestamps, gpu_power, 'r-', linewidth=2, label='GPU Power', alpha=0.7)
        ax2.set_ylabel('Power (W)', fontsize=12, fontweight='bold')
        ax2.set_title('CPU and GPU Power Breakdown', fontsize=14, fontweight='bold')
        ax2.legend(loc='upper right')
    else:
        ax2.plot(timestamps, cpu_power, 'g-', linewidth=2, label='CPU Power', alpha=0.7)
        ax2.set_ylabel('Power (W)', fontsize=12, fontweight='bold')
        ax2.set_title('CPU Power Consumption', fontsize=14, fontweight='bold')
        ax2.legend(loc='upper right')
    
    ax2.grid(True, alpha=0.3)
    
    # Format x-axis
    ax2.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M:%S'))
    ax2.xaxis.set_major_locator(mdates.MinuteLocator(interval=max(1, len(timestamps)//10)))
    plt.setp(ax2.xaxis.get_majorticklabels(), rotation=45, ha='right')
    
    # Set x-axis label
    ax2.set_xlabel('Time', fontsize=12, fontweight='bold')
    
    # Add overall title
    fig.suptitle(f'{title} - {timestamps[0].strftime("%Y-%m-%d %H:%M")} to {timestamps[-1].strftime("%H:%M")}', 
                 fontsize=16, fontweight='bold', y=0.995)
    
    # Adjust layout
    plt.tight_layout()
    
    # Save figure
    try:
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
        plt.close()
        print(f"Graph generated successfully: {output_file}")
        print(f"Statistics: Avg={avg_power:.2f}W, Max={max_power:.2f}W, Min={min_power:.2f}W, Energy={total_energy_kwh:.4f}kWh")
        return True
    except Exception as e:
        print(f"ERROR: Failed to save graph: {e}", file=sys.stderr)
        plt.close()
        return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: generate_powerjoular_graph.py <input_csv> <output_image> [title]", file=sys.stderr)
        sys.exit(1)
    
    csv_file = sys.argv[1]
    output_file = sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else "Power Consumption"
    
    success = generate_graph(csv_file, output_file, title)
    sys.exit(0 if success else 1)
