#!/bin/bash

echo "Press any key to stop recording..."

# Start recording in the background and save as audio.wav
rec -r 44100 -c 2 $1 > /dev/null 2> /dev/null &

# Get the process ID of the recording
pid=$!

# Wait for a key press
read -n 1 -s

# Stop the recording by killing the process
kill $pid

echo "Recording stopped. Audio saved as audio.wav"
sleep 1
