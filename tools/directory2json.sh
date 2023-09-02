#!/bin/bash
# This script will recursively scan the specified directory, producing a JSON output with filenames and their contents structured based on the directory hierarchy.

# Function to recursively scan a directory and produce JSON output
function scan_directory {
  local dir="$1"
  local output=""

  output+="{"  # Start of JSON object
  output+="\"$dir\": {"  # Start of directory object

  for file in "$dir"/*; do
    if [ -d "$file" ]; then
      # If it's a subdirectory, recursively scan it
      sub_output=$(scan_directory "$file")
      output+="$sub_output,"
    elif [ -f "$file" ]; then
      # If it's a file, add its content to the output
      filename=$(basename "$file")
      content=$(cat "$file")
      output+="\"$filename\": \"$content\","
    fi
  done

  # Remove the trailing comma if it exists
  output="${output%,}"

  output+="}"  # End of directory object
  output+="}"  # End of JSON object

  echo "$output"
}

# Check if a directory path is provided as an argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <directory_path>"
  exit 1
fi

directory="$1"

# Check if the provided path is a directory
if [ ! -d "$directory" ]; then
  echo "Error: The provided path is not a directory."
  exit 1
fi

# Call the scan_directory function with the specified directory
result=$(scan_directory "$directory")

# Print the JSON output
echo "$result"
