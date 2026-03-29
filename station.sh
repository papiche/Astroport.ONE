#!/bin/bash
########################################################################
# station.sh — Interface unifiée de gestion Astroport.ONE
#
# Remplace command.sh + captain.sh (trop volumineux, logique éparpillée)
# Délègue à : UPLANET.official.sh, VISA.new.sh, make_NOSTRCARD.sh,
#             PLAYER.refresh.sh, NOSTRCARD.refresh.sh, oc2uplanet.sh
#
# Paramètres : kind 30800 (DID utilisateur) & 30850 (config coopérative)
#              via tools/cooperative_config.sh (partagé sur toute la constellation)
#
# Usage : ./station.sh [--auto] [--email EMAIL]
########################################################################
MY_PATH="$(cd "$(dirname "$0")" && pwd)"

## ── Chargement des variables système ────────────────────────────────
. "${MY_PATH}/tools/my.sh" 2>/dev/null

## ── Paramètres : .env local EN PRIORITÉ, puis kind 30800/30850 ───────
## Ordre de résolution :
##   1. ~/.zen/Astroport.ONE/.env  (PAF, NCARD, ZCARD, ZCARD_SATELLITE...)
##   2. my.sh  (variables calculées : UPLANETNAME, CAPTAINEMAIL, etc.)
##   3. DID NOSTR kind 30800/30850 via cooperative_config.sh (fallback essaim)
## → Les valeurs déjà définies dans .env NE SONT PAS écrasées par le DID.
if [[ -f "${MY_PATH}/tools/cooperative_config.sh" ]]; then
    source "${MY_PATH}/tools/cooperative_config.sh" 2>/dev/null
    coop_load_env_vars 2>/dev/null || true
fi

## ── Couleurs ─────────────────────────────────────────────────────────
G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'
R='\033[0;31m'; B='\033[0;34m'; W='\033[1;37m'; N='\033[0m'

## ── Capitaine courant ────────────────────────────────────────────────
CAPTAIN=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
CAPTAIN_G1PUB=""
[[ -n "$CAPTAIN" ]] && CAPTAIN_G1PUB=$(grep 'pub:' ~/.zen/game/players/${CAPTAIN}/secret.dunikey 2>/dev/null | cut -d' ' -f2)

## ── Arguments CLI ────────────────────────────────────────────────────
AUTO=false; PRESET_EMAIL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) AUTO=true; shift ;;
        --email) PRESET_EMAIL="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--auto] [--email EMAIL]"
            echo "  --auto   Mode non-interactif (création GMARKMAIL)"
            echo "  --email  Email pré-rempli"
            exit 0 ;;
        *) shift ;;
    esac
done

## ═══════════════════════════════════════════════════════════════════════
## FONCTIONS UTILITAIRES
## ═══════════════════════════════════════════════════════════════════════

header() {
    clear
    echo -e "${B}╔══════════════════════════════════════════════════════════════╗${N}"
    printf  "${B}║${W}  %-60s${B}║${N}\n" "$1"
    echo -e "${B}╚══════════════════════════════════════════════════════════════╝${N}"
    echo ""
}

section() { echo -e "${C}── $1 ──────────────────────────────────────────────────${N}"; }

wallet_balance() {
    local pub="$1"
    [[ -z "$pub" ]] && echo "?" && return
    cat ~/.zen/tmp/coucou/${pub}.COINS 2>/dev/null \
        || "${MY_PATH}/tools/G1check.sh" "$pub" 2>/dev/null | tail -1 \
        || echo "?"
}

ask() {
    local prompt="$1" default="$2" var
    read -p "${prompt} [${default}]: " var
    echo "${var:-$default}"
}

pause() { read -p "${Y}↵ ENTRÉE pour continuer...${N}" _; }

## ═══════════════════════════════════════════════════════════════════════
## TABLEAU DE BORD
## ═══════════════════════════════════════════════════════════════════════

