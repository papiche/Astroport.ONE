#!/bin/bash

# Input longitude in degrees (positive for East, negative for West)
longitude=$1

# Check if longitude is numeric
if ! [[ $longitude =~ ^[+-]?[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid longitude input. Please provide a valid numeric value."
  exit 1
fi

# Determine if it's East or West longitude
if [ $(echo "$longitude >= 0" | bc) -eq 1 ]; then
  direction="East"
else
  direction="West"
fi

# Calculate the time offset in minutes using awk for floating-point arithmetic
offset_minutes=$(echo "$longitude * 4" | bc)

# Determine if it's ahead or behind UTC
if [ "$direction" == "West" ]; then
  offset_minutes=$(echo "$offset_minutes * -1" | bc)
fi

# Calculate the solar noon time in UTC (12:00 PM)
solar_noon_utc_seconds=$((12 * 3600))

# Adjust the solar noon time by the offset in seconds
local_solar_noon_seconds=$(echo "$solar_noon_utc_seconds + ( $offset_minutes * 60 )" | bc | cut -d '.' -f 1)

# Convert the local solar noon time to hours, minutes, and seconds
local_solar_noon_time=$(date -u -d "@$local_solar_noon_seconds" +%H:%M:%S)

# Add 8 hours and 12 minutes to the local solar noon time
new_time_seconds=$((local_solar_noon_seconds + 8*3600 + 12*60))
new_time=$(date -u -d "@$new_time_seconds" +%H:%M:%S)

echo "Longitude: $longitude degrees $direction"
echo "Time Offset: $offset_minutes minutes"
echo "Local Solar Noon (midday) Time: $local_solar_noon_time"
echo "Local Solar Noon + 8h 12mn: $new_time"
