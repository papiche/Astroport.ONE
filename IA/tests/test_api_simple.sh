#!/bin/bash
echo "🧪 Test simple de l endpoint /api/send_dm"
echo "========================================"

# Test de santé de l API
echo "📡 Test de santé de l API..."
curl -s "http://127.0.0.1:54321/health" | jq . 2>/dev/null || echo "API non accessible"

echo ""
echo "📤 Test d envoi de message privé..."
echo "   (Ce test nécessite des clés NOSTR valides)"

# Test avec des données d exemple
TEST_DATA='{
    "sender_nsec": "nsec1example",
    "recipient_hex": "0000000000000000000000000000000000000000000000000000000000000000",
    "message": "Test message"
}'

curl -s -X POST "http://127.0.0.1:54321/api/send_dm" \
    -H "Content-Type: application/json" \
    -d "$TEST_DATA" | jq . 2>/dev/null || echo "Erreur lors de l appel de l API"

echo ""
echo "📝 Test terminé."