show_dashboard() {
    header "⚓ ASTROPORT.ONE — Station Dashboard"

    ## Réseau
    section "Réseau"
    local net_mode="UPlanet ORIGIN (sandbox)"
    [[ "${UPLANETNAME}" != "000"*"000" && -n "${UPLANETNAME}" ]] \
        && net_mode="UPlanet ẐEN (${myDOMAIN:-?})"
    echo -e "  ${W}Mode      :${N} $net_mode"
    echo -e "  ${W}Nœud IPFS :${N} ${IPFSNODEID:0:16}..."
    echo -e "  ${W}Capitaine :${N} ${CAPTAIN:-${R}non configuré${N}}"
    [[ -n "$CAPTAIN_G1PUB" ]] && \
        echo -e "  ${W}G1PUB     :${N} ${CAPTAIN_G1PUB:0:20}..."
    echo ""

    ## Paramètres coopératifs (kind 30800/30850)
    section "Paramètres coopératifs (kind 30800/30850)"
    echo -e "  NCARD=${NCARD:-1} Ẑ/sem | ZCARD=${ZCARD:-4} Ẑ/sem | PAF=${PAF:-14} Ẑ/sem | TVA=${TVA_RATE:-0}%"
    echo -e "  Satellite=${ZENCARD_SATELLITE:-50} Ẑ | Constellation=${ZENCARD_CONSTELLATION:-540} Ẑ"
    echo ""

    ## Services
    section "Services"
    _svc() {
        local name="$1" port="$2"
        curl -sf --max-time 1 "http://127.0.0.1:${port}/" &>/dev/null \
            && echo -e "  ${G}✅${N} ${name} (:${port})" \
            || echo -e "  ${R}❌${N} ${name} (:${port})"
    }
    _svc "Astroport"  12345
    _svc "UPassport"  54321
    _svc "IPFS GW"    8080
    _svc "NPM Admin"  81
    docker ps --format "  ${G}🐳${N} {{.Names}}: {{.Status}}" 2>/dev/null | head -8
    echo ""

    ## Comptes
    section "Comptes locaux"
    local nb_mp nb_zc
    nb_mp=$(ls ~/.zen/game/nostr/ 2>/dev/null | grep -c '@' || echo 0)
    nb_zc=$(ls ~/.zen/game/players/ 2>/dev/null | grep -c '@' || echo 0)
    echo -e "  MULTIPASS : ${W}${nb_mp}${N} | ZEN Card : ${W}${nb_zc}${N}"
    echo ""

    ## Portefeuilles principaux
    if [[ -n "$CAPTAIN_G1PUB" ]]; then
        section "Portefeuilles capitaine"
        local g1=$(wallet_balance "$CAPTAIN_G1PUB")
        echo -e "  ZEN Card capitaine : ${Y}${g1} Ğ1${N}"
        local mp_pub
        mp_pub=$(cat ~/.zen/game/nostr/${CAPTAIN}/G1PUBNOSTR 2>/dev/null)
        [[ -n "$mp_pub" ]] && echo -e "  MULTIPASS         : ${Y}$(wallet_balance "$mp_pub") Ğ1${N}"
        echo ""
    fi
}

## ═══════════════════════════════════════════════════════════════════════
## GESTION IDENTITÉS MULTIPASS & ZEN CARD
## ═══════════════════════════════════════════════════════════════════════

menu_identites() {
    header "🎫 Identités MULTIPASS & ZEN Card"
    echo -e "  ${G}1.${N} Créer un nouveau MULTIPASS"
    echo -e "  ${G}2.${N} Créer une ZEN Card (à partir d'un MULTIPASS)"
    echo -e "  ${G}3.${N} Lister MULTIPASS et ZEN Cards"
    echo -e "  ${G}4.${N} Changer de Capitaine (sélection ZEN Card)"
    echo -e "  ${G}5.${N} Création automatique GMARKMAIL (hostname + GPS)"
    echo -e "  ${G}0.${N} Retour"
    echo ""
    read -p "Choix : " c
    case "$c" in
        1) _create_multipass ;;
        2) _create_zencard ;;
        3) _list_identites ;;
        4) _switch_captain ;;
        5) "${MY_PATH}/install/setup/setup.sh" create_gmarkmail 2>/dev/null \
              || echo "Relancez setup.sh directement pour la création GMARKMAIL" ;;
        0) return ;;
    esac
}

