#!/bin/bash

# Input longitude in degrees (positive for East, negative for West)
longitude_deg=$1

# Determine if it's East or West longitude
if [ $longitude_deg -ge 0 ]; then
  direction="East"
else
  direction="West"
fi

# Calculate the time offset in minutes
offset_minutes=$((longitude_deg * 4))

# Determine if it's ahead or behind UTC
if [ "$direction" == "West" ]; then
  offset_minutes=$((offset_minutes * -1))
fi

# Get the current UTC time in hours, minutes, and seconds
current_utc_time=$(date -u +%H:%M:%S)

# Convert the UTC time to seconds since midnight
current_utc_seconds=$(date -u -d "$current_utc_time" +%s)

# Calculate the solar noon time in UTC (12:00 PM)
solar_noon_utc_seconds=$((12 * 3600))

# Adjust the solar noon time by the offset in seconds
local_solar_noon_seconds=$((solar_noon_utc_seconds + offset_minutes * 60))

# Convert the local solar noon time to hours, minutes, and seconds
local_solar_noon_time=$(date -u -d "@$local_solar_noon_seconds" +%H:%M:%S)

# Add 8 hours and 12 minutes to the local solar noon time
new_time_seconds=$((local_solar_noon_seconds + 8*3600 + 12*60))
new_time=$(date -u -d "@$new_time_seconds" +%H:%M:%S)

echo "Longitude: $longitude_deg degrees $direction"
echo "Time Offset: $offset_minutes minutes"
echo "Local Solar Noon (midday) Time: $local_solar_noon_time"
echo "Local Solar Noon + 8h 12mn: $new_time"
