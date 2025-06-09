#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# SWARM.services.sh
# Découverte et abonnement aux services des nodes du swarm
# Réservé aux Capitaines de niveau Y (SSH/IPFS transmutation)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################

start=`date +%s`
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

# Vérifier le niveau Y (transmutation SSH/IPFS)
if [[ ! -s ~/.zen/game/id_ssh.pub ]]; then
    echo "❌ ACCÈS REFUSÉ : Niveau Y requis"
    echo "Exécutez d'abord : ~/.zen/Astroport.ONE/tools/Ylevel.sh"
    exit 1
fi

YIPNS=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py "$(cat ~/.ssh/id_ed25519.pub)")
if [[ ${YIPNS} != ${IPFSNODEID} ]]; then
    echo "❌ TRANSMUTATION SSH/IPFS INVALIDE"
    echo "Contactez le support ou relancez Ylevel.sh"
    exit 1
fi

echo "🔐 NIVEAU Y CONFIRMÉ : ${IPFSNODEID}"
echo "🌐 DÉCOUVERTE DES SERVICES SWARM"
echo "================================="

# Créer le répertoire de travail
mkdir -p ~/.zen/tmp/${MOATS}

# Scanner les nodes du swarm
SWARM_NODES=($(ls ~/.zen/tmp/swarm/ 2>/dev/null | grep -E "^12D3Koo"))
NODE_COUNT=${#SWARM_NODES[@]}

if [[ $NODE_COUNT -eq 0 ]]; then
    echo "⚠️  Aucun node détecté dans le swarm"
    echo "Attendez la synchronisation ou vérifiez votre connexion"
    exit 1
fi

echo "📡 $NODE_COUNT nodes détectés dans le swarm"
echo

# Fonction pour analyser les services d'un node
analyze_node_services() {
    local NODEID=$1
    local JSON_FILE="$HOME/.zen/tmp/swarm/$NODEID/12345.json"
    
    if [[ ! -s $JSON_FILE ]]; then
        echo "❌ Données manquantes pour $NODEID"
        return 1
    fi
    
    # Extraire les informations du JSON
    local HOSTNAME=$(jq -r '.hostname // "N/A"' $JSON_FILE)
    local CAPTAIN=$(jq -r '.captain // "N/A"' $JSON_FILE)
    local CAPTAIN_ZEN=$(jq -r '.captainZEN // "0"' $JSON_FILE)
    local NODE_ZEN=$(jq -r '.NODEZEN // "0"' $JSON_FILE)
    local PAF=$(jq -r '.PAF // "56"' $JSON_FILE)
    local NCARD=$(jq -r '.NCARD // "4"' $JSON_FILE)
    local ZCARD=$(jq -r '.ZCARD // "15"' $JSON_FILE)
    local BILAN=$(jq -r '.BILAN // "0"' $JSON_FILE)
    local NODE_G1PUB=$(jq -r '.NODEG1PUB // "N/A"' $JSON_FILE)
    
    # Découvrir les services disponibles (fichiers x_*.sh)
    local SERVICES_DIR="$HOME/.zen/tmp/swarm/$NODEID"
    local SERVICES=($(ls $SERVICES_DIR/x_*.sh 2>/dev/null | xargs -n1 basename))
    
    # Alternativement, essayer de les récupérer via IPFS
    if [[ ${#SERVICES[@]} -eq 0 ]]; then
        SERVICES=($(timeout 10s ipfs ls /ipns/$NODEID/ 2>/dev/null | grep "x_.*\.sh" | awk '{print $2}' || echo ""))
    fi
    
    # Calculer le statut économique
    local STATUS="🔴 Déficit"
    local STATUS_COLOR="\033[91m"
    if [[ $(echo "$BILAN >= $PAF" | bc -l) -eq 1 ]]; then
        if [[ $(echo "$BILAN >= $PAF * 3" | bc -l) -eq 1 ]]; then
            STATUS="🌟 Excédentaire"
            STATUS_COLOR="\033[92m"
        else
            STATUS="🟡 Rentable"
            STATUS_COLOR="\033[93m"
        fi
    fi
    
    # Afficher les informations du node
    echo -e "\033[96m┌─ NODE: $NODEID\033[0m"
    echo -e "├─ 🏠 Hostname: $HOSTNAME"
    echo -e "├─ 👨‍✈️ Captain: $CAPTAIN"
    echo -e "├─ 💰 Captain ZEN: $CAPTAIN_ZEN Ẑ"
    echo -e "├─ 🖥️  Node ZEN: $NODE_ZEN Ẑ"
    echo -e "├─ 📊 PAF: $PAF Ẑ/mois"
    echo -e "├─ ${STATUS_COLOR}├─ Statut: $STATUS (Bilan: $BILAN Ẑ)\033[0m"
    echo -e "├─ 🔑 MULTIPASS: $NCARD Ẑ/mois"
    echo -e "├─ 💳 ZEN Card: $ZCARD Ẑ/mois"
    
    if [[ ${#SERVICES[@]} -gt 0 ]]; then
        echo -e "├─ 🛠️  Services disponibles:"
        for service in "${SERVICES[@]}"; do
            local service_name=${service#x_}
            local service_name=${service_name%.sh}
            case $service_name in
                "ssh") echo -e "│  ├─ 🔐 SSH Terminal distant" ;;
                "ollama") echo -e "│  ├─ 🤖 Ollama IA (LLM)" ;;
                "comfyui") echo -e "│  ├─ 🎨 ComfyUI (IA Images)" ;;
                "perplexica") echo -e "│  ├─ 🔍 Perplexica (Recherche IA)" ;;
                "orpheus") echo -e "│  ├─ 🎵 Orpheus (Text-to-Speech)" ;;
                *) echo -e "│  ├─ ⚙️  $service_name" ;;
            esac
        done
    else
        echo -e "├─ ⚠️  Aucun service détecté"
    fi
    
    echo -e "└─ 💸 Coût total abonnement: $((NCARD + ZCARD)) Ẑ/mois"
    echo
    
    # Stocker les informations pour la sélection
    echo "$NODEID|$HOSTNAME|$CAPTAIN|$NCARD|$ZCARD|$((NCARD + ZCARD))|${#SERVICES[@]}|$NODE_G1PUB" >> ~/.zen/tmp/${MOATS}/nodes_info.txt
}

# Analyser tous les nodes
echo > ~/.zen/tmp/${MOATS}/nodes_info.txt
for NODEID in "${SWARM_NODES[@]}"; do
    # Ignorer son propre node
    [[ $NODEID == $IPFSNODEID ]] && continue
    analyze_node_services $NODEID
done

# Interface de sélection
echo "🎯 SÉLECTION D'ABONNEMENTS"
echo "=========================="

if [[ ! -s ~/.zen/tmp/${MOATS}/nodes_info.txt ]]; then
    echo "❌ Aucun node compatible trouvé"
    exit 1
fi

# Créer le menu de sélection
nodes_info=($(cat ~/.zen/tmp/${MOATS}/nodes_info.txt))
nodes_display=()
nodes_data=()

for info in "${nodes_info[@]}"; do
    IFS='|' read -r nodeid hostname captain ncard zcard total services g1pub <<< "$info"
    display="$hostname ($captain) - $total Ẑ/mois ($services services)"
    nodes_display+=("$display")
    nodes_data+=("$info")
done

nodes_display+=("💰 Voir mon solde" "🚪 Quitter")

echo "Choisissez un node pour vous abonner :"
PS3="Votre choix : "
select choice in "${nodes_display[@]}"; do
    case $REPLY in
        $((${#nodes_display[@]}-1))) # Voir solde
            CURRENT_PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
            if [[ $CURRENT_PLAYER ]]; then
                G1PUB=$(cat ~/.zen/game/players/$CURRENT_PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
                COINS=$(${MY_PATH}/../tools/COINScheck.sh ${G1PUB} | tail -n 1)
                ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
                echo "💰 Votre solde : $ZEN Ẑ ($COINS G1)"
            else
                echo "❌ Aucun joueur connecté"
            fi
            ;;
        ${#nodes_display[@]}) # Quitter
            echo "👋 Au revoir !"
            exit 0
            ;;
        *)
            if [[ $REPLY -gt 0 && $REPLY -le ${#nodes_data[@]} ]]; then
                selected_info="${nodes_data[$((REPLY-1))]}"
                IFS='|' read -r nodeid hostname captain ncard zcard total services g1pub <<< "$selected_info"
                
                echo "🎯 Node sélectionné : $hostname"
                echo "👨‍✈️ Captain : $captain"
                echo "💸 Coût : $total Ẑ/mois"
                echo
                
                # Sous-menu d'abonnement
                echo "Choisissez votre abonnement :"
                PS3="Type d'abonnement : "
                subscription_options=("🔑 MULTIPASS ($ncard Ẑ/mois)" "💳 ZEN Card ($zcard Ẑ/mois)" "🎁 Les deux ($total Ẑ/mois)" "🔙 Retour")
                select sub_choice in "${subscription_options[@]}"; do
                    case $REPLY in
                        1) # MULTIPASS
                            echo "🔑 Abonnement MULTIPASS sélectionné"
                            subscribe_to_service "$nodeid" "$g1pub" "$ncard" "MULTIPASS" "$hostname"
                            break 2
                            ;;
                        2) # ZEN Card
                            echo "💳 Abonnement ZEN Card sélectionné"
                            subscribe_to_service "$nodeid" "$g1pub" "$zcard" "ZENCARD" "$hostname"
                            break 2
                            ;;
                        3) # Les deux
                            echo "🎁 Abonnement complet sélectionné"
                            subscribe_to_service "$nodeid" "$g1pub" "$total" "MULTIPASS+ZENCARD" "$hostname"
                            break 2
                            ;;
                        4) # Retour
                            break
                            ;;
                        *)
                            echo "❌ Choix invalide"
                            ;;
                    esac
                done
            else
                echo "❌ Choix invalide"
            fi
            ;;
    esac
done

# Fonction d'abonnement
subscribe_to_service() {
    local target_nodeid=$1
    local target_g1pub=$2
    local amount=$3
    local service_type=$4
    local hostname=$5
    
    echo "💳 TRAITEMENT DE L'ABONNEMENT"
    echo "=============================="
    echo "🎯 Destination : $hostname ($target_nodeid)"
    echo "💰 Montant : $amount Ẑ"
    echo "🔖 Service : $service_type"
    echo
    
    # Vérifier le solde disponible
    CURRENT_PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
    if [[ ! $CURRENT_PLAYER ]]; then
        echo "❌ Aucun joueur connecté pour effectuer le paiement"
        return 1
    fi
    
    G1PUB=$(cat ~/.zen/game/players/$CURRENT_PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
    COINS=$(${MY_PATH}/../tools/COINScheck.sh ${G1PUB} | tail -n 1)
    ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)
    REQUIRED_G1=$(echo "scale=2; $amount / 10" | bc)
    
    echo "💰 Votre solde : $ZEN Ẑ ($COINS G1)"
    echo "💸 Requis : $amount Ẑ ($REQUIRED_G1 G1)"
    
    if [[ $(echo "$COINS < $REQUIRED_G1" | bc -l) -eq 1 ]]; then
        echo "❌ Solde insuffisant pour cet abonnement"
        return 1
    fi
    
    echo "✅ Solde suffisant"
    echo
    echo "⚠️  CONFIRMER LE PAIEMENT ?"
    echo "Tapez 'OUI' pour confirmer, autre chose pour annuler :"
    read confirmation
    
    if [[ "$confirmation" != "OUI" ]]; then
        echo "❌ Paiement annulé"
        return 1
    fi
    
    # Effectuer le paiement
    echo "💸 Traitement du paiement..."
    
    # Générer le message de transaction
    local TZ_MSG="SWARM:$service_type:$IPFSNODEID:$(date -u +%Y%m%d)"
    
    # Effectuer le paiement via PAY4SURE.sh
    echo "Exécution : ${MY_PATH}/../tools/PAY4SURE.sh ~/.zen/game/players/.current/secret.dunikey $REQUIRED_G1 $target_g1pub \"$TZ_MSG\""
    
    if ${MY_PATH}/../tools/PAY4SURE.sh ~/.zen/game/players/.current/secret.dunikey "$REQUIRED_G1" "$target_g1pub" "$TZ_MSG"; then
        echo "✅ PAIEMENT RÉUSSI !"
        echo "📧 Notification envoyée au Captain $captain"
        echo "🔗 Accès aux services disponible via :"
        echo "   ipfs cat /ipns/$target_nodeid/x_ssh.sh | bash"
        echo "   ipfs cat /ipns/$target_nodeid/x_ollama.sh | bash"
        echo "   (selon les services disponibles)"
        
        # Enregistrer l'abonnement localement
        mkdir -p ~/.zen/game/subscriptions
        echo "$(date -u +%s)|$target_nodeid|$hostname|$service_type|$amount|$target_g1pub|ACTIVE" >> ~/.zen/game/subscriptions/history.txt
        
        # Créer un lien rapide vers les services
        mkdir -p ~/.zen/tmp/subscribed_services
        echo "#!/bin/bash
# Accès rapide aux services de $hostname
echo 'Services disponibles sur $hostname :'
echo '🔐 SSH: ipfs cat /ipns/$target_nodeid/x_ssh.sh | bash'
echo '🤖 Ollama: ipfs cat /ipns/$target_nodeid/x_ollama.sh | bash'
echo '🎨 ComfyUI: ipfs cat /ipns/$target_nodeid/x_comfyui.sh | bash'
echo '🔍 Perplexica: ipfs cat /ipns/$target_nodeid/x_perplexica.sh | bash'
echo '🎵 Orpheus: ipfs cat /ipns/$target_nodeid/x_orpheus.sh | bash'
" > ~/.zen/tmp/subscribed_services/$target_nodeid.sh
        chmod +x ~/.zen/tmp/subscribed_services/$target_nodeid.sh
        
        echo "📁 Script d'accès rapide créé : ~/.zen/tmp/subscribed_services/$target_nodeid.sh"
        
    else
        echo "❌ ERREUR DE PAIEMENT"
        echo "Vérifiez votre connexion et votre solde"
        return 1
    fi
}

# Nettoyage
rm -rf ~/.zen/tmp/${MOATS}

echo "🏁 Session terminée"
exit 0 