_create_multipass() {
    header "➕ Nouveau MULTIPASS"
    local email lat lon lang
    email=$(ask "📧 Email" "${PRESET_EMAIL:-}")
    [[ -z "$email" ]] && echo "Email requis." && pause && return
    local geo; geo=$(curl -s --max-time 5 ipinfo.io/json 2>/dev/null)
    lat=$(echo "$geo" | jq -r '.loc // "0.00"' | cut -d',' -f1 2>/dev/null)
    lon=$(echo "$geo" | jq -r '.loc // "0.00"' | cut -d',' -f2 2>/dev/null)
    lat=$(ask "📍 Latitude" "${lat:-0.00}")
    lon=$(ask "📍 Longitude" "${lon:-0.00}")
    lang=$(ask "🌐 Langue" "${LANG:0:2}")
    echo ""
    echo "Création MULTIPASS pour ${email}..."
    ## NOMAIL=1 → mailjet appelé après avec sujet personnalisé
    NOMAIL=1 "${MY_PATH}/tools/make_NOSTRCARD.sh" "$email" "$lang" "$lat" "$lon" \
        && "${MY_PATH}/tools/mailjet.sh" --expire 0s "$email" \
               "${HOME}/.zen/game/nostr/${email}/.nostr.zine.html" \
               "UPlanet MULTIPASS - $(${MY_PATH}/tools/clyuseryomail.sh "$email" 2>/dev/null)" \
        && echo -e "${G}✅ MULTIPASS créé pour $email${N}" \
        || echo -e "${R}❌ Erreur création MULTIPASS${N}"
    pause
}

