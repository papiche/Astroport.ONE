#!/bin/bash
########################################################################
# zen_join.sh — Rejoindre une UPlanet ẐEN depuis une installation ORIGIN
#
# Après install.sh (ORIGIN), ce script reconfigure la station pour
# rejoindre un réseau coopératif ẐEN de production.
#
# Usage:
#   ./zen_join.sh <CAPTAIN_EMAIL> <DOMAIN> <SWARM_KEY_HEX>
#   ./zen_join.sh cap@zen.coop zen.coop a1b2c3...64hex
#   ./zen_join.sh cap@zen.coop zen.coop /path/to/swarm.key
#
# Ce script :
#   1. Nettoie les comptes et wallets ORIGIN
#   2. Installe la swarm.key ẐEN
#   3. Régénère le .env pour le nouveau domaine
#   4. Passe au niveau Y (jumelage SSH/IPFS)
#   5. Crée le capitaine avec son email
#   6. Initialise les portefeuilles coopératifs (UPLANET.init.sh)
#   7. Configure OpenCollective (OC2UPlanet)
#   8. Redémarre les services
#
# Prérequis : install.sh terminé, services arrêtés
########################################################################
set -euo pipefail

MY_PATH="$(cd "$(dirname "$0")" && pwd)"
ME="${0##*/}"

## Couleurs
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

########################################################################
## VALIDATION
########################################################################
usage() {
    echo -e "${CYAN}Usage: $ME <CAPTAIN_EMAIL> <DOMAIN> <SWARM_KEY>${NC}"
    echo ""
    echo "  CAPTAIN_EMAIL   Email du capitaine (ex: cap@zen.coop)"
    echo "  DOMAIN          Nom de domaine (ex: zen.coop)"
    echo "  SWARM_KEY       Clé hex 64 caractères ou chemin vers fichier swarm.key"
    echo ""
    echo "Exemples:"
    echo "  $ME cap@zen.coop zen.coop a1b2c3d4...64hex"
    echo "  $ME cap@zen.coop zen.coop /tmp/swarm.key"
    echo ""
    echo "Variables optionnelles:"
    echo "  MACHINE_VALUE_ZEN=500  Valeur machine (defaut: 500)"
    echo "  PAF=14                 Cout hebdo noeud (defaut: 14)"
    echo "  NCARD=1                Frais MULTIPASS (defaut: 1)"
    echo "  ZCARD=4                Frais ZenCard (defaut: 4)"
    exit 1
}

