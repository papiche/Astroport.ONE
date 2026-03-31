################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3 (Love Ledger & Resilience Update)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.ECONOMY.sh
#~ Make payments between UPlanet / NODE / Captain & NOSTR / PLAYERS Cards
################################################################################
# Ce script gère l'économie de l'écosystème UPlanet :
# 1. Vérifie les soldes des différents acteurs (UPlanet, Node, Captain)
# 2. Gère le paiement hebdomadaire des coûts opérationnels depuis CASH :
#    - 1x PAF → NODE (loyer matériel Armateur)
#    - 2x PAF → CAPTAIN MULTIPASS (rétribution travail personnelle)
# 3. Implémente le burn 4-semaines et conversion OpenCollective
#
# FLUX ÉCONOMIQUE :
# - CASH (Réserve de Fonctionnement) paie les coûts opérationnels
# - CAPTAIN MULTIPASS = revenus personnels du capitaine (salaire)
# - CAPTAIN_DEDICATED (uplanet.captain.dunikey) = collecte des loyers usagers
#   → Utilisé par ZEN.COOPERATIVE.3x1-3.sh pour allocation coopérative
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
# Source cooperative config for DID-based configuration (encrypted in NOSTR)
. "${MY_PATH}/../tools/cooperative_config.sh" 2>/dev/null || true
################################################################################
start=`date +%s`

#######################################################################
# Setup logging directory and file
#######################################################################
LOG_DIR="$HOME/.zen/tmp/coucou"
LOG_FILE="$LOG_DIR/zen_economy.txt"
LOVE_LEDGER="$HOME/.zen/game/love_ledger.json"
mkdir -p "$LOG_DIR"

# Function to log both to console and file
log_output() {
    echo "$@" | tee -a "$LOG_FILE"
}
# Initialiser le registre de Gratitude s'il n'existe pas
# "Ğ1 apporte la Liberté · Ẑen apporte l'Égalité · ❤️ apporte la Fraternité — 1 ❤️ = 1 DU"
if [[ ! -f "$LOVE_LEDGER" ]]; then
    echo '{"total_donated_zen": 0, "weeks_on_volunteer": 0, "motto": "G1=Liberte Zen=Egalite Love=Fraternite 1xLove=1DU", "history": []}' > "$LOVE_LEDGER"
fi
# Start logging session with timestamp and separator
{
    echo ""
    echo "========================================================================"
    echo " ZEN ECONOMY RUN - $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "========================================================================"
} >> "$LOG_FILE"

#######################################################################
# Weekly payment check - ensure payment is made only once per week
# Check if payment was already done this week using marker file
#######################################################################
PAYMENT_MARKER="$HOME/.zen/game/.weekly_payment.done"

# Get current week number (ISO week)
CURRENT_WEEK=$(date +%V)
CURRENT_YEAR=$(date +%Y)
WEEK_KEY="${CURRENT_YEAR}-W${CURRENT_WEEK}"

# Marqueurs atomiques de paiement — un fichier par étape et par semaine.
# Empêchent les doubles paiements si le script s'interrompt en cours de route.
# IMPORTANT : stockés dans ~/.zen/game/ (persistant) — ~/.zen/tmp/ est vidé à 20h12.
NODE_PAID_MARKER="$HOME/.zen/game/.node_paid_W${CURRENT_WEEK}"
CAPTAIN_PAID_MARKER="$HOME/.zen/game/.captain_paid_W${CURRENT_WEEK}"

# Check if payment was already done this week
# Marker format: "YEAR-Wxx:PHASEn:NODEn:CPTn" - extract week key for comparison
if [[ -f "$PAYMENT_MARKER" ]]; then
    LAST_PAYMENT_WEEK=$(cat "$PAYMENT_MARKER" | cut -d':' -f1)
    if [[ "$LAST_PAYMENT_WEEK" == "$WEEK_KEY" ]]; then
        log_output "ZEN ECONOMY: Weekly payment already completed this week ($WEEK_KEY)"
        log_output "Skipping payment process..."
        log_output "========================================================================"
        exit 0
    fi
fi

log_output "ZEN ECONOMY: Starting weekly payment process for week $WEEK_KEY"

#######################################################################
# Vérification des soldes des différents acteurs du système
# UPlanet : La "banque centrale" coopérative
# Node : Le serveur physique (PC Gamer ou RPi5)
# Captain : Le gestionnaire du Node
#######################################################################
log_output "UPlanet G1PUB : ${UPLANETG1PUB}"
UCOIN=$(${MY_PATH}/../tools/G1check.sh ${UPLANETG1PUB} | tail -n 1)
UCOIN=${UCOIN:-0}
UZEN=$(echo "scale=1; ($UCOIN - 1) * 10" | bc)
log_output "$UZEN Ẑen"

# Vérification du Node (Astroport)
NODEG1PUB=$($MY_PATH/../tools/ipfs_to_g1.py ${IPFSNODEID})
log_output "NODE G1PUB : ${NODEG1PUB}"
NODECOIN=$(${MY_PATH}/../tools/G1check.sh ${NODEG1PUB} | tail -n 1)
NODECOIN=${NODECOIN:-0}
NODEZEN=$(echo "scale=1; ($NODECOIN - 1) * 10" | bc)
log_output "$NODEZEN Ẑen"

# Vérification du Captain (gestionnaire) - MULTIPASS (NOSTR)
log_output "CAPTAIN G1PUB : ${CAPTAING1PUB}"
CAPTAINCOIN=$(${MY_PATH}/../tools/G1check.sh ${CAPTAING1PUB} | tail -n 1)
CAPTAINCOIN=${CAPTAINCOIN:-0}
CAPTAINZEN=$(echo "scale=1; ($CAPTAINCOIN - 1) * 10" | bc)
log_output "Captain MULTIPASS balance: $CAPTAINZEN Ẑen"

# Vérification de la ZEN Card du Captain (PLAYERS)
if [[ -n "$CAPTAINEMAIL" ]]; then
    CAPTAIN_ZENCARD_PATH="$HOME/.zen/game/players/$CAPTAINEMAIL"
    if [[ -d "$CAPTAIN_ZENCARD_PATH" && -s "$CAPTAIN_ZENCARD_PATH/secret.dunikey" ]]; then
        CAPTAIN_ZENCARD_PUB=$(cat "$CAPTAIN_ZENCARD_PATH/secret.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
        if [[ -n "$CAPTAIN_ZENCARD_PUB" ]]; then
            CAPTAIN_ZENCARD_COIN=$(${MY_PATH}/../tools/G1check.sh ${CAPTAIN_ZENCARD_PUB} | tail -n 1)
                CAPTAIN_ZENCARD_COIN=${CAPTAIN_ZENCARD_COIN:-0}
                CAPTAIN_ZENCARD_ZEN=$(echo "scale=1; ($CAPTAIN_ZENCARD_COIN - 1) * 10" | bc)
            log_output "Captain ZEN Card balance: $CAPTAIN_ZENCARD_ZEN Ẑen"
        else
            CAPTAIN_ZENCARD_ZEN=0
            log_output "Captain ZEN Card not found or invalid"
        fi
    else
        CAPTAIN_ZENCARD_ZEN=0
        log_output "Captain ZEN Card not found"
    fi
else
    CAPTAIN_ZENCARD_ZEN=0
    log_output "Captain email not configured"
fi

#######################################################################
# Comptage des utilisateurs actifs
# NOSTR : Utilisateurs avec carte NOSTR (1 Ẑen/semaine)
# PLAYERS : Utilisateurs avec carte ZEN (4 Ẑen/semaine)
#######################################################################
NOSTRS=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))
PLAYERS=($(ls -t ~/.zen/game/players/ 2>/dev/null | grep "@" ))
log_output "NODE hosts MULTIPASS : ${#NOSTRS[@]} / ZENCARD : ${#PLAYERS[@]}"

#######################################################################
# Configuration des paramètres économiques
# PAF : Participation Aux Frais (coûts de fonctionnement)
# NCARD : Coût hebdomadaire de la carte NOSTR
# ZCARD : Coût hebdomadaire de la carte ZEN
#######################################################################
[[ -z $PAF ]] && PAF=14  # PAF hebdomadaire par défaut
[[ -z $NCARD ]] && NCARD=1  # Coût hebdomadaire carte NOSTR
[[ -z $ZCARD ]] && ZCARD=4  # Coût hebdomadaire carte ZEN

