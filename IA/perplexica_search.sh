#!/bin/bash
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

# Check if a question was provided
if [ $# -eq 0 ]; then
    echo "Error: No question provided."
    echo "Usage: $0 \"Your question here\" [language]"
    exit 1
fi

# API endpoint
API_URL="http://localhost:3001/api/search"

# Get the question and optional language from command line arguments
QUESTION="$1"
USER_LANG="${2:-fr}"  # Default to French if no language provided

# Function to get system instructions based on language
get_system_instructions() {
    local lang="$1"
    case "$lang" in
        "fr")
            echo "# INSTRUCTIONS POUR ARTICLE DE BLOG : ## 1. CRITIQUE: Répondre UNIQUEMENT en français. ## 2. Formater comme un article de blog structuré avec: - Paragraphe d'introduction clair - Contenu principal organisé en sections logiques - Conclusion avec points clés ## 3. Utiliser les emojis stratégiquement pour améliorer la lisibilité ## 4. Inclure des faits, statistiques ou exemples pertinents ## 5. Écrire dans un ton engageant et informatif ## 6. IMPORTANT: Tout le contenu doit être en français"
            ;;
        "en")
            echo "# INSTRUCTIONS FOR BLOG ARTICLE : ## 1. CRITICAL: Respond ONLY in English. ## 2. Format as a structured blog article with: - Clear introduction paragraph - Main content organized in logical sections - Conclusion with key takeaways ## 3. Use emojis strategically to enhance readability ## 4. Include relevant facts, statistics, or examples ## 5. Write in an engaging, informative tone ## 6. IMPORTANT: All content must be in English"
            ;;
        "es")
            echo "# INSTRUCCIONES PARA ARTÍCULO DE BLOG : ## 1. CRÍTICO: Responder ÚNICAMENTE en español. ## 2. Formatear como un artículo de blog estructurado con: - Párrafo de introducción claro - Contenido principal organizado en secciones lógicas - Conclusión con puntos clave ## 3. Usar emojis estratégicamente para mejorar la legibilidad ## 4. Incluir hechos, estadísticas o ejemplos relevantes ## 5. Escribir en un tono atractivo e informativo ## 6. IMPORTANTE: Todo el contenido debe estar en español"
            ;;
        "de")
            echo "# ANWEISUNGEN FÜR BLOG-ARTIKEL : ## 1. KRITISCH: Nur auf Deutsch antworten. ## 2. Als strukturierter Blog-Artikel formatieren mit: - Klarem Einführungsparagraphen - Hauptinhalt in logischen Abschnitten organisiert - Fazit mit wichtigen Erkenntnissen ## 3. Emojis strategisch zur Verbesserung der Lesbarkeit verwenden ## 4. Relevante Fakten, Statistiken oder Beispiele einbeziehen ## 5. In einem ansprechenden, informativen Ton schreiben ## 6. WICHTIG: Alle Inhalte müssen auf Deutsch sein"
            ;;
        "it")
            echo "# ISTRUZIONI PER ARTICOLO DI BLOG : ## 1. CRITICO: Rispondere SOLO in italiano. ## 2. Formattare come un articolo di blog strutturato con: - Paragrafo introduttivo chiaro - Contenuto principale organizzato in sezioni logiche - Conclusione con punti chiave ## 3. Usare emoji strategicamente per migliorare la leggibilità ## 4. Includere fatti, statistiche o esempi rilevanti ## 5. Scrivere in un tono coinvolgente e informativo ## 6. IMPORTANTE: Tutto il contenuto deve essere in italiano"
            ;;
        *)
            echo "# INSTRUCTIONS FOR BLOG ARTICLE : ## 1. CRITICAL: Respond ONLY in ${lang} language. ## 2. Format as a structured blog article with: - Clear introduction paragraph - Main content organized in logical sections - Conclusion with key takeaways ## 3. Use emojis strategically to enhance readability ## 4. Include relevant facts, statistics, or examples ## 5. Write in an engaging, informative tone ## 6. IMPORTANT: All content must be in ${lang} language"
            ;;
    esac
}

# Get system instructions based on language
SYSTEM_INSTRUCTIONS=$(get_system_instructions "$USER_LANG")
echo "Using language: $USER_LANG" >&2

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
  "systemInstructions": "$SYSTEM_INSTRUCTIONS",
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
