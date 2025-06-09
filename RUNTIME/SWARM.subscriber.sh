#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# SWARM.subscriber.sh
# Gestion des notifications d'abonnements reçus d'autres Capitaines
# Script appelé automatiquement lors de la réception de paiements SWARM
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################

TRANSACTION_MSG="$1"  # Message de la transaction reçue
SENDER_G1PUB="$2"     # Clé publique G1 de l'expéditeur
AMOUNT_G1="$3"        # Montant en G1 reçu

# Vérifier que tous les paramètres sont fournis
if [[ -z "$TRANSACTION_MSG" || -z "$SENDER_G1PUB" || -z "$AMOUNT_G1" ]]; then
    echo "Usage: $0 <TRANSACTION_MSG> <SENDER_G1PUB> <AMOUNT_G1>"
    exit 1
fi

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
echo "📨 NOTIFICATION D'ABONNEMENT REÇUE"
echo "===================================="
echo "⏰ $MOATS"
echo "💰 Montant : $AMOUNT_G1 G1"
echo "👤 Expéditeur : $SENDER_G1PUB"
echo "📝 Message : $TRANSACTION_MSG"

# Parser le message de transaction (format: SWARM:SERVICE_TYPE:SUBSCRIBER_NODEID:DATE)
if [[ $TRANSACTION_MSG =~ ^SWARM:([^:]+):([^:]+):([^:]+)$ ]]; then
    SERVICE_TYPE="${BASH_REMATCH[1]}"
    SUBSCRIBER_NODEID="${BASH_REMATCH[2]}"
    DATE_STAMP="${BASH_REMATCH[3]}"
    
    echo "🔍 ANALYSE DU PAIEMENT"
    echo "├─ 🔖 Service : $SERVICE_TYPE"
    echo "├─ 🌐 Node abonné : $SUBSCRIBER_NODEID"
    echo "└─ 📅 Date : $DATE_STAMP"
    
    # Calculer la durée d'abonnement (28 jours pour un paiement mensuel)
    EXPIRY_DATE=$(date -d "+28 days" -u +"%Y%m%d")
    AMOUNT_ZEN=$(echo "$AMOUNT_G1 * 10" | bc | cut -d '.' -f 1)
    
    # Créer le répertoire des abonnements
    mkdir -p ~/.zen/game/swarm_subscriptions
    
    # Enregistrer l'abonnement
    SUBSCRIPTION_FILE="~/.zen/game/swarm_subscriptions/${SUBSCRIBER_NODEID}.subscription"
    
    # Chercher si cet abonné existe déjà
    if [[ -s $SUBSCRIPTION_FILE ]]; then
        echo "🔄 RENOUVELLEMENT D'ABONNEMENT"
        # Prolonger l'abonnement existant
        EXISTING_EXPIRY=$(grep "EXPIRY=" $SUBSCRIPTION_FILE | cut -d '=' -f 2)
        if [[ $EXISTING_EXPIRY > $(date -u +"%Y%m%d") ]]; then
            # Si l'abonnement n'a pas encore expiré, prolonger à partir de la date d'expiration
            NEW_EXPIRY=$(date -d "$EXISTING_EXPIRY +28 days" -u +"%Y%m%d")
        else
            # Si l'abonnement a expiré, partir d'aujourd'hui
            NEW_EXPIRY=$EXPIRY_DATE
        fi
        
        # Mettre à jour le fichier d'abonnement
        sed -i "s/EXPIRY=.*/EXPIRY=$NEW_EXPIRY/" $SUBSCRIPTION_FILE
        sed -i "s/STATUS=.*/STATUS=ACTIVE/" $SUBSCRIPTION_FILE
        echo "LAST_PAYMENT=$(date -u +%s)" >> $SUBSCRIPTION_FILE
        echo "LAST_AMOUNT=$AMOUNT_G1" >> $SUBSCRIPTION_FILE
    else
        echo "🆕 NOUVEL ABONNEMENT"
        # Créer un nouveau fichier d'abonnement
        cat > $SUBSCRIPTION_FILE << EOF
# Abonnement SWARM pour $SUBSCRIBER_NODEID
SUBSCRIBER_NODEID=$SUBSCRIBER_NODEID
SUBSCRIBER_G1PUB=$SENDER_G1PUB
SERVICE_TYPE=$SERVICE_TYPE
CREATED=$(date -u +%s)
EXPIRY=$EXPIRY_DATE
STATUS=ACTIVE
AMOUNT_G1=$AMOUNT_G1
AMOUNT_ZEN=$AMOUNT_ZEN
LAST_PAYMENT=$(date -u +%s)
LAST_AMOUNT=$AMOUNT_G1
PAYMENT_COUNT=1
EOF
    fi
    
    echo "✅ ABONNEMENT ENREGISTRÉ"
    echo "├─ 📄 Fichier : $SUBSCRIPTION_FILE"
    echo "├─ ⏰ Expiration : $EXPIRY_DATE"
    echo "└─ 🎫 Services autorisés : $SERVICE_TYPE"
    
    # Mettre à jour les accès
    update_service_access "$SUBSCRIBER_NODEID" "$SERVICE_TYPE" "$EXPIRY_DATE"
    
    # Notifier le Captain
    notify_captain "$SUBSCRIBER_NODEID" "$SERVICE_TYPE" "$AMOUNT_G1" "$EXPIRY_DATE"
    
