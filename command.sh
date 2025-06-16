#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

# Configuration des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

TS=$(date -u +%s%N | cut -b1-13)
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
#~ mkdir -p ~/.zen/tmp/${MOATS}

### CHECK and CORRECT .current
CURRENT=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ${CURRENT} == "" ]] \
    && lastplayer=$(ls -t ~/.zen/game/players 2>/dev/null | grep "@" | head -n 1) \
    && [[ ${lastplayer} ]] \
    && rm ~/.zen/game/players/.current \
    && ln -s ~/.zen/game/players/${lastplayer} ~/.zen/game/players/.current && CURRENT=${lastplayer}

UPLANETG1PUB=$(${MY_PATH}/tools/keygen -t duniter "${UPLANETNAME}" "${UPLANETNAME}")

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    printf "║%*s║\n" $((78)) ""
    printf "║%*s%s%*s║\n" $(((78-${#1})/2)) "" "$1" $(((78-${#1})/2)) ""
    printf "║%*s║\n" $((78)) ""
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo -e "${CYAN}"
    echo "┌──────────────────────────────────────────────────────────────────────────────┐"
    printf "│ %-76s │\n" "$1"
    echo "└──────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

print_status() {
    local service="$1"
    local status="$2"
    local details="$3"

    if [[ "$status" == "ACTIVE" ]]; then
        printf "  ✅ %-20s ${GREEN}%-10s${NC} %s\n" "$service" "$status" "$details"
    elif [[ "$status" == "INACTIVE" ]]; then
        printf "  ❌ %-20s ${RED}%-10s${NC} %s\n" "$service" "$status" "$details"
    else
        printf "  ⚠️  %-20s ${YELLOW}%-10s${NC} %s\n" "$service" "$status" "$details"
    fi
}

show_welcome() {
    clear
    print_header "ASTROPORT.ONE - STATION ZEN"

    echo -e "${WHITE}Node ID:${NC} $IPFSNODEID"
    echo -e "${WHITE}Capitaine:${NC} ${CURRENT:-'Non connecté'}"
    echo -e "${WHITE}UPlanet:${NC} $UPLANETG1PUB"
    echo ""

    echo -e "${CYAN}Astroport est un moteur Web3 exécutant UPlanet sur IPFS${NC}"
    echo "Il vous permet de:"
    echo "  • Gérer votre identité numérique (ZEN Card)"
    echo "  • Participer au réseau social NOSTR"
    echo "  • Stocker et partager des fichiers (uDRIVE)"
    echo "  • Gagner des récompenses (0.1 G1 par like)"
    echo ""

    echo -e "${YELLOW}Niveaux de capitaine:${NC}"
    echo "  X: Clé IPFS standard" UPlanet ORIGIN
    echo "  Y: Clé SSH jumelle" UPlanet Ẑen
    echo "  Z: Clé PGP/Yubikey" UPlanet PGP
    echo ""

    echo -e "${GREEN}Services disponibles:${NC}"
    print_status "IPFS" "ACTIVE" "(Stockage distribué)"
    print_status "NOSTR" "ACTIVE" "(Réseau social)"
    print_status "NextCloud" "ACTIVE" "(Stockage personnel)"
    print_status "uSPOT" "ACTIVE" "(Services locaux)"
    echo ""
}

show_main_menu() {
    print_section "MENU PRINCIPAL"
    echo "1. 🎫 Gérer ZEN Card"
    echo "2. 🌐 Connexion Swarm"
    echo "3. 📊 Statut Swarm"
    echo "4. 🔌 Déconnexion"
    echo "5. 💫 Faire un vœu"
    echo "6. 📱 Applications"
    echo "7. ⚙️  Configuration"
    echo "0. ❌ Quitter"
    echo ""
}

## VERIFY SOFTWARE DEPENDENCIES
[[ ! $(which ipfs) ]] && echo "EXIT. Vous devez avoir installé ipfs CLI sur votre ordinateur" && echo "https://dist.ipfs.io/#go-ipfs" && exit 1
YOU=$(pgrep -au $USER -f "ipfs daemon" > /dev/null && echo "$USER")
[[ ! $YOU ]] && echo "Lancez 'ipfs daemon' SVP sudo systemctl start ipfs" && exit 1


if [[ ${CURRENT} == "" ]]; then
    ## NO CAPTAIN
    echo "NO CAPTAIN ONBOARD !!!"
fi

echo 'PRESS CTRL+C or ENTER... '; read
## CREATE AND OR CONNECT USER
PS3=' ____ Select  ___ ? '
players=( "MULTIPASS" "ZENCARD" "DELETE" "PRINT" $(ls ~/.zen/game/players  | grep "@" 2>/dev/null))
## MULTIPLAYER

select fav in "${players[@]}"; do
    case $fav in

    "MULTIPASS")
        # Récupérer les informations de géolocalisation
        GEO_INFO=$(curl -s ipinfo.io/json)

        echo "'Email ?'"
        read EMAIL
        [[ ${EMAIL} == "" ]] && break

        # Extraire la latitude et la longitude
        echo "'Latitude ?'"
        read LAT
        [[ ${LAT} == "" ]] && LAT=$(makecoord $(echo "$GEO_INFO" | jq -r '.loc' | cut -d',' -f1))
        echo "'Longitude ?'"
        read LON
        [[ ${LON} == "" ]] && LON=$(makecoord $(echo "$GEO_INFO" | jq -r '.loc' | cut -d',' -f2))

        # Si la récupération échoue ou retourne vide, utiliser des valeurs par défaut
        [[ -z "$LAT" || "$LAT" == "null" ]] && LAT="0.00"
        echo -e "Latitude: ${LAT}"
        [[ -z "$LON" || "$LON" == "null" ]] && LON="0.00"
        echo -e "Longitude: ${LON}"

        echo "${MY_PATH}/tools/make_NOSTRCARD.sh" "${EMAIL}" "fr" "${LAT}" "${LON}"
        ${MY_PATH}/tools/make_NOSTRCARD.sh "${EMAIL}" "fr" "${LAT}" "${LON}"
        echo "Astronaute $fav bienvenue sur UPlanet..."

        exit
        ;;

    "ZENCARD")
        echo "'Email ?'"
        read EMAIL
        [[ ${EMAIL} == "" ]] && break
        echo "'Secret 1'"
        read PPASS
        [[ ${PPASS} == "" ]] \
            && PPASS=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
        echo "'Secret 2'"
        read NPASS
        [[ ${NPASS} == "" ]] \
            && NPASS=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
        echo "'Latitude ?'"
        read LAT
        [[ ${LAT} == "" ]] && LAT="0.00"
        echo "'Longitude ?'"
        read LON
        [[ ${LON} == "" ]] && LON="0.00"
        echo "'NPUB (NOSTR Card) ?'"
        read NPUB
        [[ ${NPUB} != "" ]] && HEX=$(${MY_PATH}/tools/nostr2hex.py $NPUB)

        echo "${MY_PATH}/RUNTIME/VISA.new.sh" "${PPASS}" "${NPASS}" "${EMAIL}" "UPlanet" "fr" "${LAT}" "${LON}" "${NPUB}" "${HEX}"
        ${MY_PATH}/RUNTIME/VISA.new.sh "${PPASS}" "${NPASS}" "${EMAIL}" "UPlanet" "fr" "${LAT}" "${LON}" "${NPUB}" "${HEX}"
        fav=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null) && rm ~/.zen/tmp/PSEUDO
        echo "Astronaute $fav bienvenue sur UPlanet..."
        exit
        ;;

    "DELETE")
        echo "DELETE"
        ${MY_PATH}/tools/nostr_DESTROY_TW.sh
        exit
        ;;

    "PRINT")
        echo "Choisissez le type de carte à imprimer:"
        echo "1) MULTIPASS"
        echo "2) ZENCARD"
        read CARD_TYPE

        case $CARD_TYPE in
            "1"|"MULTIPASS")
                ## DIRECT MULTIPASS print
                NOSTR=$(ls ~/.zen/game/nostr  | grep "@" 2>/dev/null)
                if [ -z "$NOSTR" ]; then
                    echo "No MULTIPASS cards found"
                    exit
                fi

                echo "Available MULTIPASS cards:"
                echo "$NOSTR" | nl
                echo "'Enter card number :'"
                read NUM

                if [ -z "$NUM" ]; then
                    EMAIL=$(echo "$NOSTR" | head -n 1)
                else
                    EMAIL=$(echo "$NOSTR" | sed -n "${NUM}p")
                fi

                [[ -f ~/.zen/game/nostr/$EMAIL/.nostr.zine.html ]] \
                    && xdg-open ~/.zen/game/nostr/$EMAIL/.nostr.zine.html \
                    || echo "NO MULTIPASS FOUND"

                exit
                ;;

            "2"|"ZENCARD")
                ## DIRECT VISA.print.sh
                echo "'Email ?'"
                read EMAIL
                [[ ${EMAIL} == "" ]] && EMAIL=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
                echo "'Secret 1 ?'"
                read SALT
                [[ ${SALT} == "" ]] && SALT=$(${MY_PATH}/tools/diceware.sh 4 | xargs)
                echo "'Secret 2?'"
                read PEPPER
                [[ ${PEPPER} == "" ]] && PEPPER=$(${MY_PATH}/tools/diceware.sh 4 | xargs)
                echo "'PIN ?'"
                read PASS

                echo "${MY_PATH}/tools/VISA.print.sh" "${EMAIL}"  "'"$SALT"'" "'"$PEPPER"'" "'"$PASS"'"
                ${MY_PATH}/tools/VISA.print.sh "${EMAIL}"  "$SALT" "$PEPPER" "$PASS" ##

                [[ ${EMAIL} != "" && ${EMAIL} != $(cat ~/.zen/game/players/.current/.player 2>/dev/null) ]] \
                    && rm -Rf ~/.zen/game/players/${EMAIL}/

                exit
                ;;

            *)
                echo "Option invalide"
                exit
                ;;
        esac
        ;;

    "")
        echo "Choix obligatoire. exit"
        exit
        ;;
    *) echo "Salut $fav"
        break
        ;;
    esac
