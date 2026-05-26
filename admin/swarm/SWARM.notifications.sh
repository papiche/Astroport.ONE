#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# SWARM.notifications.sh
# Affichage des notifications d'abonnements reçus des autres nodes
################################################################################
MY_PATH="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "${MY_PATH}/../../tools/my.sh"

#######################################################################
# Affichage des notifications d'abonnements reçus
#######################################################################

NOTIFICATIONS_FILE="$HOME/.zen/tmp/$IPFSNODEID/swarm_subscriptions_received.json"

echo "🔔 NOTIFICATIONS D'ABONNEMENTS REÇUS"
echo "===================================="
echo "Node: $IPFSNODEID"
echo ""

if [[ ! -f "$NOTIFICATIONS_FILE" ]]; then
    echo "❌ Aucune notification d'abonnement trouvée"
    echo "📂 Fichier attendu: $NOTIFICATIONS_FILE"
    exit 1
fi

# Vérifier si le fichier contient des notifications
NOTIFICATION_COUNT=$(jq '.received_subscriptions | length' "$NOTIFICATIONS_FILE" 2>/dev/null)
if [[ -z "$NOTIFICATION_COUNT" || "$NOTIFICATION_COUNT" == "0" ]]; then
    echo "📭 Aucune notification d'abonnement reçue"
    exit 0
fi

echo "📊 $NOTIFICATION_COUNT notification(s) reçue(s):"
echo ""

# Afficher chaque notification
jq -r '.received_subscriptions[] | 
    "🌐 Abonnement reçu:\n" +
    "   📧 Email: \(.subscription_email)\n" +
    "   👤 Base: \(.base_email)\n" +
    "   🔗 Node: \(.node_info)\n" +
    "   📅 Reçu: \(.received_at)\n" +
    "   📍 Position: \(.lat), \(.lon)\n" +
    "   ⚠️  Salt: \(.salt)\n" +
    "   📊 Status: \(.status)\n"' "$NOTIFICATIONS_FILE"

echo ""
echo "💡 Ces abonnements indiquent que d'autres nodes"
echo "   se sont connectés à vos services via l'essaim UPlanet"
echo ""
echo "📝 Pour gérer vos propres abonnements sortants:"
echo "   ~/.zen/Astroport.ONE/RUNTIME/SWARM.discover.sh"
echo ""

exit 0 