[[ $# -lt 3 ]] && usage

CAPTAIN_EMAIL="$1"
DOMAIN="$2"
SWARM_KEY_ARG="$3"

## Valider l'email
[[ ! "$CAPTAIN_EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]] \
    && echo -e "${RED}Email invalide: $CAPTAIN_EMAIL${NC}" && exit 1

## Valider le domaine
[[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] \
    && echo -e "${RED}Domaine invalide: $DOMAIN${NC}" && exit 1

## Résoudre la swarm.key : fichier ou hex direct
if [[ -f "$SWARM_KEY_ARG" ]]; then
    ## Lire la dernière ligne du fichier (format IPFS swarm.key)
    SWARM_KEY_HEX=$(tail -n 1 "$SWARM_KEY_ARG" | tr -d '[:space:]')
    echo -e "${CYAN}Swarm key lue depuis: $SWARM_KEY_ARG${NC}"
else
    SWARM_KEY_HEX="$SWARM_KEY_ARG"
fi

## Valider la clé hex (64 caractères hexadécimaux)
[[ ! "$SWARM_KEY_HEX" =~ ^[0-9a-fA-F]{64}$ ]] \
    && echo -e "${RED}Swarm key invalide (attendu: 64 caractères hex)${NC}" && exit 1

## Vérifier que ce n'est pas la clé ORIGIN
ORIGIN_KEY="0000000000000000000000000000000000000000000000000000000000000000"
[[ "$SWARM_KEY_HEX" == "$ORIGIN_KEY" ]] \
    && echo -e "${RED}C'est la clé ORIGIN, pas une clé ẐEN${NC}" && exit 1

## Paramètres économiques (défauts ou env)
MACHINE_VALUE_ZEN="${MACHINE_VALUE_ZEN:-500}"
PAF="${PAF:-14}"
NCARD="${NCARD:-1}"
ZCARD="${ZCARD:-4}"

########################################################################
## CONFIRMATION
########################################################################
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      MIGRATION ORIGIN → UPlanet ẐEN             ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Capitaine:   ${GREEN}$CAPTAIN_EMAIL${NC}"
echo -e "  Domaine:     ${GREEN}$DOMAIN${NC}"
echo -e "  Swarm key:   ${GREEN}${SWARM_KEY_HEX:0:16}...${NC}"
echo -e "  Machine:     ${YELLOW}$MACHINE_VALUE_ZEN ZEN${NC}"
echo -e "  PAF:         ${YELLOW}$PAF ZEN/sem${NC}"
echo ""
echo -e "${YELLOW}ATTENTION: les comptes et wallets ORIGIN seront supprimés.${NC}"
echo ""
read -p "Confirmer la migration vers ẐEN ? (oui/NON): " confirm
[[ "$confirm" != "oui" ]] && echo "Annulé." && exit 0

########################################################################
## 1. ARRETER LES SERVICES
########################################################################
echo ""
echo -e "${CYAN}[1/8] Arrêt des services...${NC}"
"$MY_PATH/stop.sh" 2>/dev/null || true

########################################################################
## 2. NETTOYAGE ORIGIN
########################################################################
echo -e "${CYAN}[2/8] Nettoyage des comptes ORIGIN...${NC}"

## Supprimer les MULTIPASS et ZEN Card ORIGIN
if [[ -d "$HOME/.zen/game/nostr" ]]; then
    for nostr_dir in "$HOME/.zen/game/nostr"/*@*.*; do
        [[ -d "$nostr_dir" ]] || continue
        email=$(basename "$nostr_dir")
        echo "  Suppression MULTIPASS: $email"
        ~/.zen/Astroport.ONE/tools/nostr_DESTROY_TW.sh $email
    done
fi

## Supprimer les wallets coopératifs ORIGIN (seront régénérés avec le bon UPLANETNAME)
for wallet in uplanet.dunikey uplanet.G1.dunikey uplanet.SOCIETY.dunikey \
              uplanet.CASH.dunikey uplanet.RnD.dunikey uplanet.ASSETS.dunikey \
              uplanet.IMPOT.dunikey uplanet.captain.dunikey uplanet.INTRUSION.dunikey \
              uplanet.CAPITAL.dunikey uplanet.AMORTISSEMENT.dunikey \
              uplanet.G1.nostr; do
    rm -f "$HOME/.zen/game/$wallet"
done

## Nettoyer les caches
rm -rf "$HOME/.zen/tmp/coucou"
rm -f "$HOME/.zen/game/MY_boostrap_nodes.txt"

echo -e "${GREEN}  Nettoyage ORIGIN terminé${NC}"

########################################################################
## 3. INSTALLER LA SWARM.KEY ẐEN
########################################################################
echo -e "${CYAN}[3/8] Installation de la swarm.key ẐEN...${NC}"

cat > "$HOME/.ipfs/swarm.key" <<SWARMKEY
/key/swarm/psk/1.0.0/
/base16/
${SWARM_KEY_HEX}
SWARMKEY
chmod 600 "$HOME/.ipfs/swarm.key"
echo -e "${GREEN}  Swarm key installée${NC}"

########################################################################
## 4. REGENERER LE .ENV
########################################################################
echo -e "${CYAN}[4/8] Configuration du domaine ${DOMAIN}...${NC}"

ENV_FILE="$HOME/.zen/Astroport.ONE/.env"
cat > "$ENV_FILE" <<DOTENV
#########################################
# ASTROPORT box - UPlanet ẐEN
# Domain: ${DOMAIN}
# Captain: ${CAPTAIN_EMAIL}
# Date: $(date -Is)
#########################################
myASTROPORT=https://astroport.${DOMAIN}
myIPFS=https://ipfs.${DOMAIN}
myRELAY=wss://relay.${DOMAIN}
uSPOT=https://u.${DOMAIN}

###################################
## ZEN ECONOMY
###################################
MACHINE_VALUE_ZEN=${MACHINE_VALUE_ZEN}
PAF=${PAF}
NCARD=${NCARD}
ZCARD=${ZCARD}
LOG_LEVEL=INFO
ENABLE_AUDIO_NOTIFICATIONS=no
DOTENV
echo -e "${GREEN}  .env créé pour ${DOMAIN}${NC}"

########################################################################
## 5. NIVEAU Y (jumelage SSH/IPFS/G1)
########################################################################
echo -e "${CYAN}[5/8] Passage au niveau Y (jumelage SSH/IPFS)...${NC}"

if [[ -s "$HOME/.zen/game/id_ssh.pub" ]]; then
    echo -e "${GREEN}  Niveau Y déjà actif${NC}"
elif [[ -s "$HOME/.ssh/id_ed25519" ]]; then
    "$MY_PATH/tools/Ylevel.sh" AUTOMATIC
    echo -e "${GREEN}  Niveau Y activé${NC}"
else
    echo -e "${YELLOW}  Pas de clé SSH ed25519 — génération...${NC}"
    ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -q
    "$MY_PATH/tools/Ylevel.sh" AUTOMATIC
    echo -e "${GREEN}  SSH + Niveau Y activés${NC}"
fi

########################################################################
## 6. CAPITAINE + WALLETS COOPERATIFS
########################################################################
echo -e "${CYAN}[6/8] Embarquement capitaine ${CAPTAIN_EMAIL}...${NC}"

## Redémarrer IPFS avec la nouvelle swarm.key + identité
sudo systemctl restart ipfs 2>/dev/null || true
sleep 3

## Sourcer my.sh pour avoir UPLANETNAME, IPFSNODEID, etc.
. "$MY_PATH/tools/my.sh"

## Créer MULTIPASS (clés NOSTR + G1 via SALT/PEPPER disco)
GO=$(my_LatLon 2>/dev/null || echo "FR 33.33 33.33")
"$MY_PATH/tools/make_NOSTRCARD.sh" "${CAPTAIN_EMAIL}" $GO || true

## Créer ZENCARD (clés G1 via SALT/PEPPER aléatoires)
ZSALT=$("$MY_PATH/tools/diceware.sh" $(( $("$MY_PATH/tools/getcoins_from_gratitude_box.sh" 2>/dev/null || echo 0) + 3 )))
ZPEPS=$("$MY_PATH/tools/diceware.sh" $(( $("$MY_PATH/tools/getcoins_from_gratitude_box.sh" 2>/dev/null || echo 0) + 3 )))

if [ -s "$HOME/.zen/game/nostr/${CAPTAIN_EMAIL}/.secret.nostr" ]; then
    . "$HOME/.zen/game/nostr/${CAPTAIN_EMAIL}/.secret.nostr"
    "$MY_PATH/RUNTIME/VISA.new.sh" "$ZSALT" "$ZPEPS" "${CAPTAIN_EMAIL}" "UPlanet" $GO "$NPUB" "$HEX" || true
fi

## Initialiser les portefeuilles coopératifs (primo TX)
echo -e "${CYAN}  Initialisation des portefeuilles coopératifs...${NC}"
"$MY_PATH/UPLANET.init.sh" --force || true

echo -e "${GREEN}  Capitaine embarqué${NC}"

########################################################################
## 7. CONFIGURATION COOPERATIVE (kind 30800 + OC2UPlanet)
########################################################################
echo -e "${CYAN}[7/8] Configuration coopérative...${NC}"

OC_TOKEN=""
OC_SLUG=""
OC2DIR="$HOME/.zen/workspace/OC2UPlanet"

## Sourcer cooperative_config.sh pour accéder aux fonctions
if [[ -f "$MY_PATH/tools/cooperative_config.sh" ]]; then
    . "$MY_PATH/tools/cooperative_config.sh"

    ## Tenter de récupérer le kind 30800 depuis le relay distant de la ẐEN
    ## Les autres stations du swarm ont déjà publié la config coopérative
    echo -e "${CYAN}  Recherche config coopérative sur wss://relay.${DOMAIN}...${NC}"
    COOP_CONFIG_RELAY="wss://relay.${DOMAIN}"
    COOP_REMOTE=$(coop_fetch_config_from_nostr 2>/dev/null)

    if [[ -n "$COOP_REMOTE" && "$COOP_REMOTE" != "{}" ]]; then
        ## Config trouvée sur le relay — on l'importe
        echo -e "${GREEN}  Config coopérative récupérée depuis le relay ẐEN${NC}"
        mkdir -p "$(dirname "$COOP_CONFIG_CACHE")"
        echo "$COOP_REMOTE" > "$COOP_CONFIG_CACHE"

        ## Extraire les credentials OC (auto-déchiffrement via UPLANETNAME)
        OC_TOKEN=$(coop_config_get "OCAPIKEY" 2>/dev/null) || true
        OC_SLUG=$(coop_config_get "OPENCOLLECTIVE_SLUG" 2>/dev/null) || true
        [[ -z "$OC_SLUG" ]] && OC_SLUG=$(echo "$COOP_REMOTE" | jq -r '.OPENCOLLECTIVE_SLUG // empty' 2>/dev/null)

        if [[ -n "$OC_TOKEN" ]]; then
            echo -e "${GREEN}  Credentials OC récupérés du DID NOSTR (chiffrés)${NC}"
        else
            echo -e "${YELLOW}  Config coopérative trouvée mais pas de token OC${NC}"
        fi
    else
        ## Première station ou relay pas encore disponible — demander interactivement
        echo -e "${YELLOW}  Aucune config coopérative trouvée sur le relay${NC}"
        echo ""
        echo -e "${CYAN}OC2UPlanet synchronise les contributions OpenCollective → wallets ẐEN.${NC}"
        echo -e "${CYAN}Obtenez votre Personal Token sur:${NC}"
        echo -e "  ${GREEN}https://opencollective.com/dashboard/<slug>/for-developers/personal-tokens/${NC}"
        echo ""

        read -p "OpenCollective Personal Token (laisser vide pour ignorer): " OC_TOKEN
        if [[ -n "$OC_TOKEN" ]]; then
            read -p "OpenCollective Slug (ex: monnaie-libre): " OC_SLUG
            [[ -z "$OC_SLUG" ]] && OC_SLUG="monnaie-libre"

            ## Stocker dans cooperative_config (chiffré NOSTR DID kind 30800)
            coop_config_set "OCAPIKEY" "$OC_TOKEN" 2>/dev/null || true
            coop_config_set "OPENCOLLECTIVE_SLUG" "$OC_SLUG" --no-encrypt 2>/dev/null || true
            echo -e "${GREEN}  Credentials OC stockés dans cooperative_config (NOSTR DID)${NC}"
        fi
    fi
else
    echo -e "${YELLOW}  cooperative_config.sh non trouvé${NC}"
fi

## Générer le .env pour OC2UPlanet si on a un token
if [[ -n "$OC_TOKEN" && -d "$OC2DIR" ]]; then
    cat > "$OC2DIR/.env" <<OCENV
## OC2UPlanet — Generated by zen_join.sh ($(date -Is))
## UPlanet ẐEN: ${DOMAIN}
OCAPIKEY="${OC_TOKEN}"
OCSLUG="${OC_SLUG}"
## Production API (mode ẐEN)
OC_API="https://api.opencollective.com/graphql/v2"
OCENV
    chmod 600 "$OC2DIR/.env"
    echo -e "${GREEN}  OC2UPlanet .env créé: $OC2DIR/.env${NC}"
elif [[ -n "$OC_TOKEN" && ! -d "$OC2DIR" ]]; then
    echo -e "${YELLOW}  OC2UPlanet non trouvé dans $OC2DIR${NC}"
elif [[ -z "$OC_TOKEN" ]]; then
    echo -e "${YELLOW}  OpenCollective non configuré (configurable plus tard)${NC}"
fi

########################################################################
## 8. REDEMARRER LES SERVICES
########################################################################
echo -e "${CYAN}[8/8] Démarrage des services ẐEN...${NC}"

## Configurer NPM si disponible
if [[ -f "$MY_PATH/install/setup/setup_npm.sh" ]]; then
    "$MY_PATH/install/setup/setup_npm.sh" 2>/dev/null || true
fi

"$MY_PATH/start.sh"

########################################################################
## RÉSUMÉ
########################################################################
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          MIGRATION ẐEN TERMINÉE                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Capitaine:   ${GREEN}$CAPTAIN_EMAIL${NC}"
echo -e "  Domaine:     ${GREEN}$DOMAIN${NC}"
echo -e "  UPLANETNAME: ${CYAN}${SWARM_KEY_HEX:0:16}...${NC}"
echo -e "  Mode:        ${YELLOW}UPlanet ẐEN (Niveau Y)${NC}"
echo ""
echo -e "  Sous-domaines:"
echo -e "    astroport.${DOMAIN}  Station Map"
echo -e "    ipfs.${DOMAIN}       IPFS Gateway"
echo -e "    relay.${DOMAIN}      NOSTR Relay"
echo -e "    u.${DOMAIN}          UPassport API"
echo ""
if [[ -n "${OC_TOKEN:-}" ]]; then
    echo -e "  OpenCollective: ${GREEN}${OC_SLUG}${NC} (API configurée)"
    [[ -s "$OC2DIR/.env" ]] && echo -e "  OC2UPlanet:     ${GREEN}$OC2DIR/.env${NC}"
fi
echo ""
echo -e "${YELLOW}Si les portefeuilles n'ont pas été initialisés (solde insuffisant):${NC}"
echo -e "  1. Alimentez uplanet.G1.dunikey avec au moins 10 G1"
echo -e "  2. Relancez: ${CYAN}$MY_PATH/UPLANET.init.sh --force${NC}"
echo ""
echo -e "${YELLOW}Config coopérative (kind 30800) — synchronisée automatiquement via le relay.${NC}"
echo -e "${YELLOW}Pour configurer manuellement:${NC}"
echo -e "  ${CYAN}source $MY_PATH/tools/cooperative_config.sh${NC}"
echo -e "  ${CYAN}coop_config_set OCAPIKEY <token>${NC}"
echo -e "  ${CYAN}coop_config_set OPENCOLLECTIVE_SLUG <slug> --no-encrypt${NC}"
echo -e "  ${CYAN}coop_config_refresh  # récupérer la config depuis le relay${NC}"
echo ""
echo -e "${CYAN}Interface: http://astroport.localhost:12345${NC}"
echo -e "${CYAN}Dashboard: $MY_PATH/tools/dashboard.sh${NC}"
