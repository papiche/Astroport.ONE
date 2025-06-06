#!/bin/bash
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

# Check if a question was provided
if [ $# -eq 0 ]; then
    echo "Error: No question provided."
    echo "Usage: $0 \"Your question here\""
    exit 1
fi

# API endpoint
API_URL="http://localhost:3001/api/search"

# Get the question from command line arguments
QUESTION="$*"

# JSON payload for the API request
JSON_PAYLOAD=$(cat <<EOF
{
  "chatModel": {
    "provider": "ollama",
    "name": "gemma3:latest"
  },
  "embeddingModel": {
    "provider": "ollama",
    "name": "nomic-embed-text:latest"
  },
  "optimizationMode": "balanced",
  "focusMode": "webSearch",
  "query": "$QUESTION",
  "systemInstructions": "# INSTRUCTIONS: ## 1. Reply in the same language as the message. ## 2. Do NOT use any markdown : i.e. NO **bold** format ! ## 3. Use emojis to make your message more readable.",
  "stream": false
}
EOF
)

# Make the API request
RESPONSE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

# Check if curl command succeeded
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to the Search API."
    echo "Make sure the server is running at $API_URL"
    exit 1
fi

# Check for API errors
ERROR=$(echo "$RESPONSE" | jq -r '.error')
if [ "$ERROR" != "null" ]; then
    echo "API Error: $ERROR"
    exit 1
fi

# Extract and display the message
MESSAGE=$(echo "$RESPONSE" | jq -r '.message')
echo -e "$MESSAGE"

# Extract and display sources
SOURCES=$(echo "$RESPONSE" | jq -r '.sources')
if [ "$SOURCES" != "null" ] && [ "$SOURCES" != "[]" ]; then
    echo "$SOURCES" | jq -r '.[] | "\(.metadata.title)\n\(.metadata.url)\n"'
fi

exit 0