_create_zencard() {
    header "🎫 Nouvelle ZEN Card"
    ## Lister MULTIPASS sans ZEN Card
    local mps=()
    for mp in $(ls ~/.zen/game/nostr/ 2>/dev/null | grep '@'); do
        [[ ! -d ~/.zen/game/players/${mp} ]] && mps+=("$mp")
    done
    if [[ ${#mps[@]} -eq 0 ]]; then
        echo "Aucun MULTIPASS sans ZEN Card. Créez d'abord un MULTIPASS."
        pause; return
    fi
    echo "MULTIPASS disponibles (sans ZEN Card) :"
    for i in "${!mps[@]}"; do echo "  $((i+1)). ${mps[$i]}"; done
    echo ""
    read -p "Numéro : " n
    [[ ! "$n" =~ ^[0-9]+$ || $n -lt 1 || $n -gt ${#mps[@]} ]] && return
    local email="${mps[$((n-1))]}"
    local mp_dir="$HOME/.zen/game/nostr/${email}"
    source "${mp_dir}/GPS" 2>/dev/null
    local npub; npub=$(cat "${mp_dir}/NPUB" 2>/dev/null)
    local hex;  hex=$(cat "${mp_dir}/HEX"  2>/dev/null)
    ## Secrets diceware
    local ppass npass
    ppass=$(${MY_PATH}/tools/diceware.sh 4 | xargs)
    npass=$(${MY_PATH}/tools/diceware.sh 4 | xargs)
    echo -e "  Secret 1 : ${C}${ppass}${N}"
    echo -e "  Secret 2 : ${C}${npass}${N}"
    echo ""
    read -p "Personnaliser ? (n/o) [n]: " custom
    if [[ "$custom" =~ ^(o|y|oui|yes)$ ]]; then
        read -p "Secret 1: " p2; [[ -n "$p2" ]] && ppass="$p2"
        read -p "Secret 2: " n2; [[ -n "$n2" ]] && npass="$n2"
    fi
    ## Bootstrap CAPTAINEMAIL si vide
    [[ -z "$CAPTAINEMAIL" ]] && export CAPTAINEMAIL="$email"
    local g1pub; g1pub=$(cat "${mp_dir}/G1PUBNOSTR" 2>/dev/null)
    [[ -n "$g1pub" ]] && export CAPTAING1PUB="$g1pub"
    echo "Création ZEN Card pour ${email}..."
    "${MY_PATH}/RUNTIME/VISA.new.sh" "$ppass" "$npass" "$email" "UPlanet" \
        "${LANG:0:2}" "${LAT:-0.00}" "${LON:-0.00}" "$npub" "$hex" \
        && echo -e "${G}✅ ZEN Card créée${N}" \
        || echo -e "${R}❌ Erreur création ZEN Card${N}"
    pause
}

_list_identites() {
    header "📋 Identités locales"
    section "MULTIPASS"
    for mp in $(ls ~/.zen/game/nostr/ 2>/dev/null | grep '@' | sort); do
        local g1; g1=$(cat ~/.zen/game/nostr/${mp}/G1PUBNOSTR 2>/dev/null | cut -c1-12)
        local zc_flag=""
        [[ -d ~/.zen/game/players/${mp} ]] && zc_flag=" ${G}+ZENCard${N}"
        echo "  • $mp  (${g1}...)${zc_flag}"
    done
    echo ""
    section "ZEN Cards"
    for zc in $(ls ~/.zen/game/players/ 2>/dev/null | grep '@' | sort); do
        local g1; g1=$(cat ~/.zen/game/players/${zc}/.g1pub 2>/dev/null | cut -c1-12)
        local bal; bal=$(wallet_balance "$(cat ~/.zen/game/players/${zc}/.g1pub 2>/dev/null)")
        local status=""
        [[ -s ~/.zen/game/players/${zc}/U.SOCIETY ]] && status=" ${G}⭐U.SOCIETY${N}"
        [[ "$(readlink ~/.zen/game/players/.current 2>/dev/null | rev | cut -d'/' -f1 | rev)" == "$zc" ]] \
            && status="${status} ${Y}← Capitaine${N}"
        echo "  • $zc  (${g1}...)  ${bal} Ğ1${status}"
    done
    echo ""
    pause
}

_switch_captain() {
    header "🔄 Changer de Capitaine"
    local zcs=()
    for zc in $(ls ~/.zen/game/players/ 2>/dev/null | grep '@' | sort); do
        zcs+=("$zc")
    done
    [[ ${#zcs[@]} -eq 0 ]] && echo "Aucune ZEN Card." && pause && return
    for i in "${!zcs[@]}"; do echo "  $((i+1)). ${zcs[$i]}"; done
    echo ""
    read -p "Numéro : " n
    [[ ! "$n" =~ ^[0-9]+$ || $n -lt 1 || $n -gt ${#zcs[@]} ]] && return
    local sel="${zcs[$((n-1))]}"
    rm -f ~/.zen/game/players/.current
    ln -s ~/.zen/game/players/${sel} ~/.zen/game/players/.current
    CAPTAIN="$sel"
    echo -e "${G}✅ Capitaine → ${sel}${N}"
    pause
}

## ═══════════════════════════════════════════════════════════════════════
## TRANSACTIONS OFFICIELLES (UPLANET.official.sh)
## ═══════════════════════════════════════════════════════════════════════

menu_transactions() {
    header "💰 Transactions Officielles (UPLANET.official.sh)"
    echo -e "  ${G}1.${N} Recharge MULTIPASS locataire (ZENCOIN)"
    echo -e "  ${G}2.${N} Virement Sociétaire Satellite   (${ZENCARD_SATELLITE:-50} Ẑen/an)"
    echo -e "  ${G}3.${N} Virement Sociétaire Constellation (${ZENCARD_CONSTELLATION:-540} Ẑen/3ans)"
    echo -e "  ${G}4.${N} Apport Capital Infrastructure"
    echo -e "  ${G}5.${N} Lancer UPLANET.official.sh (mode interactif complet)"
    echo -e "  ${G}6.${N} Contrôle portefeuilles relais (excédents)"
    echo -e "  ${G}0.${N} Retour"
    echo ""
    read -p "Choix : " c
    case "$c" in
        1)  local email; email=$(ask "Email MULTIPASS" "")
            local m; m=$(ask "Montant Ẑen" "${NCARD:-50}")
            "${MY_PATH}/UPLANET.official.sh" -l "$email" -m "$m"
            pause ;;
        2)  local email; email=$(ask "Email Sociétaire" "")
            "${MY_PATH}/UPLANET.official.sh" -s "$email" -t satellite
            pause ;;
        3)  local email; email=$(ask "Email Sociétaire" "")
            "${MY_PATH}/UPLANET.official.sh" -s "$email" -t constellation
            pause ;;
        4)  local email="${CAPTAIN:-}"
            [[ -z "$email" ]] && email=$(ask "Email Capitaine" "")
            local m; m=$(ask "Montant Ẑen" "${MACHINE_VALUE_ZEN:-500}")
            "${MY_PATH}/UPLANET.official.sh" -i -m "$m"
            pause ;;
        5)  "${MY_PATH}/UPLANET.official.sh"; pause ;;
        6)  "${MY_PATH}/UPLANET.official.sh" --check-relay 2>/dev/null \
                || echo "Utilisez UPLANET.official.sh directement pour ce diagnostic"
            pause ;;
        0) return ;;
    esac
}

## ═══════════════════════════════════════════════════════════════════════
## OPEN COLLECTIVE ↔ UPLANET (oc2uplanet.sh)
## ═══════════════════════════════════════════════════════════════════════

menu_opencollective() {
    header "💳 OpenCollective ↔ UPlanet (oc2uplanet.sh)"

    ## Charger OCAPIKEY depuis kind 30800/30850 si absent
    local ocapikey="${OCAPIKEY:-$(coop_config_get "OCAPIKEY" 2>/dev/null)}"
    local ocslug="${OCSLUG:-$(coop_config_get "OCSLUG" 2>/dev/null)}"

    echo -e "  OCSLUG   : ${W}${ocslug:-${R}non configuré${N}${W}}${N}"
    if [[ -n "$ocapikey" ]]; then
        echo -e "  OCAPIKEY : ${G}✅ chargé (${ocapikey:0:8}...)${N}"
    else
        echo -e "  OCAPIKEY : ${R}❌ manquant${N}"
        echo -e "  ${Y}→ Configurez via captain.sh ou cooperative_config.sh${N}"
    fi
    echo ""
    echo -e "  ${G}1.${N} Synchroniser les dons OC → ẐEN (oc2uplanet.sh)"
    echo -e "  ${G}2.${N} Voir le log d'émission (data/emission.log)"
    echo -e "  ${G}3.${N} Configurer OCAPIKEY (kind 30800/30850)"
    echo -e "  ${G}0.${N} Retour"
    echo ""
    read -p "Choix : " c
    case "$c" in
        1)  local oc_dir="${MY_PATH}/../OC2UPlanet"
            if [[ -x "${oc_dir}/oc2uplanet.sh" ]]; then
                echo "Lancement OC2UPlanet..."
                (cd "$oc_dir" && bash oc2uplanet.sh)
            else
                echo -e "${R}❌ OC2UPlanet/oc2uplanet.sh introuvable${N}"
                echo "   Vérifiez que le dépôt OC2UPlanet est présent."
            fi
            pause ;;
        2)  local log="${MY_PATH}/../OC2UPlanet/data/emission.log"
            [[ -s "$log" ]] && tail -30 "$log" || echo "Log vide ou absent."
            pause ;;
        3)  echo ""
            read -s -p "OCAPIKEY : " apikey; echo ""
            [[ -z "$apikey" ]] && return
            read -p "OCSLUG   : " slug
            coop_config_set "OCAPIKEY" "$apikey" 2>/dev/null \
                && coop_config_set "OCSLUG" "$slug" 2>/dev/null \
                && echo -e "${G}✅ OCAPIKEY/OCSLUG sauvegardés dans le DID coopératif (kind 30800)${N}" \
                || echo -e "${Y}⚠️  Sauvegarde DID échouée — ajoutez dans OC2UPlanet/.env${N}"
            pause ;;
        0) return ;;
    esac
}

## ═══════════════════════════════════════════════════════════════════════
## INFRASTRUCTURE
## ═══════════════════════════════════════════════════════════════════════

menu_infrastructure() {
    header "🛠️ Infrastructure"
    echo -e "  ${G}1.${N} Services : start / stop / status"
    echo -e "  ${G}2.${N} NextCloud AIO (démarrer / setup)"
    echo -e "  ${G}3.${N} Cycle économique (20h12.process.sh)"
    echo -e "  ${G}4.${N} Refresh PLAYER (ZINEs + paiements)"
    echo -e "  ${G}5.${N} Refresh NOSTRCARD (IPNS + DID)"
    echo -e "  ${G}6.${N} LeAnn (indexation NextCloud → Qdrant)"
    echo -e "  ${G}7.${N} Pare-feu UFW (status / ON / OFF)"
    echo -e "  ${G}8.${N} Logs Docker temps réel"
    echo -e "  ${G}0.${N} Retour"
    echo ""
    read -p "Choix : " c
    case "$c" in
        1)  echo "1=start  2=stop  3=status"; read -p "Action: " a
            case "$a" in
                1) "${MY_PATH}/start.sh" ;;
                2) "${MY_PATH}/stop.sh" ;;
                3) systemctl status astroport ipfs upassport strfry 2>/dev/null || \
                   docker ps ;;
            esac; pause ;;
        2)  local nc_compose="${MY_PATH}/_DOCKER/nextcloud/docker-compose.yml"
            if [[ -f "$nc_compose" ]]; then
                echo "1=démarrer AIO  2=ouvrir setup (https://127.0.0.1:8443)"
                read -p "Action: " a
                [[ "$a" == "1" ]] && docker compose -f "$nc_compose" up -d \
                    && "${MY_PATH}/install/setup/setup_npm.sh"
                [[ "$a" == "2" ]] && xdg-open "https://127.0.0.1:8443" 2>/dev/null
            else
                echo -e "${R}❌ NextCloud non installé${N}"
                echo "   Relancez : bash install.sh \"\" \"\" \"\" nextcloud"
            fi
            pause ;;
        3)  "${MY_PATH}/20h12.process.sh"; pause ;;
        4)  "${MY_PATH}/RUNTIME/PLAYER.refresh.sh"; pause ;;
        5)  "${MY_PATH}/RUNTIME/NOSTRCARD.refresh.sh"; pause ;;
        6)  bash "${MY_PATH}/install/install_leann.sh"; pause ;;
        7)  echo "1=status  2=ON  3=OFF"; read -p "Action: " a
            case "$a" in
                1) "${MY_PATH}/tools/firewall.sh" STATUS ;;
                2) "${MY_PATH}/tools/firewall.sh" ON ;;
                3) "${MY_PATH}/tools/firewall.sh" OFF ;;
            esac; pause ;;
        8)  docker compose logs -f --tail=50; pause ;;
        0) return ;;
    esac
}

