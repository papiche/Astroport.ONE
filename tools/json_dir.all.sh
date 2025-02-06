#!/bin/bash
# Generate a manifest.json referencing all JSON files in the directory
DIR="$1"

# Check if the directory exists
if [[ ! -d "$DIR" ]]; then
    echo "Directory not found: $DIR"
    exit 1
fi

# Initialize an empty JSON array
manifest_array=()

# Loop through each *.rss.json file
for file in "$DIR"/*.rss.json; do
    # Check if the file is not empty and does not contain just []
    if [[ -s "$file" && "$(jq -e '. == []' "$file")" != "true" ]]; then
        # Get file metadata
        size=$(stat -c %s "$file")
        modified=$(stat -c %Y "$file")

        # Append JSON object to the array
        manifest_array+=("{\"filename\": \"$(basename "$file")\", \"size\": $size, \"modified\": $modified}")
    fi
done

# If no valid JSON files were found, exit gracefully
if [[ ${#manifest_array[@]} -eq 0 ]]; then
    echo "No valid JSON files found in $DIR"
    echo '{"files": []}' > "${DIR}/manifest.json"
    exit 0
fi

# Create the JSON manifest
echo "{\"files\": [$(IFS=,; echo "${manifest_array[*]}")]}" > "${DIR}/manifest.json"

echo "Manifest created: ${DIR}/manifest.json"