done
PLAYER=$fav

####### NO CURRENT ? PLAYER = .current
[[ ! -d $(readlink ~/.zen/game/players/.current) ]] \
    && rm -f ~/.zen/game/players/.current \
    && ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current

pass=$(cat ~/.zen/game/players/$PLAYER/.pass 2>/dev/null)
########################################## DEVEL
echo "ENTER PASS -- FREE MODE -- $pass" && read PASS

## DECODE CURRENT PLAYER CRYPTO
# echo "********* DECODAGE SecuredSocketLayer *********"
# rm -f ~/.zen/tmp/${PLAYER}.dunikey 2>/dev/null
# openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/${PLAYER}/enc.secret.dunikey" -out "$HOME/.zen/tmp/${PLAYER}.dunikey" -k $pass 2>&1>/dev/null
[[ $PASS != $pass ]] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

## CURRENT CHANGE ?
#~ [[  ${CURRENT} !=  ${PLAYER} ]] \
#~ && echo "BECOME ADMIN ? hit ENTER for NO, write something for YES" && read ADM \
#~ && [[ ${ADM} != "" ]] \
#~ && rm -f ~/.zen/game/players/.current \
#~ && ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current

echo "________LOGIN OK____________";
echo
echo "DECHIFFRAGE CLEFS ASTRONAUTE"
echo "PASS Astroport.ONE  : $(cat ~/.zen/game/players/$PLAYER/.pass 2>/dev/null)"
export G1PUB=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
[ ! ${G1PUB} ] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