## ═══════════════════════════════════════════════════════════════════════
## MENU PRINCIPAL
## ═══════════════════════════════════════════════════════════════════════

main_menu() {
    while true; do
        show_dashboard

        echo -e "${W}Menu principal :${N}"
        echo -e "  ${G}1.${N} 🎫  Identités (MULTIPASS / ZEN Card)"
        echo -e "  ${G}2.${N} 💰  Transactions officielles (UPLANET.official.sh)"
        echo -e "  ${G}3.${N} 💳  OpenCollective ↔ UPlanet (oc2uplanet.sh)"
        echo -e "  ${G}4.${N} 🛠️   Infrastructure (Docker / Services / NextCloud)"
        echo -e "  ${G}5.${N} ⚙️   Configuration coopérative (kind 30800/30850)"
        echo -e "  ${G}6.${N} 📊  Dashboard Capitaine (captain.sh)"
        echo -e "  ${G}7.${N} 🔄  Actualiser les soldes"
        echo -e "  ${G}0.${N} ❌  Quitter"
        echo ""
        read -p "Choix : " choice

        case "$choice" in
            1) menu_identites ;;
            2) menu_transactions ;;
            3) menu_opencollective ;;
            4) menu_infrastructure ;;
            5) ## Config coopérative — déléguer à captain.sh qui a l'UI complète
               "${MY_PATH}/captain.sh" --coop-config 2>/dev/null \
                   || "${MY_PATH}/captain.sh"
               ;;
            6) "${MY_PATH}/captain.sh" ;;
            7) header "🔄 Actualisation des soldes"
               for w in $(ls ~/.zen/game/nostr/*/G1PUBNOSTR 2>/dev/null); do
                   local pub; pub=$(cat "$w")
                   [[ -n "$pub" ]] && "${MY_PATH}/tools/G1check.sh" "$pub" &>/dev/null &
               done
               for w in $(ls ~/.zen/game/players/*/.g1pub 2>/dev/null); do
                   local pub; pub=$(cat "$w")
                   [[ -n "$pub" ]] && "${MY_PATH}/tools/G1check.sh" "$pub" &>/dev/null &
               done
               wait
               echo -e "${G}✅ Soldes actualisés${N}"
               pause ;;
            0) echo -e "${G}Au revoir, Capitaine !${N}"; exit 0 ;;
            *) echo "Choix invalide"; sleep 1 ;;
        esac
    done
}

## ── Mode auto (sans capitaine → création GMARKMAIL) ─────────────────
if [[ "$AUTO" == "true" && -z "$CAPTAIN" ]]; then
    echo "Mode --auto : création GMARKMAIL..."
    "${MY_PATH}/install/setup/setup.sh" 2>/dev/null || \
        "${MY_PATH}/command.sh" 2>/dev/null
    exit $?
fi

## ── Lancement ────────────────────────────────────────────────────────
main_menu
