#!/bin/bash
# GET AND COMBINE ALL JSON IN DIRECTORY
DIR="$1"

## COMBINE ALL JSON
json_array=()
# Loop through each *.rss.json file and append its content to the array
for file in ${DIR}/*.rss.json; do
    # Use jq to extract the JSON array from each file
    data=$(jq '.' "$file")
    json_array+=("$data")
done
temp_file=$(mktemp)
printf '%s\n' "${json_array[@]}" > "$temp_file"
# Use jq to read the array from the temporary file and create the merged JSON
jq -n --slurpfile array "$temp_file" '{"data": $array}' > ${DIR}/.all.json
# Remove the temporary file
rm "$temp_file"