echo "G1PUB Astronaute : $G1PUB"
echo "ENTREE ACCORDEE"
echo
export ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | head -n1 | cut -d ' ' -f 1)

echo "$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null) TW/Moa"
echo "$myIPFS/ipns/$ASTRONAUTENS"
echo "Activation Réseau P2P Astroport !"

[[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && xdg-open "http://ipfs.localhost:8080/ipns/$ASTRONAUTENS"

echo
PS3="$PLAYER choose : __ "
choices=("PRINT VISA" "SWARM CONNECT" "SWARM STATUS" "UNPLUG PLAYER" "QUIT")
select fav in  "${choices[@]}"; do
    case $fav in
    "PRINT VISA")
        echo "IMPRESSION"
        ${MY_PATH}/tools/VISA.print.sh "$PLAYER"
        ;;

    "SWARM CONNECT")
        echo "🌐 GESTION DE L'ESSAIM UPlanet"
        echo "Découverte et connexion aux autres ♥️box..."
        ${MY_PATH}/RUNTIME/SWARM.discover.sh
        ;;

    "SWARM STATUS")
        echo "📊 STATUT DE L'ESSAIM UPlanet"
        echo "Notifications et abonnements reçus..."
        ${MY_PATH}/tools/SWARM.notifications.sh
        ;;

    "UNPLUG PLAYER")
        echo "ATTENTION ${PLAYER} DECONNEXION DE VOTRE TW !!"
        echo  "Enter to continue. Ctrl+C to stop"
        read
        ${MY_PATH}/RUNTIME/PLAYER.unplug.sh "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}"

        break
        ;;

    #~ "AJOUTER VLOG")
        #~ echo "Lancement Webcam..."
        #~ ${MY_PATH}/tools/vlc_webcam.sh "$PLAYER"
        #~ ;;

    "MAKE A WHISH")
        echo "QRCode à coller sur les lieux ou objets portant une Gvaleur"
        cp ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html
        ${MY_PATH}/RUNTIME/G1Voeu.sh "" "$PLAYER" "$HOME/.zen/tmp/$PLAYER.html"
        DIFF=$(diff ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html)
        if [[ $DIFF ]]; then
            echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats
            cp   ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
                    ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)

            TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
            ipfs name publish --key=$PLAYER /ipfs/$TW

            echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
        fi
    echo "================================================"
    echo "$PLAYER : $myIPFS/ipns/$ASTRONAUTENS"
    echo "================================================"
        ;;

    "PRINT QRVOEU")
        ${MY_PATH}/tools/VOEUX.print.sh $PLAYER
        ;;

    "QUIT")
        echo "CIAO" && exit 0
        ;;

    "")
        echo "Mauvais choix."
        ;;

    esac
