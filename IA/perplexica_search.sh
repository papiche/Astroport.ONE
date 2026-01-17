#!/bin/bash
################################################################################
# perplexica_search.sh - Perplexica Search API Client
# 
# Compatible with Perplexica API (2024+)
# Dynamically discovers available providers and models
# Falls back to compatible models when specified model is unavailable
#
# Usage: ./perplexica_search.sh "Your question here" [language]
################################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

# Configuration
API_BASE="http://localhost:3001"
API_SEARCH="${API_BASE}/api/search"
API_PROVIDERS="${API_BASE}/api/providers"

# Preferred models (in order of preference - models with tools support)
PREFERRED_CHAT_MODELS=(
    "orieg/gemma3-tools:12b"
    "gemma3:12b"
    "qwen3:14b"
    "qwen3:8b"
    "mistral-nemo:latest"
    "llama3.2:latest"
    "gpt-4o-mini"
    "gpt-4o"
)

PREFERRED_EMBEDDING_MODELS=(
    "nomic-embed-text:latest"
    "text-embedding-3-large"
    "text-embedding-3-small"
)

# Check if a question was provided
if [ $# -eq 0 ]; then
    echo "Error: No question provided." >&2
    echo "Usage: $0 \"Your question here\" [language]" >&2
    exit 1
fi

# Get the question and optional language from command line arguments
QUESTION="$1"
USER_LANG="${2:-fr}"  # Default to French if no language provided

# Function to get system instructions based on language
get_system_instructions() {
    local lang="$1"
    case "$lang" in
        "fr")
            echo "# INSTRUCTIONS POUR ARTICLE DE BLOG : ## 1. CRITIQUE: Répondre UNIQUEMENT en français. ## 2. Formater comme un article de blog structuré avec: - Paragraphe d'introduction clair - Contenu principal organisé en sections logiques - Conclusion avec points clés ## 3. Utiliser les emojis stratégiquement pour améliorer la lisibilité ## 4. Inclure des faits, statistiques ou exemples pertinents ## 5. Écrire dans un ton engageant et informatif ## 6. IMPORTANT: Tout le contenu doit être en français ## 7. CRITIQUE: N'utiliser QUE les sources fournies, ne pas inventer de références"
            ;;
        "en")
            echo "# INSTRUCTIONS FOR BLOG ARTICLE : ## 1. CRITICAL: Respond ONLY in English. ## 2. Format as a structured blog article with: - Clear introduction paragraph - Main content organized in logical sections - Conclusion with key takeaways ## 3. Use emojis strategically to enhance readability ## 4. Include relevant facts, statistics, or examples ## 5. Write in an engaging, informative tone ## 6. IMPORTANT: All content must be in English ## 7. CRITICAL: Use ONLY the provided sources, do not invent references"
            ;;
        "es")
            echo "# INSTRUCCIONES PARA ARTÍCULO DE BLOG : ## 1. CRÍTICO: Responder ÚNICAMENTE en español. ## 2. Formatear como un artículo de blog estructurado con: - Párrafo de introducción claro - Contenido principal organizado en secciones lógicas - Conclusión con puntos clave ## 3. Usar emojis estratégicamente para mejorar la legibilidad ## 4. Incluir hechos, estadísticas o ejemplos relevantes ## 5. Escribir en un tono atractivo e informativo ## 6. IMPORTANTE: Todo el contenido debe estar en español ## 7. CRÍTICO: Usar SOLO las fuentes proporcionadas, no inventar referencias"
            ;;
        "de")
            echo "# ANWEISUNGEN FÜR BLOG-ARTIKEL : ## 1. KRITISCH: Nur auf Deutsch antworten. ## 2. Als strukturierter Blog-Artikel formatieren mit: - Klarem Einführungsparagraphen - Hauptinhalt in logischen Abschnitten organisiert - Fazit mit wichtigen Erkenntnissen ## 3. Emojis strategisch zur Verbesserung der Lesbarkeit verwenden ## 4. Relevante Fakten, Statistiken oder Beispiele einbeziehen ## 5. In einem ansprechenden, informativen Ton schreiben ## 6. WICHTIG: Alle Inhalte müssen auf Deutsch sein ## 7. KRITISCH: Nur die bereitgestellten Quellen verwenden, keine Referenzen erfinden"
            ;;
        "it")
            echo "# ISTRUZIONI PER ARTICOLO DI BLOG : ## 1. CRITICO: Rispondere SOLO in italiano. ## 2. Formattare come un articolo di blog strutturato con: - Paragrafo introduttivo chiaro - Contenuto principale organizzato in sezioni logiche - Conclusione con punti chiave ## 3. Usare emoji strategicamente per migliorare la leggibilità ## 4. Includere fatti, statistiche o esempi rilevanti ## 5. Scrivere in un tono coinvolgente e informativo ## 6. IMPORTANTE: Tutto il contenuto deve essere in italiano ## 7. CRITICO: Usare SOLO le fonti fornite, non inventare riferimenti"
            ;;
        *)
            echo "# INSTRUCTIONS FOR BLOG ARTICLE : ## 1. CRITICAL: Respond ONLY in ${lang} language. ## 2. Format as a structured blog article with: - Clear introduction paragraph - Main content organized in logical sections - Conclusion with key takeaways ## 3. Use emojis strategically to enhance readability ## 4. Include relevant facts, statistics, or examples ## 5. Write in an engaging, informative tone ## 6. IMPORTANT: All content must be in ${lang} language ## 7. CRITICAL: Use ONLY the provided sources, do not invent references"
            ;;
    esac
}

