#!/bin/bash
# GET AND COMBINE ALL JSON IN DIRECTORY
DIR="$1"

# Check if the directory exists
if [[ ! -d "$DIR" ]]; then
    echo "Directory not found: $DIR"
    exit 1
fi

## COMBINE ALL JSON
json_array=()
# Loop through each *.rss.json file and append its content to the array
for file in ${DIR}/*.rss.json; do
    # Check if the file is not empty and does not contain just []
    if [[ -s "$file" && "$(jq -e '. == []' "$file")" != "true" ]]; then
        # Use jq to extract the JSON array from each file
        data=$(jq '.' "$file")
        json_array+=("$data")
    fi
done

# If no valid JSON files were found, exit gracefully
if [[ ${#json_array[@]} -eq 0 ]]; then
    echo "No valid JSON files found in $DIR"
    exit 0
fi

temp_file=$(mktemp)
printf '%s\n' "${json_array[@]}" > "$temp_file"
# Use jq to read the array from the temporary file and create the merged JSON
jq -n --slurpfile array "$temp_file" '{"data": $array}' > "${DIR}/.all.json"
# Remove the temporary file
rm "$temp_file"

echo "Combined JSON saved to ${DIR}/.all.json"