done

# Main loop
while true; do
    show_welcome
    show_main_menu
    read -p "Votre choix: " choice

    case $choice in
        1)
            print_section "GESTION ZEN CARD"
            echo "1. Imprimer VISA"
            echo "2. Créer nouvelle ZEN Card"
            echo "3. Personnaliser ZEN Card"
            echo "0. Retour"
            read -p "Choix: " card_choice

            case $card_choice in
                1) "${MY_PATH}/tools/VISA.print.sh" "$PLAYER" ;;
                2)
                    echo -e "${CYAN}Création d'une nouvelle ZEN Card${NC}"
                    read -p "Email: " EMAIL
                    read -p "Secret 1: " SALT
                    read -p "Secret 2: " PEPPER
                    read -p "PIN (4 chiffres): " PASS
                    "${MY_PATH}/tools/VISA.print.sh" "$EMAIL" "$SALT" "$PEPPER" "$PASS"
                    ;;
                3)
                    echo -e "${YELLOW}Personnalisation à venir...${NC}"
                    ;;
            esac
            ;;
        2)
            print_section "CONNEXION SWARM"
            echo "Découverte et connexion aux autres ♥️box..."
            "${MY_PATH}/RUNTIME/SWARM.discover.sh"
            ;;
        3)
            print_section "STATUT SWARM"
            echo "Notifications et abonnements reçus..."
            "${MY_PATH}/tools/SWARM.notifications.sh"
            ;;
        4)
            print_section "DÉCONNEXION"
            echo -e "${RED}ATTENTION: Déconnexion de votre TW !${NC}"
            read -p "Appuyez sur ENTRÉE pour continuer (Ctrl+C pour annuler)..."
            "${MY_PATH}/RUNTIME/PLAYER.unplug.sh" "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}"
            ;;
        5)
            print_section "FAIRE UN VŒU"
            echo "Création d'un QR Code pour les lieux ou objets portant une Gvaleur..."
            "${MY_PATH}/RUNTIME/G1Voeu.sh" "" "$PLAYER" "$HOME/.zen/tmp/$PLAYER.html"
            ;;
        6)
            print_section "APPLICATIONS"
            echo "1. Interface web (http://astroport.localhost:1234)"
            echo "2. CLI (command.sh)"
            echo "3. Applications mobiles"
            echo "0. Retour"
            read -p "Choix: " app_choice

            case $app_choice in
                1) xdg-open "http://astroport.localhost:1234" ;;
                2) echo "Vous utilisez déjà la CLI" ;;
                3) echo "Applications mobiles à venir..." ;;
            esac
            ;;
        7)
            print_section "CONFIGURATION"
            echo "1. Paramètres IPFS"
            echo "2. Configuration réseau"
            echo "3. Paramètres économiques"
            echo "0. Retour"
            read -p "Choix: " config_choice

            case $config_choice in
                1) echo "Configuration IPFS..." ;;
                2) echo "Configuration réseau..." ;;
                3) echo "Paramètres économiques..." ;;
            esac
            ;;
        0)
            echo -e "${GREEN}Au revoir !${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Choix invalide${NC}"
            sleep 1
            ;;
    esac

    [[ $choice != "0" ]] && { echo ""; read -p "Appuyez sur ENTRÉE pour continuer..."; }
done

exit 0
