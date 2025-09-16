#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# SWARM.discover.sh
# Découverte et gestion des connexions entre Nodes de l'essaim UPlanet
# Permet au capitaine de s'abonner aux services des autres ♥️box
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

start=`date +%s`
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

#######################################################################
# Fonction pour découvrir les Nodes de l'essaim
#######################################################################
discover_swarm_nodes() {
    echo "🔍 DÉCOUVERTE DE L'ESSAIM UPlanet"
    echo "=================================="

    SWARM_DIR="$HOME/.zen/tmp/swarm"
    [[ ! -d "$SWARM_DIR" ]] && echo "❌ Aucun répertoire essaim trouvé: $SWARM_DIR" && return 1

    DISCOVERED_NODES=()

    # Parcourir tous les nodes découverts
    for node_dir in "$SWARM_DIR"/*/; do
        [[ ! -d "$node_dir" ]] && continue

        NODE_ID=$(basename "$node_dir")
        JSON_FILE="$node_dir/12345.json"

        # Ignorer notre propre node
        [[ "$NODE_ID" == "$IPFSNODEID" ]] && continue

        if [[ -f "$JSON_FILE" ]]; then
            # Vérifier que le JSON est valide et récent
            if validate_node_json "$JSON_FILE"; then
                DISCOVERED_NODES+=("$NODE_ID")
                echo "✅ Node découvert: $NODE_ID"
            else
                echo "⚠️  Node invalide ou obsolète: $NODE_ID"
            fi
        else
            echo "❌ Fichier JSON manquant pour: $NODE_ID"
        fi
    done

    if [[ ${#DISCOVERED_NODES[@]} -eq 0 ]]; then
        echo "📭 Aucun node valide découvert dans l'essaim"
        return 1
    fi

    echo "🌐 ${#DISCOVERED_NODES[@]} node(s) découvert(s)"
    return 0
}

#######################################################################
# Fonction pour valider un fichier JSON de node
#######################################################################
validate_node_json() {
    local json_file="$1"

    # Vérifier que le fichier existe et n'est pas vide
    [[ ! -s "$json_file" ]] && return 1

    # Vérifier que c'est du JSON valide
    if ! jq . "$json_file" >/dev/null 2>&1; then
        echo "❌ JSON invalide: $json_file"
        return 1
    fi

    # Vérifier la présence des champs essentiels
    local required_fields=("ipfsnodeid" "captain" "PAF" "NCARD" "ZCARD" "uSPOT")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$json_file" >/dev/null 2>&1; then
            echo "❌ Champ manquant '$field' dans: $json_file"
            return 1
        fi
    done

    # Vérifier que le node n'est pas obsolète (moins de 7 jours)
    local created=$(jq -r '.created' "$json_file" 2>/dev/null)
    if [[ "$created" != "null" && "$created" != "" ]]; then
        local created_timestamp=$(echo "$created" | cut -c1-10)  # Les 10 premiers chiffres = timestamp unix
        local current_timestamp=$(date +%s)
        local age_days=$(( (current_timestamp - created_timestamp) / 86400 ))

        if [[ $age_days -gt 7 ]]; then
            echo "⚠️  Node obsolète ($age_days jours): $json_file"
            return 1
        fi
    fi

    return 0
}

#######################################################################
# Fonction pour afficher les détails d'un node
#######################################################################
show_node_details() {
    local node_id="$1"
    local json_file="$HOME/.zen/tmp/swarm/$node_id/12345.json"

    echo ""
    echo "📋 DÉTAILS DU NODE: $node_id"
    echo "========================================="

    # Extraire les informations principales
    local captain=$(jq -r '.captain' "$json_file")
    local hostname=$(jq -r '.hostname' "$json_file")
    local uSPOT=$(jq -r '.uSPOT' "$json_file")
    local PAF=$(jq -r '.PAF' "$json_file")
    local NCARD=$(jq -r '.NCARD' "$json_file")
    local ZCARD=$(jq -r '.ZCARD' "$json_file")
    local BILAN=$(jq -r '.BILAN' "$json_file")
    local captainZEN=$(jq -r '.captainZEN' "$json_file")
    local NODEZEN=$(jq -r '.NODEZEN' "$json_file")

    echo "🧑‍✈️  Capitaine: $captain"
    echo "🏠 Hostname: $hostname"
    echo "🌐 API: $uSPOT"
    echo "💰 PAF: $PAF Ẑ"
    echo "🔑 MULTIPASS: $NCARD Ẑ/semaine"
    echo "💳 ZEN Card: $ZCARD Ẑ/semaine"
    echo "📊 Bilan: $BILAN Ẑ"
    echo "👨‍💼 Capitaine ZEN: $captainZEN Ẑ"
    echo "🖥️  Node ZEN: $NODEZEN Ẑ"

    # Coût total pour 1 slot (NCARD + ZCARD)
    local total_cost=$((NCARD + ZCARD))
    echo "💸 Coût total abonnement: $total_cost Ẑ/semaine"

    # Services disponibles (fichiers x_*.sh)
    echo ""
    echo "🛠️  SERVICES DISPONIBLES:"
    local services_dir="$HOME/.zen/tmp/swarm/$node_id"
    local services_found=false

    for service_file in "$services_dir"/x_*.sh; do
        if [[ -f "$service_file" ]]; then
            local service_name=$(basename "$service_file" .sh | sed 's/x_//')
            echo "   🔧 $service_name"
            services_found=true
        fi
    done

    if [[ "$services_found" == "false" ]]; then
        echo "   ❌ Aucun service spécialisé détecté"
    fi

    echo ""
}

#######################################################################
# Fonction pour générer l'alias email pour l'inscription
#######################################################################
generate_subscription_email() {
    local target_node_id="$1"

    # Format: capitaine+ipfsnodeid@domain.com
    local base_email="$CAPTAINEMAIL"
    local local_part="${base_email%@*}"
    local domain_part="${base_email#*@}"
    echo "${local_part}+${target_node_id}@${domain_part}"
}

#######################################################################
# Fonction pour s'abonner à un node distant
#######################################################################
subscribe_to_node() {
    local target_node_id="$1"
    local json_file="$HOME/.zen/tmp/swarm/$target_node_id/12345.json"

    # Extraire les informations nécessaires
    local uSPOT=$(jq -r '.uSPOT' "$json_file")
    local NCARD=$(jq -r '.NCARD' "$json_file")
    local ZCARD=$(jq -r '.ZCARD' "$json_file")
    local captain=$(jq -r '.captain' "$json_file")
    local total_cost=$((NCARD + ZCARD))

    echo ""
    echo "📝 INSCRIPTION AU NODE: $target_node_id"
    echo "======================================="
    echo "🎯 Capitaine distant: $captain"
    echo "🌐 API: $uSPOT"
    echo "💸 Coût: $total_cost Ẑ/semaine"

    # Générer l'email d'inscription ## captainemail+target_node_id@emaildomain.tld
    local subscription_email=$(generate_subscription_email "$target_node_id")
    echo "📧 Email d'inscription: $subscription_email"

    # Vérifier que nous avons assez de ZEN
    echo ""
    echo "💰 VÉRIFICATION DES FONDS"
    echo "========================"

    # Vérifier le solde du Node (niveau Y) ou du Capitaine
    local available_zen=0
    local payment_source=""

    if [[ -f ~/.zen/game/secret.NODE.dunikey ]]; then
        # Node niveau Y
        local node_coins=$(${MY_PATH}/../tools/G1check.sh ${NODEG1PUB} | tail -n 1)
        local node_zen=$(echo "($node_coins - 1) * 10" | bc | cut -d '.' -f 1)
        available_zen=$node_zen
        payment_source="Node (Y Level)"
        echo "🖥️  Solde Node: $node_zen Ẑ"
    else
        # Solde Capitaine
        local captain_coins=$(${MY_PATH}/../tools/G1check.sh ${CAPTAING1PUB} | tail -n 1)
        local captain_zen=$(echo "($captain_coins - 1) * 10" | bc | cut -d '.' -f 1)
        available_zen=$captain_zen
        payment_source="Capitaine"
        echo "👨‍💼 Solde Capitaine: $captain_zen Ẑ"
    fi

    if [[ $available_zen -lt $total_cost ]]; then
        echo "❌ Fonds insuffisants: $available_zen Ẑ < $total_cost Ẑ"
        echo "💡 Rechargez votre portefeuille ou demandez de l'aide à UPlanet"
        return 1
    fi

    echo "✅ Fonds suffisants: $available_zen Ẑ >= $total_cost Ẑ"
    echo "💳 Source de paiement: $payment_source"

    # Confirmation finale
    echo ""
    echo "❓ CONFIRMER L'ABONNEMENT ?"
    echo "=========================="
    echo "📧 Email: $subscription_email"
    echo "🎯 Node: $target_node_id"
    echo "💸 Coût: $total_cost Ẑ/semaine"
    echo "💳 Paiement: $payment_source ($available_zen Ẑ disponibles)"
    echo ""
    echo "Tapez 'OUI' pour confirmer, ou ENTER pour annuler:"
    read confirmation

    if [[ "${confirmation^^}" != "OUI" ]]; then
        echo "❌ Abonnement annulé"
        return 1
    fi

    # Procéder à l'inscription
    echo ""
    echo "🚀 INSCRIPTION EN COURS..."
    echo "========================="

    # Appeler l'API /g1nostr du node distant (POST)
    local api_url="${uSPOT}/g1nostr"
    echo "📡 Connexion à: $api_url"

    # Créer un fichier temporaire pour l'inscription
    local temp_dir="$HOME/.zen/tmp/$MOATS"
    mkdir -p "$temp_dir"

    # Récupérer les vraies valeurs GPS et langue du capitaine
    local gps_file="$HOME/.zen/game/nostr/$CAPTAINEMAIL/GPS"
    local lang_file="$HOME/.zen/game/nostr/$CAPTAINEMAIL/LANG"
    
    # Valeurs par défaut
    local lang="fr"
    local lat="0.0"
    local lon="0.0"
    
    # Lire la langue
    if [[ -f "$lang_file" ]]; then
        lang=$(cat "$lang_file" | tr -d '\n\r')
        echo "🌍 Langue détectée: $lang"
    else
        echo "⚠️  Fichier langue non trouvé: $lang_file (utilisation de 'fr' par défaut)"
    fi
    
    # Lire les coordonnées GPS
    if [[ -f "$gps_file" ]]; then
        local gps_content=$(cat "$gps_file")
        if [[ "$gps_content" =~ LAT=([0-9.]+) ]]; then
            lat="${BASH_REMATCH[1]}"
            echo "📍 Latitude détectée: $lat"
        fi
        if [[ "$gps_content" =~ LON=([0-9.]+) ]]; then
            lon="${BASH_REMATCH[1]}"
            echo "📍 Longitude détectée: $lon"
        fi
    else
        echo "⚠️  Fichier GPS non trouvé: $gps_file (utilisation de 0.0,0.0 par défaut)"
    fi
    
    echo "🚀 Envoi de la demande d'inscription..."
    echo "📧 Email: $subscription_email"
    echo "🎯 Node: $target_node_id"
    echo "💸 Coût: $total_cost Ẑ"
    echo "🌍 Langue: $lang"
    echo "📍 Coordonnées: $lat, $lon"
    
    # Appel réel à l'API POST /g1nostr
    local response=$(curl -s -X POST "$api_url" \
        -F "email=$subscription_email" \
        -F "lang=$lang" \
        -F "lat=$lat" \
        -F "lon=$lon" \
        -F "salt=" \
        -F "pepper=" \
        --connect-timeout 30 \
        --max-time 60)
    
    if [[ $? -eq 0 ]]; then
        echo "✅ Réponse reçue du node distant"
        echo "$response" > "$temp_dir/api_response.log"
    else
        echo "❌ Erreur lors de l'appel API"
        echo "Inscription simulée de $subscription_email au node $target_node_id" > "$temp_dir/subscription.log"
        echo "Coût: $total_cost Ẑ" >> "$temp_dir/subscription.log"
        echo "Timestamp: $(date)" >> "$temp_dir/subscription.log"
    fi

    # Enregistrer l'abonnement localement
    local subscriptions_file="$HOME/.zen/tmp/$IPFSNODEID/swarm_subscriptions.json"
    mkdir -p "$(dirname "$subscriptions_file")"

    # Créer ou mettre à jour le fichier des abonnements
    if [[ ! -f "$subscriptions_file" ]]; then
        echo '{"subscriptions": []}' > "$subscriptions_file"
    fi

    # Ajouter le nouvel abonnement
    local subscription_entry=$(cat <<EOF
{
    "target_node": "$target_node_id",
    "subscription_email": "$subscription_email",
    "cost_ncard": $NCARD,
    "cost_zcard": $ZCARD,
    "total_cost": $total_cost,
    "payment_source": "$payment_source",
    "subscribed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "next_payment": "$(date -u -d '+7 days' +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "active",
    "api_url": "$uSPOT"
}
EOF
)

    # Ajouter l'abonnement au fichier JSON
    jq --argjson new_sub "$subscription_entry" '.subscriptions += [$new_sub]' "$subscriptions_file" > "$subscriptions_file.tmp"
    mv "$subscriptions_file.tmp" "$subscriptions_file"

    echo "✅ Abonnement enregistré localement"
    echo "📝 Fichier: $subscriptions_file"
    echo "📧 Email: $subscription_email"
    echo ""
    echo "🔄 L'abonnement sera activé lors du prochain cycle ZEN.ECONOMY.sh"
    echo "💰 Le paiement de $total_cost Ẑ sera effectué automatiquement"

    return 0
}

#######################################################################
# Fonction pour lister les abonnements actifs
#######################################################################
list_active_subscriptions() {
    local subscriptions_file="$HOME/.zen/tmp/$IPFSNODEID/swarm_subscriptions.json"

    echo ""
    echo "📋 ABONNEMENTS ACTIFS"
    echo "===================="

    if [[ ! -f "$subscriptions_file" ]]; then
        echo "❌ Aucun abonnement trouvé"
        return 1
    fi

    local count=$(jq '.subscriptions | length' "$subscriptions_file")

    if [[ $count -eq 0 ]]; then
        echo "❌ Aucun abonnement actif"
        return 1
    fi

    echo "📊 $count abonnement(s) actif(s):"
    echo ""

    jq -r '.subscriptions[] | select(.status == "active") |
        "🎯 Node: \(.target_node)\n📧 Email: \(.subscription_email)\n💸 Coût: \(.total_cost) Ẑ/7j\n🗓️  Prochain paiement: \(.next_payment)\n"' "$subscriptions_file"
}

#######################################################################
# Menu principal
#######################################################################
main_menu() {
    echo ""
    echo "🌐 GESTION DE L'ESSAIM UPlanet"
    echo "=============================="
    echo ""
    echo "Votre Node: $IPFSNODEID"
    echo "Capitaine: $CAPTAINEMAIL"
    echo ""

    # Découvrir les nodes
    if ! discover_swarm_nodes; then
        echo "❌ Impossible de découvrir l'essaim"
        return 1
    fi

    while true; do
        echo ""
        echo "🔧 ACTIONS DISPONIBLES:"
        echo "======================="
        echo "1) 🔍 Voir les détails d'un node"
        echo "2) 📝 S'abonner à un node"
        echo "3) 📋 Voir mes abonnements"
        echo "4) 🔄 Actualiser la découverte"
        echo "5) ❌ Quitter"
        echo ""
        echo "Votre choix (1-5):"
        read choice

        case $choice in
            1)
                echo ""
                echo "🔍 NODES DISPONIBLES:"
                for i in "${!DISCOVERED_NODES[@]}"; do
                    echo "$((i+1))) ${DISCOVERED_NODES[$i]}"
                done
                echo ""
                echo "Numéro du node à examiner:"
                read node_num

                if [[ $node_num =~ ^[0-9]+$ ]] && [[ $node_num -ge 1 ]] && [[ $node_num -le ${#DISCOVERED_NODES[@]} ]]; then
                    local selected_node="${DISCOVERED_NODES[$((node_num-1))]}"
                    show_node_details "$selected_node"
                else
                    echo "❌ Choix invalide"
                fi
                ;;

            2)
                echo ""
                echo "📝 NODES DISPONIBLES POUR ABONNEMENT:"
                for i in "${!DISCOVERED_NODES[@]}"; do
                    echo "$((i+1))) ${DISCOVERED_NODES[$i]}"
                done
                echo ""
                echo "Numéro du node pour s'abonner:"
                read node_num

                if [[ $node_num =~ ^[0-9]+$ ]] && [[ $node_num -ge 1 ]] && [[ $node_num -le ${#DISCOVERED_NODES[@]} ]]; then
                    local selected_node="${DISCOVERED_NODES[$((node_num-1))]}"
                    show_node_details "$selected_node"
                    subscribe_to_node "$selected_node"
                else
                    echo "❌ Choix invalide"
                fi
                ;;

            3)
                list_active_subscriptions
                ;;

            4)
                echo "🔄 Actualisation..."
                discover_swarm_nodes
                ;;

            5)
                echo "👋 Au revoir!"
                break
                ;;

            *)
                echo "❌ Choix invalide (1-5)"
                ;;
        esac
    done
}

#######################################################################
# Point d'entrée principal
#######################################################################

# Vérifications préalables
if [[ -z "$IPFSNODEID" ]]; then
    echo "❌ IPFSNODEID non défini"
    exit 1
fi

if [[ -z "$CAPTAINEMAIL" ]]; then
    echo "❌ CAPTAINEMAIL non défini"
    exit 1
fi

# Créer le répertoire de notification si nécessaire
mkdir -p "$HOME/.zen/tmp/$IPFSNODEID"

# Lancer le menu principal
main_menu

echo ""
echo "⏱️  Temps d'exécution: $(($(date +%s) - start)) secondes"
exit 0