# PAF hebdomadaire
WEEKLYPAF=$PAF
log_output "ZEN ECONOMY : PAF=$WEEKLYPAF ZEN/week :: NCARD=$NCARD // ZCARD=$ZCARD"
WEEKLYG1=$(makecoord $(echo "$WEEKLYPAF / 10" | bc -l))

##################################################################################
# Système de paiement hebdomadaire depuis CASH (Réserve de Fonctionnement)
# MODÈLE ÉCONOMIQUE (flux correct) :
# - CASH → NODE (1x PAF) : loyer matériel Armateur
# - CASH → CAPTAIN MULTIPASS (2x PAF) : rétribution travail personnelle
# 
# Note : Le Capitaine REÇOIT sa rétribution sur son MULTIPASS personnel.
#        Les loyers usagers sont collectés sur CAPTAIN_DEDICATED (séparé)
#        et servent de source pour l'allocation coopérative 3x1/3.
#######################################################################

# Ensure CASH wallet exists and get its balance
if [[ ! -s "$HOME/.zen/game/uplanet.CASH.dunikey" ]]; then
    log_output "⚠️  CASH wallet not found - creating it..."
    ${MY_PATH}/../tools/keygen -t duniter -o ~/.zen/game/uplanet.CASH.dunikey "${UPLANETNAME}.TREASURY" "${UPLANETNAME}.TREASURY"
    chmod 600 ~/.zen/game/uplanet.CASH.dunikey
fi

