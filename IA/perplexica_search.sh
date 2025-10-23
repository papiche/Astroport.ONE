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
  "systemInstructions": "# INSTRUCTIONS FOR BLOG ARTICLE : ## 1. Reply in the same language as the message. ## 2. Format as a structured blog article with: - Clear introduction paragraph - Main content organized in logical sections - Conclusion with key takeaways ## 3. Use emojis strategically to enhance readability ## 4. Include relevant facts, statistics, or examples ## 5. Write in an engaging, informative tone",
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

# Extract and display sources in numbered markdown link format
SOURCES=$(echo "$RESPONSE" | jq -r '.sources')
if [ "$SOURCES" != "null" ] && [ "$SOURCES" != "[]" ]; then
    echo ""
    echo "📚 Sources et références :"
    # Add sources with numbering, one per line
    echo "$SOURCES" | jq -r 'to_entries | .[] | "\(.key + 1). [\(.value.metadata.title)](\(.value.metadata.url))"'
fi

exit 0