else
    echo "❌ FORMAT DE MESSAGE INVALIDE : $TRANSACTION_MSG"
    echo "Format attendu : SWARM:SERVICE_TYPE:SUBSCRIBER_NODEID:DATE"
    exit 1
fi

# Fonction de mise à jour des accès aux services
update_service_access() {
    local nodeid=$1
    local service_type=$2
    local expiry=$3
    
    echo "🔧 MISE À JOUR DES ACCÈS"
    
    # Créer le répertoire des accès autorisés
    mkdir -p ~/.zen/game/swarm_access
    
    case $service_type in
        "MULTIPASS"|"MULTIPASS+ZENCARD")
            echo "🔑 Activation accès MULTIPASS pour $nodeid"
            echo "NODEID=$nodeid
SERVICE=MULTIPASS
EXPIRY=$expiry
STATUS=ACTIVE
GRANTED=$(date -u +%s)" > ~/.zen/game/swarm_access/${nodeid}.multipass
            ;;
    esac
    
    case $service_type in
        "ZENCARD"|"MULTIPASS+ZENCARD")
            echo "💳 Activation accès ZEN Card pour $nodeid"
            echo "NODEID=$nodeid
SERVICE=ZENCARD
EXPIRY=$expiry
STATUS=ACTIVE
GRANTED=$(date -u +%s)" > ~/.zen/game/swarm_access/${nodeid}.zencard
            ;;
    esac
    
    # Générer une clé d'accès temporaire pour les tunnels P2P
    ACCESS_TOKEN=$(echo "${nodeid}:${IPFSNODEID}:$(date -u +%s)" | sha256sum | cut -d ' ' -f 1)
    echo "ACCESS_TOKEN=$ACCESS_TOKEN" >> ~/.zen/game/swarm_access/${nodeid}.access
    
    echo "🎫 Token d'accès généré : ${ACCESS_TOKEN:0:16}..."
}

# Fonction de notification au Captain
notify_captain() {
    local subscriber_nodeid=$1
    local service_type=$2
    local amount=$3
    local expiry=$4
    
    echo "📧 NOTIFICATION CAPTAIN"
    
    # Créer le message de notification
    local notification_msg="🎉 NOUVEL ABONNEMENT REÇU !

🌐 Node abonné : $subscriber_nodeid
🔖 Service : $service_type  
💰 Montant : $amount G1
⏰ Expiration : $expiry
🎫 Accès autorisé jusqu'au : $(date -d "$expiry" "+%d/%m/%Y")

Votre node génère maintenant des revenus supplémentaires !
Consulter tous vos abonnements : ~/.zen/game/swarm_subscriptions/

Astroport.ONE UPlanet $(date)"
    
    # Enregistrer la notification
    mkdir -p ~/.zen/game/notifications
    echo "$notification_msg" > ~/.zen/game/notifications/subscription_${subscriber_nodeid}_$(date -u +%s).txt
    
    # Si possible, envoyer par email (optionnel)
    if [[ -n "$CAPTAINEMAIL" ]] && command -v mail >/dev/null 2>&1; then
        echo "$notification_msg" | mail -s "🎉 Nouvel abonnement SWARM reçu !" "$CAPTAINEMAIL" 2>/dev/null || true
    fi
    
    # Log dans le système
    logger "Astroport.ONE: Subscription received from $subscriber_nodeid for $service_type ($amount G1)"
    
    echo "✅ Notification envoyée"
}

# Créer un script de vérification d'expiration des abonnements
create_expiry_checker() {
    cat > ~/.zen/game/swarm_check_expiry.sh << 'EOF'
#!/bin/bash
# Vérification automatique de l'expiration des abonnements SWARM
TODAY=$(date -u +"%Y%m%d")
EXPIRED_COUNT=0

for subscription_file in ~/.zen/game/swarm_subscriptions/*.subscription; do
    [[ ! -f "$subscription_file" ]] && continue
    
    source "$subscription_file"
    
    if [[ "$EXPIRY" < "$TODAY" ]] && [[ "$STATUS" == "ACTIVE" ]]; then
        echo "⏰ Abonnement expiré : $SUBSCRIBER_NODEID (expiré le $EXPIRY)"
        
        # Marquer comme expiré
        sed -i "s/STATUS=ACTIVE/STATUS=EXPIRED/" "$subscription_file"
        
        # Supprimer les accès
        rm -f ~/.zen/game/swarm_access/${SUBSCRIBER_NODEID}.*
        
        ((EXPIRED_COUNT++))
    fi
done

[[ $EXPIRED_COUNT -gt 0 ]] && echo "📊 $EXPIRED_COUNT abonnement(s) expiré(s) traité(s)"
EOF
    chmod +x ~/.zen/game/swarm_check_expiry.sh
}

# Créer le script de vérification d'expiration
create_expiry_checker

echo "🏁 Traitement terminé avec succès"
echo "📋 Résumé :"
echo "├─ ✅ Abonnement enregistré"
echo "├─ 🔧 Accès configurés"
echo "├─ 📧 Captain notifié"
echo "└─ ⏰ Vérification d'expiration mise à jour"

exit 0 