# Function to fetch available providers and models
fetch_providers() {
    echo "Fetching available providers from Perplexica API..." >&2
    local response
    response=$(curl -s --connect-timeout 10 "${API_PROVIDERS}")
    
    if [ $? -ne 0 ] || [ -z "$response" ]; then
        echo "Error: Failed to fetch providers from ${API_PROVIDERS}" >&2
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        echo "Error: Invalid JSON response from providers API" >&2
        echo "Response: $response" >&2
        return 1
    fi
    
    echo "$response"
}

# Function to find best matching chat model
find_chat_model() {
    local providers_json="$1"
    
    # Iterate through preferred models
    for preferred_model in "${PREFERRED_CHAT_MODELS[@]}"; do
        # Search in all providers' chatModels - use limit to get only first match
        local result
        result=$(echo "$providers_json" | jq -c --arg model "$preferred_model" '
            [.providers[]? | 
            select(.chatModels[]?.key == $model or .chatModels[]?.name == $model) |
            {
                providerId: .id,
                providerName: .name,
                modelKey: (.chatModels[] | select(.key == $model or .name == $model) | .key)
            }] | first // empty
        ' 2>/dev/null)
        
        if [ -n "$result" ] && [ "$result" != "null" ] && [ "$result" != "" ]; then
            echo "Found chat model: $preferred_model" >&2
            echo "$result"
            return 0
        fi
    done
    
    # Fallback: get first available chat model from any provider
    echo "No preferred chat model found, using first available..." >&2
    local fallback
    fallback=$(echo "$providers_json" | jq -c '
        [.providers[]? | select(.chatModels | length > 0)] | first |
        {
            providerId: .id,
            providerName: .name,
            modelKey: .chatModels[0].key
        }
    ' 2>/dev/null)
    
    if [ -n "$fallback" ] && [ "$fallback" != "null" ] && [ "$fallback" != "" ]; then
        echo "$fallback"
        return 0
    fi
    
    echo "Error: No chat models available" >&2
    return 1
}

# Function to find best matching embedding model
find_embedding_model() {
    local providers_json="$1"
    
    # Iterate through preferred embedding models
    for preferred_model in "${PREFERRED_EMBEDDING_MODELS[@]}"; do
        local result
        result=$(echo "$providers_json" | jq -c --arg model "$preferred_model" '
            [.providers[]? | 
            select(.embeddingModels[]?.key == $model or .embeddingModels[]?.name == $model) |
            {
                providerId: .id,
                providerName: .name,
                modelKey: (.embeddingModels[] | select(.key == $model or .name == $model) | .key)
            }] | first // empty
        ' 2>/dev/null)
        
        if [ -n "$result" ] && [ "$result" != "null" ] && [ "$result" != "" ]; then
            echo "Found embedding model: $preferred_model" >&2
            echo "$result"
            return 0
        fi
    done
    
    # Fallback: get first available embedding model from any provider
    echo "No preferred embedding model found, using first available..." >&2
    local fallback
    fallback=$(echo "$providers_json" | jq -c '
        [.providers[]? | select(.embeddingModels | length > 0)] | first |
        {
            providerId: .id,
            providerName: .name,
            modelKey: .embeddingModels[0].key
        }
    ' 2>/dev/null)
    
    if [ -n "$fallback" ] && [ "$fallback" != "null" ] && [ "$fallback" != "" ]; then
        echo "$fallback"
        return 0
    fi
    
    echo "Error: No embedding models available" >&2
    return 1
}

# Get system instructions based on language
SYSTEM_INSTRUCTIONS=$(get_system_instructions "$USER_LANG")
echo "Using language: $USER_LANG" >&2

# Fetch providers
PROVIDERS_JSON=$(fetch_providers)
if [ $? -ne 0 ]; then
    echo "Error: Could not fetch providers. Is Perplexica running?" >&2
    exit 1
fi

# Debug: Show available providers
echo "Available providers:" >&2
echo "$PROVIDERS_JSON" | jq -r '.providers[]? | "  - \(.name): \(.chatModels | length) chat models, \(.embeddingModels | length) embedding models"' 2>/dev/null >&2

# Find best chat model
CHAT_MODEL_INFO=$(find_chat_model "$PROVIDERS_JSON")
if [ $? -ne 0 ] || [ -z "$CHAT_MODEL_INFO" ]; then
    echo "Error: Could not find a suitable chat model" >&2
    exit 1
fi

CHAT_PROVIDER_ID=$(echo "$CHAT_MODEL_INFO" | jq -r '.providerId')
CHAT_MODEL_KEY=$(echo "$CHAT_MODEL_INFO" | jq -r '.modelKey')
echo "Selected chat model: $CHAT_MODEL_KEY (provider: $CHAT_PROVIDER_ID)" >&2

# Find best embedding model
EMBED_MODEL_INFO=$(find_embedding_model "$PROVIDERS_JSON")
if [ $? -ne 0 ] || [ -z "$EMBED_MODEL_INFO" ]; then
    echo "Error: Could not find a suitable embedding model" >&2
    exit 1
fi

EMBED_PROVIDER_ID=$(echo "$EMBED_MODEL_INFO" | jq -r '.providerId')
EMBED_MODEL_KEY=$(echo "$EMBED_MODEL_INFO" | jq -r '.modelKey')
echo "Selected embedding model: $EMBED_MODEL_KEY (provider: $EMBED_PROVIDER_ID)" >&2

# Escape question and system instructions for JSON
QUESTION_ESCAPED=$(printf '%s' "$QUESTION" | jq -Rs '.')
SYSTEM_ESCAPED=$(printf '%s' "$SYSTEM_INSTRUCTIONS" | jq -Rs '.')

# Build JSON payload using new API format (Perplexica 2024+)
JSON_PAYLOAD=$(jq -n \
    --arg chat_provider "$CHAT_PROVIDER_ID" \
    --arg chat_key "$CHAT_MODEL_KEY" \
    --arg embed_provider "$EMBED_PROVIDER_ID" \
    --arg embed_key "$EMBED_MODEL_KEY" \
    --argjson query "$QUESTION_ESCAPED" \
    --argjson system "$SYSTEM_ESCAPED" \
    '{
        "chatModel": {
            "providerId": $chat_provider,
            "key": $chat_key
        },
        "embeddingModel": {
            "providerId": $embed_provider,
            "key": $embed_key
        },
        "optimizationMode": "balanced",
        "sources": ["web"],
        "query": $query,
        "systemInstructions": $system,
        "stream": false
    }')

echo "Sending search request to Perplexica..." >&2

# Make the API request
RESPONSE=$(curl -s -X POST "$API_SEARCH" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    --connect-timeout 30 \
    --max-time 120)

# Check if curl command succeeded
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to the Search API at $API_SEARCH" >&2
    echo "Make sure Perplexica server is running and accessible" >&2
    exit 1
fi

# Check if response is empty
if [ -z "$RESPONSE" ]; then
    echo "Error: Empty response from API" >&2
    exit 1
fi

# Check if response is valid JSON
if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON response from API" >&2
    echo "Response: $RESPONSE" >&2
    exit 1
fi

# Check for API errors
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR" ] && [ "$ERROR" != "null" ]; then
    echo "API Error: $ERROR" >&2
    # Show more details if available
    DETAILS=$(echo "$RESPONSE" | jq -r '.details // empty')
    if [ -n "$DETAILS" ] && [ "$DETAILS" != "null" ]; then
        echo "Details: $DETAILS" >&2
    fi
    exit 1
fi

# Extract and display the message
MESSAGE=$(echo "$RESPONSE" | jq -r '.message // empty')
if [ -z "$MESSAGE" ] || [ "$MESSAGE" == "null" ]; then
    echo "Error: No message in response" >&2
    echo "Full response: $RESPONSE" >&2
    exit 1
fi

echo -e "$MESSAGE"

# Extract and display sources in numbered markdown link format
SOURCES=$(echo "$RESPONSE" | jq -r '.sources // []')
if [ "$SOURCES" != "null" ] && [ "$SOURCES" != "[]" ]; then
    SOURCES_COUNT=$(echo "$SOURCES" | jq 'length')
    if [ "$SOURCES_COUNT" -gt 0 ]; then
        echo ""
        echo "📚 Sources et références :"
        # Add sources with numbering, one per line
        echo "$SOURCES" | jq -r 'to_entries | .[] | "\(.key + 1). [\(.value.metadata.title // "Source")](\(.value.metadata.url // "#"))"'
    fi
fi

exit 0