CASH_G1PUB=$(cat "$HOME/.zen/game/uplanet.CASH.dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
CASH_COIN=$(${MY_PATH}/../tools/G1check.sh ${CASH_G1PUB} | tail -n 1)
CASH_COIN=${CASH_COIN:-0}
CASH_ZEN=$(echo "scale=1; ($CASH_COIN - 1) * 10" | bc)
log_output "CASH (Treasury) balance: $CASH_ZEN Ẑen"

# Calculate total required: 3x PAF (1x NODE + 2x CAPTAIN)
TOTAL_PAF_REQUIRED=$(echo "scale=2; $WEEKLYPAF * 3" | bc -l)
log_output "ZEN ECONOMY: Total weekly PAF required: $TOTAL_PAF_REQUIRED Ẑen (1x NODE + 2x CAPTAIN)"

if [[ $(echo "$WEEKLYG1 > 0" | bc -l) -eq 1 ]]; then
    if [[ $(echo "$NODECOIN >= 1" | bc -l) -eq 1 ]]; then
        
        #######################################################################
        # SYSTÈME DE RÉSILIENCE ET DE DONS (Accord des Acteurs)
        # Payer directement depuis les portefeuilles de secours :
        #
        # NIVEAU 0: Abondance  - Paiement depuis CASH
        # NIVEAU 1: Solidarité - Paiement depuis ASSETS (forêts-jardins soutiennent)
        # NIVEAU 2: Résilience - Paiement depuis R&D (innovation soutient l'infra)
        # NIVEAU 3: BÉNÉVOLAT  - Aucun fonds dispo, le Capitaine offre son infra/temps
        #
        # Chaque niveau envoie une notification aux acteurs pour la transparence.
        # Le bénévolat est comptabilisé dans le Love Ledger et diffusé sur NOSTR.
        #######################################################################

        RESILIENCE_LEVEL=0
        CAPTAIN_PAID=0
        NODE_PAID=0
        LOVE_DONATION_THIS_WEEK=0
        PAYMENT_SOURCE="CAPTAIN_DEDICATED"
        NODE_PAYMENT_SOURCE=""
        CAPTAIN_PAYMENT_SOURCE=""

        # ── Reprise atomique : détecter les étapes déjà payées cette semaine ──────
        # Si le script a été interrompu après un paiement réussi, on ne repaie pas.
        if [[ -f "$NODE_PAID_MARKER" ]]; then
            log_output "🔒 NODE déjà payé cette semaine (W${CURRENT_WEEK}) — skip double-paiement"
            NODE_PAID=1
            NODE_PAYMENT_SOURCE=$(cut -d: -f2 "$NODE_PAID_MARKER" 2>/dev/null || echo "PREV")
        fi
        if [[ -f "$CAPTAIN_PAID_MARKER" ]]; then
            log_output "🔒 CAPTAIN déjà payé cette semaine (W${CURRENT_WEEK}) — skip double-paiement"
            CAPTAIN_PAID=1
            CAPTAIN_PAYMENT_SOURCE=$(cut -d: -f2 "$CAPTAIN_PAID_MARKER" 2>/dev/null || echo "PREV")
        fi
        
        # Calculate remuneration amounts
        CAPTAIN_REMUNERATION=$(echo "scale=2; $WEEKLYPAF * 2" | bc -l)
        CAPTAIN_REMUNERATION_G1=$(makecoord $(echo "$CAPTAIN_REMUNERATION / 10" | bc -l))
        
        #######################################################################
        # PRIORITY 1: Pay NODE (1x PAF) - Infrastructure
        #######################################################################
        log_output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_output "📦 NODE PAYMENT (1x PAF = $WEEKLYPAF Ẑen)"
        
        # On vérifie si le compte de COLLECTE (CAPTAIN_DED_ZEN) peut payer
        if [[ $(echo "$CAPTAIN_DED_ZEN >= $WEEKLYPAF" | bc -l) -eq 1 ]]; then
            ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$WEEKLYG1" "${NODEG1PUB}" "UP:${UPLANETG1PUB:0:8}:PAF:W${CURRENT_WEEK}:${WEEKLYPAF}Z:INCOME>NODE" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                log_output "✅ REVENUS payent NODE PAF: $WEEKLYPAF Ẑen"
                NODE_PAID=1
                NODE_PAYMENT_SOURCE="REVENUS"
                CAPTAIN_DED_ZEN=$(echo "scale=1; $CAPTAIN_DED_ZEN - $WEEKLYPAF" | bc)
                echo "$(date +%Y%m%d%H%M%S):INCOME" > "$NODE_PAID_MARKER"
            fi
        fi

        # BÉNÉVOLAT - Aucun fonds disponible, l'Armateur offre son infrastructure
        if [[ $NODE_PAID -eq 0 ]]; then
            log_output "⚠️  REVENUS insuffisants pour payer le matériel (NODE)."
            NODE_PAYMENT_SOURCE="LOVE (Bénévolat)"
        fi
        
        #######################################################################
        # PRIORITY 2: Pay Captain (2x PAF) - Rétribution
        #######################################################################
        log_output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_output "👨‍✈️ CAPTAIN PAYMENT (2x PAF = $CAPTAIN_REMUNERATION Ẑen)"
        
        if [[ $NODE_PAID -eq 1 ]]; then
            # Tenter de payer le Capitaine depuis le RESTE des revenus
            if [[ $(echo "$CAPTAIN_DED_ZEN >= $CAPTAIN_REMUNERATION" | bc -l) -eq 1 ]]; then
                ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.captain.dunikey" "$CAPTAIN_REMUNERATION_G1" "${CAPTAING1PUB}" "UP:${UPLANETG1PUB:0:8}:SALARY:W${CURRENT_WEEK}:${CAPTAIN_REMUNERATION}Z:INCOME>CPT" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    log_output "✅ REVENUS payent Capitaine: $CAPTAIN_REMUNERATION Ẑen"
                    CAPTAIN_PAID=1
                    CAPTAIN_PAYMENT_SOURCE="REVENUS"
                    CAPTAIN_DED_ZEN=$(echo "scale=1; $CAPTAIN_DED_ZEN - $CAPTAIN_REMUNERATION" | bc)
                    echo "$(date +%Y%m%d%H%M%S):INCOME" > "$CAPTAIN_PAID_MARKER"
                fi
            fi
        fi

        if [[ $CAPTAIN_PAID -eq 0 ]]; then
             CAPTAIN_PAYMENT_SOURCE="LOVE (Bénévolat)"
        fi

        # 3. CONCLUSION : Si l'un des deux n'est pas payé, on active la Résilience Level 3
        if [[ $NODE_PAID -eq 0 || $CAPTAIN_PAID -eq 0 ]]; then
            RESILIENCE_LEVEL=3
            log_output "❤️  NIVEAU 3 (BÉNÉVOLAT) : Recettes insuffisantes pour couvrir les coûts."
            
            # Calcul du don au Love Ledger (ce qui n'a pas pu être payé)
            [[ $NODE_PAID -eq 0 ]] && LOVE_DONATION_THIS_WEEK=$(echo "$LOVE_DONATION_THIS_WEEK + $WEEKLYPAF" | bc -l)
            [[ $CAPTAIN_PAID -eq 0 ]] && LOVE_DONATION_THIS_WEEK=$(echo "$LOVE_DONATION_THIS_WEEK + $CAPTAIN_REMUNERATION" | bc -l)
        fi

        log_output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        #######################################################################
        # MISE À JOUR DU LOVE LEDGER + NOTIFICATION NOSTR DE GRATITUDE
        # Comptabilise le bénévolat et le diffuse sur NOSTR pour remercier
        # publiquement le Capitaine (transparence des Communs)
        #######################################################################
        if [[ $(echo "$LOVE_DONATION_THIS_WEEK > 0" | bc -l) -eq 1 ]]; then
            TODATE=$(date +%Y-%m-%d)
            log_output "❤️  Mise à jour du Love Ledger : +${LOVE_DONATION_THIS_WEEK} Ẑen offerts aux Communs"

            # Mise à jour du JSON de Gratitude
            current_total=$(jq -r '.total_donated_zen' "$LOVE_LEDGER" 2>/dev/null || echo "0")
            new_total=$(echo "scale=2; $current_total + $LOVE_DONATION_THIS_WEEK" | bc -l)

            jq --arg date "$TODATE" \
               --arg amount "$LOVE_DONATION_THIS_WEEK" \
               --argjson new_total "$new_total" \
               '.total_donated_zen = $new_total |
                .weeks_on_volunteer += 1 |
                .history += [{"date": $date, "amount_zen": ($amount | tonumber)}]' \
               "$LOVE_LEDGER" > "${LOVE_LEDGER}.tmp" && mv "${LOVE_LEDGER}.tmp" "$LOVE_LEDGER"

            log_output "📖 Love Ledger mis à jour : total cumulé = ${new_total} Ẑen"

            # Envoi d'un événement NOSTR de Gratitude (Kind 1) pour remercier publiquement
            NOSTR_KEYFILE="$HOME/.zen/game/uplanet.G1.nostr"
            if [[ -x "${MY_PATH}/../tools/nostr_send_note.py" && -f "$NOSTR_KEYFILE" ]]; then
                LOVE_MSG="❤️ L'Astroport ${IPFSNODEID:0:8} fonctionne grâce au bénévolat !
Cette semaine, le Capitaine a offert l'équivalent de ${LOVE_DONATION_THIS_WEEK} Ẑen (~€) en frais d'infrastructure et de gestion.
Total offert à la communauté : ${new_total} Ẑen. 🙏
Ğ1=Liberté Ẑen=Égalité ❤️=Fraternité — 1❤️=1DU
#UPlanet #CommonsLove #Gratitude #AGPL #MonnaieLibre #TrocZen"
                "${MY_PATH}/../tools/nostr_send_note.py" \
                    --keyfile "$NOSTR_KEYFILE" \
                    --content "$LOVE_MSG" \
                    --relays "$myRELAY" 2>/dev/null \
                    && log_output "📡 Message de gratitude diffusé sur NOSTR (Kind 1)" \
                    || log_output "⚠️  Diffusion NOSTR Kind 1 échouée (non-critique)"

                #######################################################################
                # BOUCLE AUTONOME Ğ1↔Ẑen↔❤️↔DU : Émission Kind 30305 (Protocole TrocZen)
                # "1 ❤️ = 1 DU" — le sacrifice du Capitaine génère un DU co-créé
                # que TrocZen traduit en Bon fondant (28j TTL) sur le marché local
                #
                # FORMAT EXACT Kind 30305 (source: nostr_service.dart#publishDuIncrement) :
                # - kind   : 30305 (NIP-33 replaceable event)
                # - pubkey : clé HEX NOSTR du Capitaine (bénéficiaire du DU)
                # - tags   : [["d","du-YYYY-MM-DD"],["amount","XX.XX"]] SEULEMENT
                # - content: "" (TOUJOURS VIDE — TrocZen lit uniquement les tags)
                #
                # TrocZen lit l'amount via computeAvailableDu(npub) :
                #   DU_disponible = Σamount(Kind30305) - Σvalue(Kind30303 bons émis)
                # fetchAverageRecentDu() calibre DU(0) des nouveaux membres via ce tag
                #
                # La clé doit être celle du Capitaine (CAPTAINEMAIL) pour que TrocZen
                # l'attribue au bon npub dans sa DB du_increments(npub, date, amount)
                #######################################################################
                DU_INCREMENT=$(printf "%.2f" "$LOVE_DONATION_THIS_WEEK")
                DU_DATE=$(date +%Y-%m-%d)
                # d-tag unique par jour : "du-YYYY-MM-DD" (NIP-33, clé primaire DB TrocZen)
                DU_KIND30305_TAGS="[[\"d\",\"du-${DU_DATE}\"],[\"amount\",\"${DU_INCREMENT}\"]]"

                # Clé du Capitaine (bénéficiaire) — si disponible, sinon clé UPlanet
                CAPTAIN_NOSTR_KEY="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
                EMITTER_KEY="${CAPTAIN_NOSTR_KEY:-$NOSTR_KEYFILE}"
                [[ ! -f "$EMITTER_KEY" ]] && EMITTER_KEY="$NOSTR_KEYFILE"

                "${MY_PATH}/../tools/nostr_send_note.py" \
                    --keyfile "$EMITTER_KEY" \
                    --kind 30305 \
                    --content "" \
                    --tags "$DU_KIND30305_TAGS" \
                    --relays "$myRELAY" 2>/dev/null \
                    && log_output "🎫 Kind 30305 conforme TrocZen émis : +${DU_INCREMENT} Ẑen DU pour ${CAPTAINEMAIL:-Capitaine}" \
                    || log_output "⚠️  Émission Kind 30305 échouée (non-critique — boucle TrocZen indisponible)"
            fi

            # Notification email "Solidarité Active" au Capitaine (niveau 1 ou 2)
            if [[ $RESILIENCE_LEVEL -gt 0 && $RESILIENCE_LEVEL -lt 3 && -n "$CAPTAINEMAIL" ]]; then
                RESILIENCE_TEMPLATE="${MY_PATH}/../templates/NOSTR/pre_bankruptcy.html"
                RESILIENCE_REPORT="$HOME/.zen/tmp/resilience_level${RESILIENCE_LEVEL}_$(date +%Y-%m-%d).html"
                if [[ -s "$RESILIENCE_TEMPLATE" ]]; then
                    REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
                    UPLANET_ID="${UPLANETG1PUB:0:8}"
                    PAYMENT_SOURCE="${PAYMENT_SOURCE:-LOVE}"
                    [[ -z $NCARD ]] && NCARD=1
                    [[ -z $ZCARD ]] && ZCARD=4
                    IMPACT_10_MULTIPASS=$(echo "scale=0; 10 * $NCARD" | bc)
                    IMPACT_5_ZENCARDS=$(echo "scale=0; 5 * $ZCARD" | bc)
                    escape_sed_replacement() { echo "$1" | sed 's/[&/\]/\\&/g'; }
                    case $RESILIENCE_LEVEL in
                        1) PHASE_ICON="🌿"; PHASE_NAME_FR_SAFE="Solidarité ASSETS"; PHASE_CLASS="assets" ;;
                        2) PHASE_ICON="🔬"; PHASE_NAME_FR_SAFE=$(escape_sed_replacement "Solidarité R&D"); PHASE_CLASS="rnd" ;;
                    esac
                    NODE_PAYMENT_STATUS_FR="${NODE_PAYMENT_SOURCE} (${WEEKLYPAF} Ẑen)"
                    CAPTAIN_PAYMENT_STATUS_FR="${CAPTAIN_PAYMENT_SOURCE} (${CAPTAIN_REMUNERATION} Ẑen)"
                    cat "$RESILIENCE_TEMPLATE" | sed \
                        -e "s~_DATE_~${REPORT_DATE}~g" \
                        -e "s~_TODATE_~${TODATE}~g" \
                        -e "s~_UPLANET_ID_~${UPLANET_ID}~g" \
                        -e "s~_DEGRADATION_PHASE_~${RESILIENCE_LEVEL}~g" \
                        -e "s~_PAYMENT_SOURCE_~${PAYMENT_SOURCE}~g" \
                        -e "s~_PHASE_CLASS_~${PHASE_CLASS}~g" \
                        -e "s~_PHASE_ICON_~${PHASE_ICON}~g" \
                        -e "s~_PHASE_NAME_FR_~${PHASE_NAME_FR_SAFE}~g" \
                        -e "s~_PHASE_NAME_EN_~Resilience Level ${RESILIENCE_LEVEL}~g" \
                        -e "s~_PHASE_NAME_ES_~Nivel de Resiliencia ${RESILIENCE_LEVEL}~g" \
                        -e "s~_CASH_BALANCE_~${CASH_ZEN}~g" \
                        -e "s~_ASSETS_BALANCE_~${ASSETS_ZEN}~g" \
                        -e "s~_RND_BALANCE_~${RND_ZEN}~g" \
                        -e "s~_TOTAL_PAF_REQUIRED_~${TOTAL_PAF_REQUIRED}~g" \
                        -e "s~_NODE_PAYMENT_STATUS_FR_~${NODE_PAYMENT_STATUS_FR}~g" \
                        -e "s~_NODE_PAYMENT_STATUS_EN_~${NODE_PAYMENT_SOURCE} (${WEEKLYPAF} Zen)~g" \
                        -e "s~_CAPTAIN_PAYMENT_STATUS_FR_~${CAPTAIN_PAYMENT_STATUS_FR}~g" \
                        -e "s~_CAPTAIN_PAYMENT_STATUS_EN_~${CAPTAIN_PAYMENT_SOURCE}~g" \
                        -e "s~_NCARD_~${NCARD}~g" \
                        -e "s~_ZCARD_~${ZCARD}~g" \
                        -e "s~_IMPACT_10_MULTIPASS_~${IMPACT_10_MULTIPASS}~g" \
                        -e "s~_IMPACT_5_ZENCARDS_~${IMPACT_5_ZENCARDS}~g" \
                        > "$RESILIENCE_REPORT"
                    ${MY_PATH}/../tools/mailjet.sh --expire 7d "$CAPTAINEMAIL" "$RESILIENCE_REPORT" \
                        "🌿 UPlanet Résilience Niveau ${RESILIENCE_LEVEL} - ${TODATE}" 2>/dev/null \
                        && log_output "📧 Rapport de résilience envoyé au Capitaine: $CAPTAINEMAIL" \
                        || log_output "⚠️  Envoi email résilience échoué"
                fi
            fi
        fi

        #######################################################################
        # RAPPORT DE RÉSILIENCE HEBDOMADAIRE (remplace l'ancien rapport de faillite)
        #######################################################################
        log_output ""
        log_output "╔══════════════════════════════════════════════════════════════════════╗"
        log_output "║           📊 BILAN DE RÉSILIENCE HEBDOMADAIRE - $WEEK_KEY             "
        log_output "╠══════════════════════════════════════════════════════════════════════╣"
        case $RESILIENCE_LEVEL in
            0) log_output "║ STATUT: ✅ ABONDANCE  - Revenus couvrent tous les frais               " ;;
            1) log_output "║ STATUT: 🌿 SOLIDARITÉ - Les forêts-jardins (ASSETS) soutiennent       " ;;
            2) log_output "║ STATUT: 🔬 RÉSILIENCE - La R&D soutient l'infrastructure              " ;;
            3) log_output "║ STATUT: ❤️  BÉNÉVOLAT  - Le Capitaine soutient le réseau              " ;;
        esac
        log_output "╠══════════════════════════════════════════════════════════════════════╣"
        if [[ $NODE_PAID -eq 1 ]]; then
            log_output "║   🖥️  NODE    : ✅ $WEEKLYPAF Ẑen depuis $NODE_PAYMENT_SOURCE"
        else
            log_output "║   🖥️  NODE    : ❤️  $WEEKLYPAF Ẑen offerts (bénévolat Capitaine)"
        fi
        if [[ $CAPTAIN_PAID -eq 1 ]]; then
            log_output "║   👨‍✈️ CAPTAIN : ✅ $CAPTAIN_REMUNERATION Ẑen depuis $CAPTAIN_PAYMENT_SOURCE"
        else
            log_output "║   👨‍✈️ CAPTAIN : ❤️  $CAPTAIN_REMUNERATION Ẑen offerts (temps bénévole)"
        fi
        if [[ $(echo "$LOVE_DONATION_THIS_WEEK > 0" | bc -l) -eq 1 ]]; then
            log_output "╠══════════════════════════════════════════════════════════════════════╣"
            log_output "║   🎁 DON AUX COMMUNS CETTE SEMAINE : ${LOVE_DONATION_THIS_WEEK} Ẑen (~€)"
            if [[ -f "$LOVE_LEDGER" ]]; then
                _lt=$(jq -r '.total_donated_zen' "$LOVE_LEDGER" 2>/dev/null || echo "?")
                _wv=$(jq -r '.weeks_on_volunteer' "$LOVE_LEDGER" 2>/dev/null || echo "?")
                log_output "║   📖 LOVE LEDGER TOTAL : ${_lt} Ẑen sur ${_wv} semaine(s)"
            fi
        fi
        log_output "╠══════════════════════════════════════════════════════════════════════╣"
        log_output "║ SOLDES PORTEFEUILLES (après paiements) :                              "
        log_output "║   💰 CASH:   $CASH_ZEN Ẑen                                            "
        log_output "║   🌱 ASSETS: $ASSETS_ZEN Ẑen                                          "
        log_output "║   🔬 RnD:    $RND_ZEN Ẑen                                             "
        log_output "╚══════════════════════════════════════════════════════════════════════╝"
        log_output ""
        
        #######################################################################
        # DEPRECIATION: UPLANETNAME_CAPITAL → UPLANETNAME_AMORTISSEMENT
        # Linear depreciation over 3 years (156 weeks)
        # Compte 21 (Immobilisations) → Compte 28 (Amortissements)
        # 
        # NOTE: Amortissement n'est PAS du cash convertible en €
        # C'est une écriture comptable représentant la valeur "consommée"
        # Valeur Nette Comptable = CAPITAL - AMORTISSEMENT
        #######################################################################
        
        if [[ -s "$HOME/.zen/game/.env" ]] && [[ -s "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
            # Read machine capital configuration
            MACHINE_VALUE=$(grep "^MACHINE_VALUE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            CAPITAL_DATE=$(grep "^CAPITAL_DATE=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            DEPRECIATION_WEEKS=$(grep "^DEPRECIATION_WEEKS=" "$HOME/.zen/game/.env" 2>/dev/null | cut -d'=' -f2)
            [[ -z $DEPRECIATION_WEEKS ]] && DEPRECIATION_WEEKS=156  # Default: 3 years
            
            # Initialize AMORTISSEMENT wallet if not exists
            if [[ ! -s "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" ]]; then
                log_output "📦 Creating UPLANETNAME_AMORTISSEMENT wallet (Compte 28)..."
                ${MY_PATH}/../tools/keygen -t duniter -o "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" "${UPLANETNAME}.AMORTISSEMENT" "${UPLANETNAME}.AMORTISSEMENT"
                chmod 600 "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey"
                # Initialize with 1Ğ1 for transaction capability
                AMORT_G1PUB=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.G1.dunikey" "1" "${AMORT_G1PUB}" "UP:${UPLANETG1PUB:0:8}:INIT:AMORT:1G1:GENESIS" 2>/dev/null
                log_output "✅ UPLANETNAME_AMORTISSEMENT initialized: ${AMORT_G1PUB:0:8}..."
            fi
            
            # Get AMORTISSEMENT wallet public key
            AMORT_G1PUB=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" | grep "pub:" | cut -d ' ' -f 2)
            
            if [[ -n "$MACHINE_VALUE" ]] && [[ -n "$CAPITAL_DATE" ]] && [[ "$MACHINE_VALUE" != "0" ]]; then
                # Calculate weeks since capital date
                CAPITAL_TIMESTAMP=$(date -d "${CAPITAL_DATE:0:8}" +%s 2>/dev/null || echo "0")
                CURRENT_TIMESTAMP=$(date +%s)
                SECONDS_ELAPSED=$((CURRENT_TIMESTAMP - CAPITAL_TIMESTAMP))
                WEEKS_ELAPSED=$((SECONDS_ELAPSED / 604800))  # 604800 = 7*24*60*60
                
                log_output "📊 DEPRECIATION CHECK: Machine value=$MACHINE_VALUE Ẑen, Weeks elapsed=$WEEKS_ELAPSED/$DEPRECIATION_WEEKS"
                
                if [[ $WEEKS_ELAPSED -lt $DEPRECIATION_WEEKS ]]; then
                    # Calculate weekly depreciation amount
                    WEEKLY_DEPRECIATION=$(echo "scale=2; $MACHINE_VALUE / $DEPRECIATION_WEEKS" | bc -l)
                    WEEKLY_DEPRECIATION_G1=$(makecoord $(echo "$WEEKLY_DEPRECIATION / 10" | bc -l))
                    
                    # Check CAPITAL wallet balance
                    CAPITAL_G1PUB=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                    CAPITAL_COIN=$(${MY_PATH}/../tools/G1check.sh ${CAPITAL_G1PUB} | tail -n 1)
                    CAPITAL_ZEN=$(echo "scale=1; ($CAPITAL_COIN - 1) * 10" | bc)
                    
                    # Calculate values for logging
                    TOTAL_DEPRECIATED=$(echo "scale=2; $WEEKLY_DEPRECIATION * $WEEKS_ELAPSED" | bc -l)
                    RESIDUAL_VALUE=$(echo "scale=2; $MACHINE_VALUE - $TOTAL_DEPRECIATED" | bc -l)
                    
                    # Get current AMORTISSEMENT balance
                    AMORT_COIN=$(${MY_PATH}/../tools/G1check.sh ${AMORT_G1PUB} | tail -n 1)
                    AMORT_ZEN=$(echo "scale=1; ($AMORT_COIN - 1) * 10" | bc)
                    
                    if [[ $(echo "$CAPITAL_ZEN >= $WEEKLY_DEPRECIATION" | bc -l) -eq 1 ]]; then
                        # Transfer depreciation from CAPITAL → AMORTISSEMENT (Compte 21 → Compte 28)
                        ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.CAPITAL.dunikey" "$WEEKLY_DEPRECIATION_G1" "${AMORT_G1PUB}" "UP:${UPLANETG1PUB:0:8}:AMORT:W${CURRENT_WEEK}:${WEEKLY_DEPRECIATION}Z:C21>C28" 2>/dev/null
                        
                        if [[ $? -eq 0 ]]; then
                            NEW_AMORT_ZEN=$(echo "scale=2; $AMORT_ZEN + $WEEKLY_DEPRECIATION" | bc -l)
                            log_output "✅ DEPRECIATION: $WEEKLY_DEPRECIATION Ẑen → AMORTISSEMENT (Compte 28)"
                            log_output "   Valeur Brute (Compte 21): $MACHINE_VALUE Ẑen"
                            log_output "   Amortissements Cumulés (Compte 28): ~$NEW_AMORT_ZEN Ẑen"
                            log_output "   Valeur Nette Comptable: ~$RESIDUAL_VALUE Ẑen (après $WEEKS_ELAPSED semaines)"
                        else
                            log_output "⚠️  DEPRECIATION transfer failed - will retry next week"
                        fi
                    else
                        log_output "⚠️  CAPITAL wallet insufficient for depreciation ($CAPITAL_ZEN < $WEEKLY_DEPRECIATION Ẑen)"
                        log_output "   Expected residual value: $RESIDUAL_VALUE Ẑen - Capital fully amortized or underfunded"
                    fi
                else
                    log_output "📊 DEPRECIATION COMPLETE: Machine fully amortized after $DEPRECIATION_WEEKS weeks"
                    log_output "   Valeur Nette Comptable = 0 (machine peut être vendue à valeur résiduelle)"
                    # After full depreciation, CAPITAL wallet should be empty
                    # AMORTISSEMENT wallet contains total depreciated value
                fi
            fi
        fi
        
        #######################################################################
        # NIVEAU 3 BÉNÉVOLAT : Notification de gratitude à la communauté
        # Envoi d'un email "Merci" aux usagers (pas d'alerte anxiogène)
        #######################################################################
        if [[ $RESILIENCE_LEVEL -eq 3 && -n "$CAPTAINEMAIL" ]]; then
            TODATE=$(date +%Y-%m-%d)
            log_output "❤️  Niveau Bénévolat : envoi d'une notification de gratitude..."

            BENEVOLAT_TEMPLATE="${MY_PATH}/../templates/NOSTR/bankrupt.html"
            BENEVOLAT_REPORT="$HOME/.zen/tmp/benevolat_semaine_$(date +%Y-%m-%d).html"

            if [[ -s "$BENEVOLAT_TEMPLATE" ]]; then
                REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
                UPLANET_ID="${UPLANETG1PUB:0:8}"
                CASH_BALANCE=$CASH_ZEN
                [[ -z $NCARD ]] && NCARD=1
                [[ -z $ZCARD ]] && ZCARD=4
                [[ -z $TVA_RATE ]] && TVA_RATE=20
                [[ -z $IS_THRESHOLD ]] && IS_THRESHOLD=42500
                [[ -z $IS_RATE_REDUCED ]] && IS_RATE_REDUCED=15
                [[ -z $IS_RATE_NORMAL ]] && IS_RATE_NORMAL=25
                MIN_REQUIRED=$(echo "scale=2; $WEEKLYPAF + $CAPTAIN_REMUNERATION" | bc -l)
                TOTAL_ALLOCATIONS=0
                TOTAL_NEEDED=$MIN_REQUIRED
                TAX_RATE_USED=$IS_RATE_REDUCED
                DEFICIT=$(echo "scale=2; $TOTAL_PAF_REQUIRED - $CASH_ZEN" | bc -l)
                [[ $(echo "$DEFICIT < 0" | bc -l) -eq 1 ]] && DEFICIT="0.00"
                IMPACT_10_MULTIPASS=$(echo "scale=2; 10 * $NCARD" | bc -l)
                IMPACT_5_ZENCARDS=$(echo "scale=2; 5 * $ZCARD" | bc -l)
                IMPACT_TOTAL_REVENUE=$(echo "scale=2; $IMPACT_10_MULTIPASS + $IMPACT_5_ZENCARDS" | bc -l)
                SOCIETAIRE_SHARE_PRICE=50
                SOCIETAIRE_SHARE_PRICE_EUR=50
                SOCIETAIRE_CAPITAL=$(echo "scale=2; 10 * $SOCIETAIRE_SHARE_PRICE" | bc -l)
                CAPITAL_BALANCE="0"; AMORT_BALANCE="0"
                MACHINE_VALUE_REPORT="0"; DEPRECIATION_PERCENT="0"
                WEEKS_PASSED_REPORT="0"; DEPRECIATION_WEEKS_REPORT="156"
                if [[ -f "$HOME/.zen/game/uplanet.CAPITAL.dunikey" ]]; then
                    CAPITAL_G1PUB_RPT=$(cat "$HOME/.zen/game/uplanet.CAPITAL.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                    CAPITAL_COIN_RPT=$(${MY_PATH}/../tools/G1check.sh ${CAPITAL_G1PUB_RPT} 2>/dev/null | tail -n 1)
                    CAPITAL_BALANCE=$(echo "scale=1; ($CAPITAL_COIN_RPT - 1) * 10" | bc 2>/dev/null || echo "0")
                    if [[ -f "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" ]]; then
                        AMORT_G1PUB_RPT=$(cat "$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey" | grep "pub:" | cut -d ' ' -f 2)
                        AMORT_COIN_RPT=$(${MY_PATH}/../tools/G1check.sh ${AMORT_G1PUB_RPT} 2>/dev/null | tail -n 1)
                        AMORT_BALANCE=$(echo "scale=1; ($AMORT_COIN_RPT - 1) * 10" | bc 2>/dev/null || echo "0")
                    fi
                    MACHINE_VALUE_REPORT="${MACHINE_VALUE_ZEN:-0}"
                    DEPRECIATION_WEEKS_REPORT="${DEPRECIATION_WEEKS:-156}"
                fi
                # Liste des éléments offerts bénévolement
                FAILED_ALLOCATIONS=""
                [[ $NODE_PAID -eq 0 ]] && FAILED_ALLOCATIONS="${FAILED_ALLOCATIONS}<li>❤️ Hébergement NODE offert : ${WEEKLYPAF} Ẑen</li>"
                [[ $CAPTAIN_PAID -eq 0 ]] && FAILED_ALLOCATIONS="${FAILED_ALLOCATIONS}<li>❤️ Temps Capitaine offert : ${CAPTAIN_REMUNERATION} Ẑen</li>"

                cat "$BENEVOLAT_TEMPLATE" | sed \
                    -e "s~_DATE_~${REPORT_DATE}~g" \
                    -e "s~_TODATE_~${TODATE}~g" \
                    -e "s~_UPLANET_ID_~${UPLANET_ID}~g" \
                    -e "s~_CASH_BALANCE_~${CASH_BALANCE}~g" \
                    -e "s~_PAF_~${WEEKLYPAF}~g" \
                    -e "s~_CAPTAIN_REMUNERATION_~${CAPTAIN_REMUNERATION}~g" \
                    -e "s~_MIN_REQUIRED_~${MIN_REQUIRED}~g" \
                    -e "s~_NCARD_~${NCARD}~g" \
                    -e "s~_ZCARD_~${ZCARD}~g" \
                    -e "s~_TVA_RATE_~${TVA_RATE}~g" \
                    -e "s~_IS_THRESHOLD_~${IS_THRESHOLD}~g" \
                    -e "s~_IS_RATE_REDUCED_~${IS_RATE_REDUCED}~g" \
                    -e "s~_IS_RATE_NORMAL_~${IS_RATE_NORMAL}~g" \
                    -e "s~_TAX_RATE_USED_~${TAX_RATE_USED}~g" \
                    -e "s~_TOTAL_ALLOCATIONS_~${TOTAL_ALLOCATIONS}~g" \
                    -e "s~_TOTAL_NEEDED_~${TOTAL_NEEDED}~g" \
                    -e "s~_DEFICIT_~${DEFICIT}~g" \
                    -e "s~_IMPACT_10_MULTIPASS_~${IMPACT_10_MULTIPASS}~g" \
                    -e "s~_IMPACT_5_ZENCARDS_~${IMPACT_5_ZENCARDS}~g" \
                    -e "s~_IMPACT_TOTAL_REVENUE_~${IMPACT_TOTAL_REVENUE}~g" \
                    -e "s~_SOCIETAIRE_SHARE_PRICE_~${SOCIETAIRE_SHARE_PRICE}~g" \
                    -e "s~_SOCIETAIRE_SHARE_PRICE_EUR_~${SOCIETAIRE_SHARE_PRICE_EUR}~g" \
                    -e "s~_SOCIETAIRE_CAPITAL_~${SOCIETAIRE_CAPITAL}~g" \
                    -e "s~_FAILED_ALLOCATIONS_~${FAILED_ALLOCATIONS}~g" \
                    -e "s~_CAPITAL_BALANCE_~${CAPITAL_BALANCE}~g" \
                    -e "s~_AMORT_BALANCE_~${AMORT_BALANCE}~g" \
                    -e "s~_MACHINE_VALUE_~${MACHINE_VALUE_REPORT}~g" \
                    -e "s~_DEPRECIATION_PERCENT_~${DEPRECIATION_PERCENT}~g" \
                    -e "s~_WEEKS_PASSED_~${WEEKS_PASSED_REPORT}~g" \
                    -e "s~_DEPRECIATION_WEEKS_~${DEPRECIATION_WEEKS_REPORT}~g" \
                    > "$BENEVOLAT_REPORT"

                # Envoi au Capitaine : merci pour ton sacrifice !
                ${MY_PATH}/../tools/mailjet.sh --expire 7d "$CAPTAINEMAIL" "$BENEVOLAT_REPORT" \
                    "❤️ UPlanet Bénévolat Actif - Merci Capitaine ! - $TODATE" 2>/dev/null \
                    && log_output "📧 Rapport de bénévolat envoyé au Capitaine: $CAPTAINEMAIL" \
                    || log_output "⚠️  Envoi email bénévolat échoué (non-critique)"

                # Envoi à tous les usagers MULTIPASS (message positif de solidarité)
                for player_dir in ~/.zen/game/nostr/*/; do
                    player_email=$(basename "$player_dir")
                    if [[ "$player_email" =~ @ && "$player_email" != "$CAPTAINEMAIL" ]]; then
                        ${MY_PATH}/../tools/mailjet.sh --expire 7d "$player_email" "$BENEVOLAT_REPORT" \
                            "❤️ UPlanet Bénévolat Actif - Semaine $WEEK_KEY" 2>/dev/null
                    fi
                done
            else
                log_output "⚠️  Template de bénévolat non trouvé: $BENEVOLAT_TEMPLATE (non-critique)"
            fi
        fi
        
    else
        log_output "NODE $NODECOIN G1 is NOT INITIALIZED !! UPlanet send 1 G1 to NODE"
        # TX Comment: UP:NetworkID:INIT:IPFSNodeID:Amount (Node wallet activation)
        # First-time activation of NODE wallet with 1 G1 to enable transactions
        ${MY_PATH}/../tools/PAYforSURE.sh "$HOME/.zen/game/uplanet.G1.dunikey" "1" "${NODEG1PUB}" "UP:${UPLANETG1PUB:0:8}:INIT:${IPFSNODEID:0:8}:1G1:GENESIS" 2>/dev/null
    fi
fi

#######################################################################
# PAF BURN & CONVERSION - 4-week operational cost management
# Burn 4-week accumulated PAF from NODE back to UPLANETNAME_G1 and request € conversion
# This creates a deflationary mechanism and enables real € payment for costs
#######################################################################
fourweeks_paf_burn_and_convert() {
    # Calculate current 4-week period (based on week number)
    local current_week=$(date +%V)
    local current_year=$(date +%Y)
    local period_number=$(( (current_week - 1) / 4 + 1 ))
    local period_key="${current_year}-P${period_number}"
    local burn_marker="$HOME/.zen/game/.fourweeks_paf_burn.$period_key"
    
    # Detect station level (X or Y) like DRAGON_p2p_ssh.sh
    local station_level="X"
    if [[ -s ~/.ssh/id_ed25519.pub ]]; then
        local YIPNS=$(${MY_PATH}/../tools/ssh_to_g1ipfs.py "$(cat ~/.ssh/id_ed25519.pub)")
        if [[ ${IPFSNODEID} == ${YIPNS} ]]; then
            station_level="Y"
            log_output "ZEN ECONOMY: Station Level Y detected (SSH/IPFS transmuted)"
        else
            log_output "ZEN ECONOMY: Station Level X detected (SSH/IPFS not linked)"
            log_output "ZEN ECONOMY: ${YIPNS} != ${IPFSNODEID}"
        fi
    else
        log_output "ZEN ECONOMY: Station Level X detected (no SSH key found)"
    fi
    
    # Check if burn was already done for this 4-week period
    if [[ -f "$burn_marker" ]]; then
        log_output "ZEN ECONOMY: 4-week PAF burn already completed for period $period_key"
        return 0
    fi
    
    # Only burn if NODE has sufficient balance and received PAF
    if [[ $(echo "$NODECOIN >= 1" | bc -l) -eq 1 && $(echo "$NODEZEN > 0" | bc -l) -eq 1 ]]; then
        # Calculate 4-week PAF (weekly PAF * 4)
        FOURWEEKS_PAF=$(echo "scale=2; $WEEKLYPAF * 4" | bc -l)
        FOURWEEKS_PAF_G1=$(makecoord $(echo "$FOURWEEKS_PAF / 10" | bc -l))
        
        # Check if NODE has enough for 4-week burn
        if [[ $(echo "$NODEZEN >= $FOURWEEKS_PAF" | bc -l) -eq 1 ]]; then
            log_output "ZEN ECONOMY: Processing 4-week PAF burn..."
            log_output "  Period: $period_key (4-week cycle)"
            log_output "  4-week PAF: $FOURWEEKS_PAF Ẑen ($FOURWEEKS_PAF_G1 G1)"
            log_output "  From: NODE (operational costs)"
            log_output "  To: UPLANETNAME_G1 (burn & convert)"
            
            # Burn: NODE → UPLANETNAME_G1
            # Check station level and use appropriate method
            local burn_result=1
            if [[ "$station_level" == "Y" && -f "$HOME/.zen/game/secret.NODE.dunikey" ]]; then
                # Level Y: Use existing NODE wallet
                log_output "ZEN ECONOMY: Using NODE wallet (Level Y): $HOME/.zen/game/secret.NODE.dunikey"
                ${MY_PATH}/../tools/PAYforSURE.sh \
                    "$HOME/.zen/game/secret.NODE.dunikey" \
                    "$FOURWEEKS_PAF_G1" \
                    "${UPLANETG1PUB}" \
                    "UP:${UPLANETG1PUB:0:8}:BURN:${period_key}:${FOURWEEKS_PAF}Z:NODE>DEFLATE" \
                    2>/dev/null
                burn_result=$?
            elif [[ "$station_level" == "X" ]]; then
                # Level X: Use CAPTAIN MULTIPASS as burn source (no NODE wallet available)
                log_output "ZEN ECONOMY: Level X - Using CAPTAIN MULTIPASS for PAF burn (no NODE wallet available)"
                if [[ -n "$CAPTAINEMAIL" && -f "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" ]]; then
                    ${MY_PATH}/../tools/PAYforSURE.sh \
                        "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.dunikey" \
                        "$FOURWEEKS_PAF_G1" \
                        "${UPLANETG1PUB}" \
                        "UP:${UPLANETG1PUB:0:8}:BURN:${period_key}:${FOURWEEKS_PAF}Z:CPT>DEFLATE_LvX" \
                        2>/dev/null
                    burn_result=$?
                else
                    log_output "ZEN ECONOMY: Level X - No CAPTAIN MULTIPASS available for PAF burn"
                    return 1
                fi
            else
                log_output "ZEN ECONOMY: Unknown station level or missing NODE wallet"
                return 1
            fi

            if [[ $burn_result -eq 0 ]]; then
                log_output "✅ 4-week PAF burn completed: $FOURWEEKS_PAF Ẑen"
                
                # Request OpenCollective conversion (1Ẑ = 1€)
                request_opencollective_conversion "$FOURWEEKS_PAF" "$period_key"
                
                # Mark burn as completed
                echo "$(date -u +%Y%m%d%H%M%S) FOURWEEKS_PAF_BURN $FOURWEEKS_PAF ZEN NODE $period_key" > "$burn_marker"
                chmod 600 "$burn_marker"
            else
                log_output "❌ 4-week PAF burn failed"
            fi
        else
            log_output "ZEN ECONOMY: Insufficient NODE balance for 4-week PAF burn"
            log_output "  Required: $FOURWEEKS_PAF Ẑen"
            log_output "  Available: $NODEZEN Ẑen"
        fi
    else
        log_output "ZEN ECONOMY: NODE not ready for PAF burn (balance: $NODEZEN Ẑen)"
    fi
}

# Function to request OpenCollective conversion using GraphQL API
# Creates an Expense (INVOICE) on the collective so the PAF burn can be converted to €
# Conforms to https://graphql-docs-v2.opencollective.com
request_opencollective_conversion() {
    local zen_amount="$1"
    local period="${2:-$(date +%Y%m%d)}"
    local euro_amount=$(echo "scale=2; $zen_amount * 1" | bc -l)  # 1Ẑ = 1€
    local euro_cents=$(echo "$euro_amount * 100" | bc | cut -d. -f1)

    log_output "ZEN ECONOMY: Requesting OpenCollective conversion..."
    log_output "  Amount: $zen_amount Ẑen → $euro_amount €"
    log_output "  Period: $period"

    ## Resolve OC token — try cooperative DID config, then OC2UPlanet .env, then env var
    local OC_TOKEN=""
    if type coop_config_get &>/dev/null; then
        OC_TOKEN=$(coop_config_get "OCAPIKEY" 2>/dev/null || echo "")
    fi
    ## Fallback: read OCAPIKEY from OC2UPlanet .env (same token used by oc2uplanet.sh)
    if [[ -z "$OC_TOKEN" && -s "$HOME/.zen/workspace/OC2UPlanet/.env" ]]; then
        OC_TOKEN=$(grep "^OCAPIKEY=" "$HOME/.zen/workspace/OC2UPlanet/.env" 2>/dev/null \
            | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    ## Fallback: environment variable
    [[ -z "$OC_TOKEN" ]] && OC_TOKEN="${OCAPIKEY:-}"

    ## Resolve OC slug — from OC2UPlanet .env or default
    local OC_SLUG=""
    if [[ -s "$HOME/.zen/workspace/OC2UPlanet/.env" ]]; then
        OC_SLUG=$(grep "^OCSLUG=" "$HOME/.zen/workspace/OC2UPlanet/.env" 2>/dev/null \
            | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    [[ -z "$OC_SLUG" ]] && OC_SLUG="${OCSLUG:-}"

    if [[ -z "$OC_SLUG" ]]; then
        log_output "⚠️  No OCSLUG configured — cannot create OC expense"
        log_output "   Configure OCSLUG in ~/.zen/workspace/OC2UPlanet/.env"
        echo "$(date -u +%Y%m%d%H%M%S) MANUAL_CONVERSION_NEEDED $zen_amount ZEN $euro_amount EUR $period" \
            >> "$HOME/.zen/game/opencollective_conversion.log"
        return 1
    fi

    ## Resolve OC API URL — ORIGIN mode = staging, else production
    local OC_API_URL="https://api.opencollective.com/graphql/v2"
    local ORIGIN_KEY="0000000000000000000000000000000000000000000000000000000000000000"
    if [[ -s ~/.ipfs/swarm.key ]]; then
        local swarm_last=$(tail -n 1 ~/.ipfs/swarm.key 2>/dev/null)
        if [[ "$swarm_last" == "$ORIGIN_KEY" || -z "$swarm_last" ]]; then
            OC_API_URL="https://api-staging.opencollective.com/graphql/v2"
            log_output "  Mode: ORIGIN (staging API)"
        fi
    fi

    if [[ -z "$OC_TOKEN" ]]; then
        log_output "⚠️  No OpenCollective token configured"
        log_output "   Options:"
        log_output "   1. coop_config_set OCAPIKEY \"token\""
        log_output "   2. Set OCAPIKEY in ~/.zen/workspace/OC2UPlanet/.env"
        log_output "   Manual conversion needed: $zen_amount Ẑen → $euro_amount €"
        echo "$(date -u +%Y%m%d%H%M%S) MANUAL_CONVERSION_NEEDED $zen_amount ZEN $euro_amount EUR $period" \
            >> "$HOME/.zen/game/opencollective_conversion.log"
        return 1
    fi

    ## Resolve payee — Captain email for expense submission
    local PAYEE_EMAIL="${CAPTAINEMAIL:-}"
    if [[ -z "$PAYEE_EMAIL" ]]; then
        log_output "⚠️  No CAPTAINEMAIL — cannot identify expense payee"
        echo "$(date -u +%Y%m%d%H%M%S) MANUAL_CONVERSION_NEEDED $zen_amount ZEN $euro_amount EUR $period NO_PAYEE" \
            >> "$HOME/.zen/game/opencollective_conversion.log"
        return 1
    fi

    ## Build GraphQL createExpense mutation
    ## Required fields: account (collective), payee, type, description, items[]
    local description="PAF Burn Conversion - ${IPFSNODEID:0:8} Node Operational Costs (${period})"
    local reference="BURN:PAF:${period}:${zen_amount}ZEN"

    local graphql_payload
    graphql_payload=$(cat <<EOGQL
{
    "query": "mutation CreateExpense(\$expense: ExpenseCreateInput!) { createExpense(expense: \$expense) { id legacyId status amount { valueInCents currency } description } }",
    "variables": {
        "expense": {
            "account": { "slug": "${OC_SLUG}" },
            "payee": { "email": "${PAYEE_EMAIL}" },
            "type": "INVOICE",
            "description": "${description}",
            "tags": ["paf-burn", "operational-costs", "zen-conversion"],
            "items": [
                {
                    "description": "${reference}",
                    "amount": ${euro_cents}
                }
            ]
        }
    }
}
EOGQL
    )

    log_output "  Collective: $OC_SLUG"
    log_output "  Payee: $PAYEE_EMAIL"
    log_output "  API: $OC_API_URL"

    local response
    response=$(curl -s -X POST "$OC_API_URL" \
        -H "Personal-Token: $OC_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$graphql_payload" 2>/dev/null)

    if [[ $? -ne 0 || -z "$response" ]]; then
        log_output "⚠️  OpenCollective API request failed (network error)"
        echo "$(date -u +%Y%m%d%H%M%S) OC_API_FAILED $zen_amount ZEN $euro_amount EUR $period" \
            >> "$HOME/.zen/game/opencollective_conversion.log"
        return 1
    fi

    ## Check for GraphQL errors
    local errors
    errors=$(echo "$response" | jq -r '.errors // empty' 2>/dev/null)
    if [[ -n "$errors" && "$errors" != "null" ]]; then
        log_output "⚠️  OpenCollective GraphQL errors:"
        echo "$response" | jq -r '.errors[] | "  - \(.message)"' 2>/dev/null | tee -a "$LOG_FILE"
        echo "$(date -u +%Y%m%d%H%M%S) OC_GRAPHQL_ERROR $zen_amount ZEN $euro_amount EUR $period" \
            >> "$HOME/.zen/game/opencollective_conversion.log"
        return 1
    fi

    local expense_id
    expense_id=$(echo "$response" | jq -r '.data.createExpense.id // empty' 2>/dev/null)
    if [[ -n "$expense_id" ]]; then
        log_output "✅ OpenCollective expense created: $euro_amount €"
        log_output "   Expense ID: $expense_id"
        log_output "   Reference: $reference"
    else
        log_output "⚠️  Unexpected OC response:"
        echo "$response" | head -c 300 | tee -a "$LOG_FILE"
        return 1
    fi
}

# Execute 4-week PAF burn (runs once per 4-week period)
fourweeks_paf_burn_and_convert

#######################################################################

## AFTER PAF PAYMENT: CHECK SWARM SUBSCRIPTIONS
# ${MY_PATH}/ZEN.SWARM.payments.sh
## Ouverture d'un compte sur un autre noeud de l'essaim pour activer des services...
## Il suffit d'alimenter le MULTIPASS pour payer sur place.


#######################################################################
# PRIMAL WALLET CONTROL - Protect cooperative wallets from intrusions
# Ensure all cooperative wallets only receive funds from authorized sources
#######################################################################
log_output "ZEN ECONOMY: Checking primal wallet control for cooperative wallets..."

# Define cooperative wallets to protect
declare -A COOPERATIVE_WALLETS=(
    ["UPLANETNAME"]="$HOME/.zen/game/uplanet.dunikey"
    ["UPLANETNAME_SOCIETY"]="$HOME/.zen/game/uplanet.SOCIETY.dunikey"
    ["UPLANETNAME_CASH"]="$HOME/.zen/game/uplanet.CASH.dunikey"
    ["UPLANETNAME_RND"]="$HOME/.zen/game/uplanet.RnD.dunikey"
    ["UPLANETNAME_ASSETS"]="$HOME/.zen/game/uplanet.ASSETS.dunikey"
    ["UPLANETNAME_IMPOT"]="$HOME/.zen/game/uplanet.IMPOT.dunikey"
    ["UPLANETNAME.CAPTAIN"]="$HOME/.zen/game/uplanet.captain.dunikey"
    ["UPLANETNAME_INTRUSION"]="$HOME/.zen/game/uplanet.INTRUSION.dunikey"
    ["UPLANETNAME_CAPITAL"]="$HOME/.zen/game/uplanet.CAPITAL.dunikey"
    ["UPLANETNAME_AMORTISSEMENT"]="$HOME/.zen/game/uplanet.AMORTISSEMENT.dunikey"
    ["NODE"]="$HOME/.zen/game/secret.NODE.dunikey"
)

# Master primal source for cooperative wallets (UPLANETNAME_G1 is the unique primal source)
COOPERATIVE_MASTER_PRIMAL="$UPLANETNAME_G1"
COOPERATIVE_ADMIN_EMAIL="${CAPTAINEMAIL:-support@qo-op.com}"

# Check each cooperative wallet for primal compliance
for wallet_name in "${!COOPERATIVE_WALLETS[@]}"; do
    wallet_dunikey="${COOPERATIVE_WALLETS[$wallet_name]}"
    
    if [[ -f "$wallet_dunikey" ]]; then
        # Extract public key from dunikey file
        wallet_pubkey=$(cat "$wallet_dunikey" 2>/dev/null | grep "pub:" | cut -d ' ' -f 2)
        
        if [[ -n "$wallet_pubkey" ]]; then
            log_output "ZEN ECONOMY: Checking primal control for $wallet_name (${wallet_pubkey:0:8}...)"
            
            # Run primal wallet control for this cooperative wallet
            log_output "CONTROL UPLANET ZEN - Cooperative wallet primal control"
            ${MY_PATH}/../tools/primal_wallet_control.sh \
                "$wallet_dunikey" \
                "$wallet_pubkey" \
                "$COOPERATIVE_MASTER_PRIMAL" \
                "$COOPERATIVE_ADMIN_EMAIL"

            if [[ $? -eq 0 ]]; then
                log_output "ZEN ECONOMY: Primal control OK for $wallet_name"
            else
                log_output "ZEN ECONOMY: Primal control issues detected for $wallet_name"
            fi
        else
            log_output "ZEN ECONOMY: ⚠️  Could not extract public key from $wallet_name"
        fi
    else
        log_output "ZEN ECONOMY: ⚠️  Wallet file not found: $wallet_name ($wallet_dunikey)"
    fi
done

log_output "ZEN ECONOMY: Primal wallet control completed for all cooperative wallets"

#######################################################################
# Cooperative allocation check - trigger 3x1/3 allocation if conditions are met
# This will be executed after PAF payment to ensure proper economic flow
#######################################################################
log_output "ZEN ECONOMY: Checking cooperative allocation conditions..."
${MY_PATH}/../RUNTIME/ZEN.COOPERATIVE.3x1-3.sh

#######################################################################
# BROADCAST ECONOMIC HEALTH TO NOSTR (kind 30850) - DAILY
# Enables swarm-level economic visibility and legal compliance reporting
# See: nostr-nips/101-economic-health-extension.md
#######################################################################
if [[ -x "${MY_PATH}/ECONOMY.broadcast.sh" ]]; then
    log_output "📡 Broadcasting economic health to NOSTR constellation..."
    ${MY_PATH}/ECONOMY.broadcast.sh 2>/dev/null
    if [[ $? -eq 0 ]]; then
        log_output "✅ Economic health report broadcasted successfully"
    else
        log_output "⚠️  Economic health broadcast failed (non-critical)"
    fi
fi

#######################################################################
# Marquer le paiement hebdomadaire comme complété
# Format : YEAR-Wxx:RESILIENCEn:NODEn:CPTn
# Le bénévolat (LOVE) paie toujours la différence — pas de GAME OVER
#######################################################################
echo "$WEEK_KEY:RESILIENCE${RESILIENCE_LEVEL:-0}:NODE${NODE_PAID:-0}:CPT${CAPTAIN_PAID:-0}" > "$PAYMENT_MARKER"
log_output "ZEN ECONOMY: Semaine $WEEK_KEY complétée — Niveau de Résilience: ${RESILIENCE_LEVEL:-0}"
if [[ $(echo "${LOVE_DONATION_THIS_WEEK:-0} > 0" | bc -l) -eq 1 ]]; then
    log_output "❤️  Don aux Communs cette semaine : ${LOVE_DONATION_THIS_WEEK} Ẑen (voir Love Ledger)"
fi
log_output "========================================================================"

# L'économie UPlanet ne connaît pas de faillite :
# Le bénévolat et la résilience collective assurent la continuité du réseau.
# 0 = Abondance, 1 = Solidarité ASSETS, 2 = Solidarité R&D, 3 = Bénévolat
exit 0
