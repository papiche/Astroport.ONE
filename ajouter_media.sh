#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# SCRIPT INTERACTIF POUR AJOUTER UN FICHIER à UPLANET
# Compatible avec UPlanet_FILE_CONTRACT.md
# Utilise upload2ipfs.sh et l'API FastAPI (/api/fileupload, /webcam)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

# REMOVE GtkDialog errors for zenity
shopt -s expand_aliases
alias zenity='zenity 2> >(grep -v GtkDialog >&2)'

# Notification function - supports multiple methods
# Alternatives to espeak: notify-send (desktop notifications), zenity (GUI), or console output
notify_user() {
    local message="$1"
    local priority="${2:-normal}"  # low, normal, critical
    
    # Method 1: Desktop notifications (notify-send) - RECOMMENDED
    # Works on most Linux desktop environments (GNOME, KDE, XFCE, etc.)
    if command -v notify-send &> /dev/null; then
        notify-send --urgency="$priority" --expire-time=3000 \
            "UPlanet Media" "$message" 2>/dev/null || true
        return 0
    fi
    
    # Method 2: Zenity info dialog (fallback if notify-send not available)
    # Non-intrusive popup that auto-closes after 3 seconds
    if command -v zenity &> /dev/null && [[ -z "$2" ]]; then
        zenity --info --title="UPlanet Media" --text="$message" --timeout=3 2>/dev/null || true
        return 0
    fi
    
    # Method 3: Console output with emoji (always available)
    # Fallback that always works, even in headless environments
    echo "🔔 $message" >&2
    
    # Method 4: espeak (if available and user explicitly enables audio)
    # Only used if ENABLE_AUDIO_NOTIFICATIONS=yes environment variable is set
    if command -v espeak &> /dev/null && [[ "${ENABLE_AUDIO_NOTIFICATIONS:-}" == "yes" ]]; then
        /usr/bin/espeak "$message" >/dev/null 2>&1 || true
    fi
}

# Legacy espeak alias for backward compatibility
# All existing espeak calls will now use notify_user() instead
# This provides desktop notifications by default, with espeak as optional fallback
alias espeak='notify_user'

## CHECK IF IPFS DAEMON IS RUNNING
floop=0
while [[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]]; do
    sleep 1
    ((floop++)) && [ $floop -gt 5 ] \
        && echo "ERROR. IPFS daemon not running on port 5001" \
        && espeak 'ERROR. I P F S daemon not running' \
        && exit 1
done

. "${MY_PATH}/tools/my.sh"
[[ $IPFSNODEID == "" ]] && echo "IPFSNODEID manquant" && espeak "IPFS NODE ID Missing" && exit 1

start=`date +%s`

########################################################################
# Check dependencies
[[ $(which ipfs) == "" ]] && echo "ERREUR! Installez ipfs" && exit 1
[[ $(which zenity) == "" ]] && echo "ERREUR! Installez zenity" && echo "sudo apt install zenity" && exit 1
[[ $(which curl) == "" ]] && echo "ERREUR! Installez curl" && exit 1
[[ $(which jq) == "" ]] && echo "ERREUR! Installez jq" && exit 1

mkdir -p ~/.zen/tmp/
LOG_FILE="$HOME/.zen/tmp/ajouter_media.log"
# Properly redirect both stdout and stderr to log file while also showing on terminal
exec > >(tee -a "$LOG_FILE")
exec 2>&1

URL="$1"
PLAYER="$2"
CHOICE="$3"
echo ">>> RUNNING 'ajouter_media.sh' URL=$URL PLAYER=$PLAYER CHOICE=$CHOICE"
echo ">>> Log file: $LOG_FILE"

# API endpoint
API_URL="http://127.0.0.1:54321"

# Check who is PLAYER ?
if [[ ${PLAYER} == "" ]]; then
    players=($(ls ~/.zen/game/nostr 2>/dev/null | grep "@"))
    if [[ ${#players[@]} -ge 1 ]]; then
        espeak "SELECT YOUR MULTIPASS"
        OUTPUT=$(zenity --list --width 480 --height 200 --title="Choix du PLAYER" --column="Astronaute" "${players[@]}")
        [[ ${OUTPUT} == "" ]] && espeak "No player selected. EXIT" && exit 1
    else
        OUTPUT="${players}"
    fi
    PLAYER=${OUTPUT}
else
    OUTPUT=${PLAYER}
fi

####### NO CURRENT ? PLAYER = .current
[[ ! -d $(readlink ~/.zen/game/players/.current 2>/dev/null) ]] \
    && rm -f ~/.zen/game/players/.current \
    && ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current

echo "ADMIN : "$(cat ~/.zen/game/players/.current/.player 2>/dev/null)

[[ ${OUTPUT} != ""  ]] \
&& espeak "${OUTPUT} CONNECTED" \
&& . "${MY_PATH}/tools/my.sh"

## NO PLAYER AT ALL
[[ ${OUTPUT} == "" ]] \
&& espeak "Astronaut. Please register." \
&& xdg-open "$API_URL/g1" \
&& exit 1 \
PSEUDO=$(myPlayerUser)

"$MY_PATH/tools/search_for_this_email_in_players.sh" "${PLAYER}" 2>/dev/null || true

espeak "Hello $PSEUDO"

## MULTIPASS (Zen)
G1PUB=$(cat ~/.zen/game/nostr/${PLAYER}/G1PUBNOSTR)
[[ $G1PUB == "" ]] && espeak "ERROR NO G 1 PUBLIC KEY FOUND - EXIT" && exit 1

# Get NOSTR npub and hex from player
NPUB=$(cat ~/.zen/game/nostr/${PLAYER}/NPUB 2>/dev/null || echo "")
NPUB_HEX=$(cat ~/.zen/game/nostr/${PLAYER}/HEX 2>/dev/null || echo "")

# If we have NPUB but not HEX, try to convert (or use search_for_this_email_in_players.sh)
if [[ -z "$NPUB_HEX" ]] && [[ -n "$NPUB" ]]; then
    # Try to get HEX from user directory lookup
    USER_NOSTR_DIR="$HOME/.zen/game/nostr/${PLAYER}"
    if [[ -d "$USER_NOSTR_DIR" ]]; then
        # Check if there's a .secret.nostr file we can extract pubkey from
        if [[ -f "$USER_NOSTR_DIR/.secret.nostr" ]]; then
            # Try to extract pubkey from secret file (if it contains pubkey info)
            # For now, we'll use a helper script if available
            if [[ -f "${MY_PATH}/tools/nostr2hex.py" ]]; then
                NPUB_HEX=$(python3 "${MY_PATH}/tools/nostr2hex.py" "$NPUB" 2>/dev/null || echo "")
            fi
        fi
    fi
fi

# If still no HEX, try to get from search_for_this_email_in_players.sh output
if [[ -z "$NPUB_HEX" ]]; then
    SEARCH_OUTPUT=$($MY_PATH/tools/search_for_this_email_in_players.sh ${PLAYER} 2>/dev/null | tail -n 1)
    # Extract hex from output if available
    if echo "$SEARCH_OUTPUT" | grep -qE '^[a-f0-9]{64}$'; then
        NPUB_HEX="$SEARCH_OUTPUT"
    fi
fi

if [[ -z "$NPUB_HEX" ]] && [[ -z "$NPUB" ]]; then
        echo "⚠️  No NOSTR keys found for player ${PLAYER}"
    echo "⚠️  Upload will work but provenance tracking will be disabled"
fi

# Function to get user uDRIVE path
get_user_udrive_path() {
    local player="$1"
    if [[ -n "$player" && "$player" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        local nostr_base_path="$HOME/.zen/game/nostr"
        if [ -d "$nostr_base_path" ]; then
            for email_dir in "$nostr_base_path"/*; do
                if [ -d "$email_dir" ] && [[ "$email_dir" == *"$player"* ]]; then
                    local udrive_path="$email_dir/APP/uDRIVE"
                    mkdir -p "$udrive_path"
                    echo "$udrive_path"
                    return 0
                fi
            done
        fi
    fi
    return 1
}

# Get user uDRIVE path for file storage
USER_UDRIVE_PATH=$(get_user_udrive_path "$PLAYER")
if [[ -n "$USER_UDRIVE_PATH" ]]; then
    echo "✅ Using uDRIVE path: $USER_UDRIVE_PATH"
else
    echo "⚠️  Could not determine uDRIVE path for player: $PLAYER"
    USER_UDRIVE_PATH="$HOME/.zen/tmp"
fi

########################################################################
## EXCEPTION COPIE PRIVE
# Un joueur MULTIPASS enregistré a déjà accepté les CGU UPlanet à l'onboarding.
# On enregistre l'accord silencieusement (sans GUI) pour éviter les dépendances zenity.
LEGAL_FILE="$HOME/.zen/game/nostr/${PLAYER}/legal"
if [[ ! -f "$LEGAL_FILE" ]]; then
    echo "⚖️  Copie privée — En ajoutant ce média sur UPlanet, vous confirmez agir"
    echo "   dans le cadre de la copie privée (Code de la propriété intellectuelle français)."
    echo "   Ref: https://fr.wikipedia.org/wiki/Droit_d%27auteur_en_France"
    echo "$G1PUB" > "$LEGAL_FILE"
    echo "✅ Accord enregistré pour $PLAYER"
fi

########################################################################
# CHOOSE CATEGORY
if [ $URL ]; then
    echo "URL: $URL"
    REVSOURCE="$(echo "$URL" | awk -F/ '{print $3}' | rev)_"
    [[ ${CHOICE} == "" ]] && IMPORT=$(zenity --entry --width 640 --title="$URL => UPlanet" --text="${PLAYER} Type de media à importer ?" --entry-text="Video" PDF MP3) || IMPORT="$CHOICE"
    [[ $IMPORT == "" ]] && espeak "No choice made. Exit" && exit 1
    [[ $IMPORT == "Video" ]] && IMPORT="Youtube"
    CHOICE="$IMPORT"
fi

[ ! $2 ] && [[ $CHOICE == "" ]] && CHOICE=$(zenity --list --width 320 --height 380 --title="Catégorie" --text="Quelle catégorie pour ce media ?" --column="Catégorie" "uDRIVE" "Youtube" "MP3" "Film" "Serie" "Video" "PDF" "Vlog" "IA" 2>/dev/null)
[[ $CHOICE == "" ]] && echo "NO CHOICE MADE" && exit 1

# LOWER CARACTERS
CAT=$(echo "${CHOICE}" | awk '{print tolower($0)}')
# UPPER CARACTERS
CHOICE=$(echo "${CAT}" | awk '{print toupper($0)}')

PREFIX=$(echo "${CAT}" | head -c 1 | awk '{ print toupper($0) }' ) # ex: F, S, A, Y, M ... P W
[[ $PREFIX == "" ]] && exit 1

########################################################################
# Fonction NIP-42 : authentification NOSTR partagée youtube/mp3
send_nip42_auth() {
    local secret_file="$HOME/.zen/game/nostr/${PLAYER}/.secret.nostr"
    local send_script="${MY_PATH}/tools/nostr_send_note.py"
    local relay="ws://127.0.0.1:7777"
    [[ ! -f "$secret_file" ]] || [[ ! -f "$send_script" ]] && return 0
    local challenge=""
    [[ -n "$NPUB_HEX" ]] && challenge=$(curl -sf "http://127.0.0.1:54321/api/nip42/challenge?npub=${NPUB_HEX}" 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('challenge',''))" 2>/dev/null || true)
    [[ -z "$challenge" ]] && challenge="local-$(date +%s)-${IPFSNODEID:0:8}"
    local out
    out=$(python3 "$send_script" --keyfile "$secret_file" \
        --content "${IPFSNODEID} ${UPLANETNAME_G1}" --kind 22242 \
        --tags '[["relay","'"$relay"'"],["challenge","'"$challenge"'"]]' \
        --relays "$relay" 2>&1)
    local evid
    evid=$(echo "$out" | grep -oE '"event_id"\s*:\s*"[a-f0-9]{64}"' | grep -oE '[a-f0-9]{64}' | head -1)
    if [[ -n "$NPUB_HEX" && -n "$evid" ]]; then
        local mdir="$HOME/.zen/game/nostr/${PLAYER}"
        printf '{"pubkey":"%s","event_hash":"%s","created_at":%d}' "$NPUB_HEX" "$evid" "$(date +%s)" \
            > "${mdir}/.nip42_auth_${NPUB_HEX}" 2>/dev/null
        rm -f "${mdir}/.nip42_auth" 2>/dev/null || true
        sleep 2
    fi
}

########################################################################
# Collecte métadonnées TMDB (scraping + saisie utilisateur)
# Arg $1: "film" ou "serie"
# Popule toutes les variables TITLE*, SERIES_NAME, EPISODE_NAME*,
#   YEAR, GENRES, GENRES_ARRAY, SEASON_NUMBER, EPISODE_NUMBER,
#   TITLE_WITH_EPISODE, VIDEO_DESC, TMDB_METADATA_FILE, SOURCE_TYPE
ask_tmdb_metadata() {
    local tmdb_cat="$1"
    [[ "$tmdb_cat" == "serie" ]] && MEDIA_TYPE="tv" || MEDIA_TYPE="movie"
    SOURCE_TYPE="$tmdb_cat"

    # Ouvrir TMDB dans le navigateur
    zenity --question --width 300 --text "Ouvrir https://www.themoviedb.org pour $(echo "${FILE_TITLE}" | sed 's/_/%20/g') ?" \
        && xdg-open "https://www.themoviedb.org/search?query=$(echo "${FILE_TITLE}" | sed 's/_/%20/g')"

    local tmdb_prompt="film"
    [[ "$tmdb_cat" == "serie" ]] && tmdb_prompt="série"
    local TMDB_URL_INPUT
    TMDB_URL_INPUT=$(zenity --entry --title="Identification TMDB" \
        --text="URL ou ID du ${tmdb_prompt}.\nEx: https://www.themoviedb.org/${MEDIA_TYPE}/301528-toy-story-4\nou: 301528-toy-story-4" \
        --entry-text="")
    [[ -z "$TMDB_URL_INPUT" ]] && exit 1

    if [[ "$TMDB_URL_INPUT" =~ ^https?:// ]]; then
        TMDB_URL="$TMDB_URL_INPUT"
        MEDIAID=$(echo "$TMDB_URL_INPUT" | rev | cut -d '/' -f 1 | rev)
    else
        MEDIAID="$TMDB_URL_INPUT"
        TMDB_URL="https://www.themoviedb.org/${MEDIA_TYPE}/$MEDIAID"
    fi
    MEDIAID=$(echo "$MEDIAID" | rev | cut -d '/' -f 1 | rev)
    local CMED
    CMED=$(echo "$MEDIAID" | cut -d '-' -f 1)
    if ! [[ "$CMED" =~ ^[0-9]+$ ]]; then
        zenity --warning --width 600 \
            --text "Numéro TMDB invalide. Seules les vidéos référencées sur The Movie Database sont acceptées. Sinon importez en mode 'Video'" \
            && exit 1
    fi
    MEDIAID="$CMED"
    [[ "$TMDB_URL" =~ ^https?:// ]] || TMDB_URL="https://www.themoviedb.org/${MEDIA_TYPE}/$MEDIAID"

    # Scraping TMDB (optionnel)
    SCRAPE_TMDB="no"
    SCRAPED_METADATA=""
    if zenity --question --width 400 --title="Scraper TMDB ?" \
            --text="Enrichir automatiquement les métadonnées ?\nURL: $TMDB_URL"; then
        SCRAPE_TMDB="yes"
        echo "🔍 Scraping TMDB: $TMDB_URL"
        local scraper="${MY_PATH}/IA/scraper.TMDB.py"
        [[ ! -f "$scraper" ]] && scraper="${HOME}/.zen/Astroport.ONE/IA/scraper.TMDB.py"
        [[ ! -f "$scraper" ]] && scraper="${HOME}/workspace/AAA/Astroport.ONE/IA/scraper.TMDB.py"
        if [[ -f "$scraper" ]]; then
            SCRAPED_METADATA=$(python3 "$scraper" "$TMDB_URL" 2>/dev/null)
            if echo "$SCRAPED_METADATA" | jq -e '.' >/dev/null 2>&1; then
                echo "✅ Métadonnées TMDB récupérées"
                local sg
                sg=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
                [[ -n "$sg" ]] && echo "   📋 Genres: $sg"
            else
                echo "⚠️  Scraping échoué, saisie manuelle"
                SCRAPED_METADATA=""
                SCRAPE_TMDB="no"
            fi
        else
            echo "⚠️  Scraper introuvable, saisie manuelle"
            SCRAPE_TMDB="no"
        fi
    fi

    # Titre
    SERIES_NAME="" EPISODE_NAME="" EPISODE_NAME_FOR_FILENAME="" EPISODE_NAME_FOR_PUBLICATION="" TITLE_WITH_EPISODE=""
    if [[ "$tmdb_cat" == "serie" ]]; then
        [[ "$SCRAPE_TMDB" == "yes" ]] && SERIES_NAME=$(echo "$SCRAPED_METADATA" | jq -r '.title // .name // empty' 2>/dev/null)
        if [[ -z "$SERIES_NAME" ]]; then
            [[ -z "$PLAYER" ]] && SERIES_NAME=$(zenity --entry --width 400 --title "Nom de la série" --text "Nom de la série" --entry-text="$FILE_TITLE")
            [[ -z "$SERIES_NAME" ]] && SERIES_NAME="$FILE_TITLE"
        fi
        SERIES_NAME=$(echo "${SERIES_NAME}" | detox --inline)

        local ep_default="$FILE_TITLE"
        if [[ "$SCRAPE_TMDB" == "yes" ]]; then
            local ep_meta
            ep_meta=$(echo "$SCRAPED_METADATA" | jq -r '.episode_title // .episode_name // empty' 2>/dev/null)
            [[ -n "$ep_meta" ]] && ep_default="$ep_meta"
        fi
        local ep_clean
        ep_clean=$(echo "$ep_default" | sed 's/_/ /g;s/  */ /g;s/^ *//;s/ *$//')
        [[ -z "$PLAYER" ]] && EPISODE_NAME=$(zenity --entry --width 400 --title "Titre de l'épisode" --text "Titre de l'épisode" --entry-text="$ep_clean") || EPISODE_NAME="$ep_clean"
        [[ -z "$EPISODE_NAME" ]] && EPISODE_NAME="$ep_clean"
        EPISODE_NAME_FOR_FILENAME=$(echo "${EPISODE_NAME}" | detox --inline)
        EPISODE_NAME_FOR_PUBLICATION="$EPISODE_NAME"
        TITLE="$EPISODE_NAME_FOR_FILENAME"
        TITLE_FOR_PUBLICATION="$EPISODE_NAME_FOR_PUBLICATION"
        TITLE_FOR_FILENAME="$TITLE"
    else
        if [[ "$SCRAPE_TMDB" == "yes" ]]; then
            TITLE=$(echo "$SCRAPED_METADATA" | jq -r '.title // empty' 2>/dev/null)
            [[ -z "$TITLE" ]] && TITLE="$FILE_TITLE"
        else
            TITLE="$FILE_TITLE"
        fi
        local title_clean
        title_clean=$(echo "$TITLE" | sed 's/_/ /g;s/  */ /g;s/^ *//;s/ *$//')
        [[ -z "$PLAYER" ]] && TITLE=$(zenity --entry --width 300 --title "Titre" --text "Titre de la vidéo" --entry-text="$title_clean") || TITLE="$title_clean"
        [[ -z "$TITLE" ]] && exit 1
        TITLE_FOR_FILENAME=$(echo "${TITLE}" | detox --inline)
        TITLE_FOR_PUBLICATION="$TITLE"
    fi

    # Année
    YEAR=""
    [[ "$SCRAPE_TMDB" == "yes" ]] && YEAR=$(echo "$SCRAPED_METADATA" | jq -r '.year // empty' 2>/dev/null)
    YEAR=$(zenity --entry --width 300 --title "Année" --text "Année de sortie (ex: 1985)" --entry-text="$YEAR")

    # Genres
    GENRES="" GENRES_ARRAY="[]"
    local GENRES_DEFAULT=""
    if [[ "$SCRAPE_TMDB" == "yes" ]]; then
        GENRES_ARRAY=$(echo "$SCRAPED_METADATA" | jq -c '.genres // []' 2>/dev/null)
        GENRES_DEFAULT=$(echo "$SCRAPED_METADATA" | jq -r '.genres // [] | join(", ")' 2>/dev/null)
        [[ "$GENRES_ARRAY" == "[]" || -z "$GENRES_ARRAY" ]] && GENRES_ARRAY="[]"
    fi
    [[ -z "$PLAYER" ]] && GENRES=$(zenity --entry --width 400 --title "Genres" \
        --text "Genres séparés par virgules. Ex: Action, Science Fiction" \
        --entry-text="$GENRES_DEFAULT") || GENRES="$GENRES_DEFAULT"
    [[ -z "$GENRES" ]] && GENRES="$GENRES_DEFAULT"
    if [[ -n "$GENRES" ]]; then
        GENRES_ARRAY=$(echo "$GENRES" | jq -R 'split(", ") | map(select(. != "")) | map(gsub("^\\s+|\\s+$"; ""))' 2>/dev/null || echo "[]")
        echo "📋 Genres: $GENRES"
    fi

    # Saison/Épisode (série uniquement)
    SEASON_NUMBER="" EPISODE_NUMBER=""
    if [[ "$tmdb_cat" == "serie" ]]; then
        # Auto-détection depuis le nom de fichier (format SxxExx)
        if echo "$FILE_NAME" | grep -qiE 's[0-9]+e[0-9]+'; then
            SEASON_NUMBER=$(echo "$FILE_NAME" | grep -oiE 's([0-9]+)' | grep -oiE '[0-9]+' | head -1)
            EPISODE_NUMBER=$(echo "$FILE_NAME" | grep -oiE 'e([0-9]+)' | grep -oiE '[0-9]+' | head -1)
        fi
        # Récupération depuis les métadonnées TMDB scrapées
        if [[ "$SCRAPE_TMDB" == "yes" && -n "$SCRAPED_METADATA" ]]; then
            local scraped_season scraped_episode
            scraped_season=$(echo "$SCRAPED_METADATA" | jq -r '.season_number // empty' 2>/dev/null)
            scraped_episode=$(echo "$SCRAPED_METADATA" | jq -r '.episode_number // empty' 2>/dev/null)
            [[ -n "$scraped_season" ]] && SEASON_NUMBER="$scraped_season"
            [[ -n "$scraped_episode" ]] && EPISODE_NUMBER="$scraped_episode"
        fi
        # Extraction du numéro d'épisode seul depuis le nom de fichier (ex: E002)
        if [[ -z "$EPISODE_NUMBER" ]]; then
            EPISODE_NUMBER=$(echo "$FILE_NAME" | grep -oiE 'E([0-9]+)' | grep -oiE '[0-9]+' | head -1)
        fi
        # Saisie interactive (toujours affichée pour les séries, comme le champ Année)
        SEASON_NUMBER=$(zenity --entry --width 300 --title "Saison" --text "Numéro de saison (ex: 1)" --entry-text="${SEASON_NUMBER:-1}")
        EPISODE_NUMBER=$(zenity --entry --width 300 --title "Épisode" --text "Numéro d'épisode (ex: 1)" --entry-text="${EPISODE_NUMBER}")
        [[ -n "$SEASON_NUMBER" ]] && ! [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]] && SEASON_NUMBER=""
        [[ -n "$EPISODE_NUMBER" ]] && ! [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]] && EPISODE_NUMBER=""
        if [[ -n "$SEASON_NUMBER" && -n "$EPISODE_NUMBER" ]]; then
            TITLE_WITH_EPISODE="${TITLE} - S${SEASON_NUMBER}E${EPISODE_NUMBER}"
            echo "📺 S${SEASON_NUMBER}E${EPISODE_NUMBER} — $TITLE_WITH_EPISODE"
        fi
    fi

    # Description
    VIDEO_DESC=""
    SCRAPED_DIRECTOR="" SCRAPED_CREATOR="" SCRAPED_RUNTIME="" SCRAPED_VOTE_AVG="" SCRAPED_VOTE_COUNT=""
    if [[ "$SCRAPE_TMDB" == "yes" ]]; then
        local tagline overview
        tagline=$(echo "$SCRAPED_METADATA" | jq -r '.tagline // empty' 2>/dev/null)
        overview=$(echo "$SCRAPED_METADATA" | jq -r '.overview // empty' 2>/dev/null)
        [[ -n "$tagline" ]] && VIDEO_DESC="$tagline"
        [[ -n "$overview" ]] && VIDEO_DESC="${VIDEO_DESC:+$VIDEO_DESC  }$overview"
        SCRAPED_DIRECTOR=$(echo "$SCRAPED_METADATA" | jq -r '.director // empty' 2>/dev/null)
        SCRAPED_CREATOR=$(echo "$SCRAPED_METADATA" | jq -r '.creator // empty' 2>/dev/null)
        SCRAPED_RUNTIME=$(echo "$SCRAPED_METADATA" | jq -r '.runtime // empty' 2>/dev/null)
        SCRAPED_VOTE_AVG=$(echo "$SCRAPED_METADATA" | jq -r '.vote_average // empty' 2>/dev/null)
        SCRAPED_VOTE_COUNT=$(echo "$SCRAPED_METADATA" | jq -r '.vote_count // empty' 2>/dev/null)
    fi
    [[ -z "$PLAYER" ]] && VIDEO_DESC=$(zenity --entry --width 600 --title "Description" --text "Description (optionnel)" --entry-text="$VIDEO_DESC")
    # Sanitiser les sauts de ligne (TMDB overview peut être multi-lignes)
    VIDEO_DESC=$(echo "${VIDEO_DESC}" | tr '\n\r' ' ')

    # Construire JSON métadonnées TMDB
    TMDB_METADATA_FILE="$HOME/.zen/tmp/tmdb_${MEDIAID}_$(date +%s).json"
    local TMDB_METADATA_JSON=""
    if [[ "$SCRAPE_TMDB" == "yes" && -n "$SCRAPED_METADATA" ]]; then
        local jq_base='. | .title=$title | .year=$year | .tmdb_id=($tmdb_id|tonumber) | .media_type=$media_type | .tmdb_url=$tmdb_url'
        if [[ "$GENRES_ARRAY" != "[]" && -n "$GENRES_ARRAY" ]]; then
            TMDB_METADATA_JSON=$(echo "$SCRAPED_METADATA" | jq \
                --arg title "$TITLE" --arg year "$YEAR" --arg tmdb_url "$TMDB_URL" \
                --arg tmdb_id "$MEDIAID" --arg media_type "$MEDIA_TYPE" \
                --argjson genres_array "$GENRES_ARRAY" \
                "${jq_base} | .genres=\$genres_array" 2>/dev/null)
        else
            TMDB_METADATA_JSON=$(echo "$SCRAPED_METADATA" | jq \
                --arg title "$TITLE" --arg year "$YEAR" --arg tmdb_url "$TMDB_URL" \
                --arg tmdb_id "$MEDIAID" --arg media_type "$MEDIA_TYPE" \
                "$jq_base" 2>/dev/null)
        fi
    fi
    # Fallback JSON minimal
    if ! echo "${TMDB_METADATA_JSON:-}" | jq -e '.' >/dev/null 2>&1; then
        TMDB_METADATA_JSON=$(printf '{"tmdb_id":%s,"media_type":"%s","title":"%s","year":"%s","tmdb_url":"%s","genres":%s}' \
            "$MEDIAID" "$MEDIA_TYPE" "$TITLE" "$YEAR" "$TMDB_URL" "${GENRES_ARRAY:-[]}")
    fi
    # Ajouter champs série
    if [[ "$tmdb_cat" == "serie" ]]; then
        [[ -n "$SERIES_NAME" ]] && TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --arg v "$SERIES_NAME" '.series_name=$v' 2>/dev/null || echo "$TMDB_METADATA_JSON")
        [[ -n "$EPISODE_NAME" ]] && TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --arg v "$EPISODE_NAME" '.episode_name=$v' 2>/dev/null || echo "$TMDB_METADATA_JSON")
        [[ "$SEASON_NUMBER" =~ ^[0-9]+$ ]] && TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --argjson v "$SEASON_NUMBER" '.season_number=$v' 2>/dev/null || echo "$TMDB_METADATA_JSON")
        [[ "$EPISODE_NUMBER" =~ ^[0-9]+$ ]] && TMDB_METADATA_JSON=$(echo "$TMDB_METADATA_JSON" | jq --argjson v "$EPISODE_NUMBER" '.episode_number=$v' 2>/dev/null || echo "$TMDB_METADATA_JSON")
    fi
    echo "$TMDB_METADATA_JSON" > "$TMDB_METADATA_FILE"
    echo "✅ Métadonnées TMDB: $TMDB_METADATA_FILE"
    echo "📋 Titre: $TITLE | Année: $YEAR | TMDB: $MEDIAID ($MEDIA_TYPE)"
    [[ -n "$GENRES" ]] && echo "   Genres: $GENRES"
    [[ -n "$SCRAPED_DIRECTOR" ]] && echo "   Réalisateur: $SCRAPED_DIRECTOR"
    [[ -n "$SCRAPED_VOTE_AVG" ]] && echo "   Note: $SCRAPED_VOTE_AVG ($SCRAPED_VOTE_COUNT votes)"
    [[ "$tmdb_cat" == "serie" && -n "$SEASON_NUMBER" && -n "$EPISODE_NUMBER" ]] && echo "   S${SEASON_NUMBER}E${EPISODE_NUMBER}"
}

########################################################################
# Conversion H264/AAC + upload IPFS + publication NOSTR
# Arg $1: fichier source
# Utilise les vars globales: TITLE_FOR_FILENAME TITLE_FOR_PUBLICATION VIDEO_DESC
#   NPUB_HEX PLAYER SOURCE_TYPE TMDB_METADATA_FILE
#   SERIES_NAME EPISODE_NAME_FOR_PUBLICATION SEASON_NUMBER EPISODE_NUMBER
#   GENRES_ARRAY TITLE_WITH_EPISODE
convert_and_publish_video() {
    local SRC_FILE="$1"
    local FILE_EXT="${SRC_FILE##*.}"
    local TITLE_FNAME="${TITLE_FOR_FILENAME:-${TITLE:-$(basename "$SRC_FILE" .mp4)}}"

    # Conversion H264/AAC si nécessaire
    local VIDEO_CODEC_SRC AUDIO_CODEC_SRC
    VIDEO_CODEC_SRC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nokey=1 "$SRC_FILE" 2>/dev/null | tr -d '[:space:]')
    AUDIO_CODEC_SRC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
        -of default=noprint_wrappers=1:nokey=1 "$SRC_FILE" 2>/dev/null | tr -d '[:space:]')
    local FINAL_FILE="$HOME/.zen/tmp/${TITLE_FNAME}.mp4"
    echo "🔍 Codec source: video=$VIDEO_CODEC_SRC audio=$AUDIO_CODEC_SRC"

    if [[ "$FILE_EXT" != "mp4" || "$VIDEO_CODEC_SRC" != "h264" || "$AUDIO_CODEC_SRC" != "aac" ]]; then
        espeak "Converting to H264 M P 4. Please wait"
        ffmpeg -loglevel quiet -i "$SRC_FILE" -c:v libx264 -profile:v main -level 4.1 \
            -c:a aac -b:a 128k -movflags +faststart "$FINAL_FILE"
        espeak "M P 4 ready"
    else
        cp "$SRC_FILE" "$FINAL_FILE"
    fi

    # Upload via upload2ipfs.sh
    echo "📤 Upload via upload2ipfs.sh..."
    local UPLOAD_OUTPUT_FILE="$HOME/.zen/tmp/upload_$(date +%s).json"
    local UPLOAD_SCRIPT="${MY_PATH}/../UPassport/upload2ipfs.sh"
    [[ ! -f "$UPLOAD_SCRIPT" ]] && UPLOAD_SCRIPT="${HOME}/.zen/UPassport/upload2ipfs.sh"
    [[ ! -f "$UPLOAD_SCRIPT" ]] && UPLOAD_SCRIPT="${HOME}/workspace/AAA/UPassport/upload2ipfs.sh"
    if [[ ! -f "$UPLOAD_SCRIPT" ]]; then
        echo "❌ upload2ipfs.sh introuvable"
        espeak "Upload script not found"
        rm -f "${TMDB_METADATA_FILE:-}"
        exit 1
    fi

    local -a upload_args=("$UPLOAD_SCRIPT")
    [[ -n "${TMDB_METADATA_FILE:-}" && -f "$TMDB_METADATA_FILE" ]] && upload_args+=(--metadata "$TMDB_METADATA_FILE")
    upload_args+=("$FINAL_FILE" "$UPLOAD_OUTPUT_FILE")
    [[ -n "${NPUB_HEX:-}" ]] && upload_args+=("$NPUB_HEX")
    bash "${upload_args[@]}" > "$HOME/.zen/tmp/upload2ipfs.log" 2>&1
    local UPLOAD_EXIT=$?

    if [[ $UPLOAD_EXIT -ne 0 || ! -f "$UPLOAD_OUTPUT_FILE" ]] || \
       ! jq -e '.' "$UPLOAD_OUTPUT_FILE" >/dev/null 2>&1; then
        echo "❌ upload2ipfs.sh échoué (code: $UPLOAD_EXIT)"
        cat "$HOME/.zen/tmp/upload2ipfs.log" 2>/dev/null
        espeak "Upload failed"
        rm -f "${TMDB_METADATA_FILE:-}" "$UPLOAD_OUTPUT_FILE"
        exit 1
    fi

    local IPFS_CID DIMENSIONS DURATION_V
    IPFS_CID=$(jq -r '.cid // empty' "$UPLOAD_OUTPUT_FILE")
    DIMENSIONS=$(jq -r '.dimensions // empty' "$UPLOAD_OUTPUT_FILE")
    DURATION_V=$(jq -r '.duration // 0' "$UPLOAD_OUTPUT_FILE")

    if [[ -z "$IPFS_CID" ]]; then
        echo "❌ CID IPFS manquant"
        espeak "IPFS upload failed"
        rm -f "${TMDB_METADATA_FILE:-}" "$UPLOAD_OUTPUT_FILE"
        exit 1
    fi
    echo "✅ Vidéo uploadée sur IPFS! CID: $IPFS_CID"
    [[ -n "$DIMENSIONS" ]] && echo "   Dimensions: $DIMENSIONS"
    [[ -n "$DURATION_V" && "$DURATION_V" != "0" ]] && echo "   Durée: ${DURATION_V}s"
    espeak "Video uploaded successfully" 2>/dev/null || true

    # Enrichir description avec URL TMDB
    if [[ -n "${TMDB_METADATA_FILE:-}" && -f "$TMDB_METADATA_FILE" ]]; then
        local tmdb_u
        tmdb_u=$(jq -r '.tmdb_url // empty' "$TMDB_METADATA_FILE" 2>/dev/null)
        [[ -n "$tmdb_u" ]] && VIDEO_DESC="${VIDEO_DESC:+$VIDEO_DESC  }TMDB: $tmdb_u"
    fi

    # Publication NOSTR
    local PUBLISH_SCRIPT="${MY_PATH}/tools/publish_nostr_video.sh"
    [[ ! -f "$PUBLISH_SCRIPT" ]] && PUBLISH_SCRIPT="${HOME}/.zen/Astroport.ONE/tools/publish_nostr_video.sh"
    local SECRET_FILE="$HOME/.zen/game/nostr/${PLAYER}/.secret.nostr"
    if [[ ! -f "$PUBLISH_SCRIPT" || ! -f "$SECRET_FILE" ]]; then
        [[ ! -f "$PUBLISH_SCRIPT" ]] && echo "❌ publish_nostr_video.sh introuvable"
        [[ ! -f "$SECRET_FILE" ]] && echo "❌ Clé secrète introuvable: $SECRET_FILE"
        espeak "Publish script not found"
        rm -f "${TMDB_METADATA_FILE:-}" "$UPLOAD_OUTPUT_FILE"
        exit 1
    fi

    local PUBLISH_TITLE="${TITLE_FOR_PUBLICATION:-${TITLE:-unknown}}"
    local src_type="${SOURCE_TYPE:-webcam}"
    if [[ "$src_type" == "serie" && -n "${TITLE_WITH_EPISODE:-}" ]]; then
        PUBLISH_TITLE=$(echo "$TITLE_WITH_EPISODE" | sed 's/_/ /g;s/  */ /g;s/^ *//;s/ *$//')
        echo "📺 Titre épisode: $PUBLISH_TITLE"
    fi

    local -a PUBLISH_CMD=("$PUBLISH_SCRIPT" --auto "$UPLOAD_OUTPUT_FILE" --nsec "$SECRET_FILE" --title "$PUBLISH_TITLE")
    [[ -n "${VIDEO_DESC:-}" ]] && PUBLISH_CMD+=(--description "$VIDEO_DESC")
    PUBLISH_CMD+=(--source-type "$src_type")
    echo "📹 Type: $src_type"

    if [[ "$src_type" == "serie" ]]; then
        [[ -n "${SERIES_NAME:-}" ]] && PUBLISH_CMD+=(--series-name "$SERIES_NAME") && echo "📺 Série: $SERIES_NAME"
        [[ -n "${EPISODE_NAME_FOR_PUBLICATION:-}" ]] && PUBLISH_CMD+=(--episode-name "$EPISODE_NAME_FOR_PUBLICATION") && echo "📺 Épisode: $EPISODE_NAME_FOR_PUBLICATION"
        [[ "${SEASON_NUMBER:-}" =~ ^[0-9]+$ ]] && PUBLISH_CMD+=(--season-number "$SEASON_NUMBER") && echo "📺 Saison: $SEASON_NUMBER"
        [[ "${EPISODE_NUMBER:-}" =~ ^[0-9]+$ ]] && PUBLISH_CMD+=(--episode-number "$EPISODE_NUMBER") && echo "📺 Épisode n°: $EPISODE_NUMBER"
    fi

    if [[ -n "${GENRES_ARRAY:-}" && "$GENRES_ARRAY" != "[]" && "$GENRES_ARRAY" != "null" ]]; then
        local gc
        gc=$(echo "$GENRES_ARRAY" | jq -c '.' 2>/dev/null | tr -d '\n\r')
        [[ -n "$gc" ]] && echo "$gc" | jq -e '.' >/dev/null 2>&1 \
            && PUBLISH_CMD+=(--genres "$gc") && echo "🏷️  Genres: $gc"
    fi

    [[ -n "$DIMENSIONS" && "$DIMENSIONS" != "empty" && "$DIMENSIONS" != "640x480" ]] \
        && PUBLISH_CMD+=(--dimensions "$DIMENSIONS") && echo "📐 $DIMENSIONS"
    [[ -n "$DURATION_V" && "$DURATION_V" != "0" && "$DURATION_V" != "empty" ]] \
        && PUBLISH_CMD+=(--duration "$DURATION_V") && echo "⏱️  ${DURATION_V}s"
    PUBLISH_CMD+=(--channel "$PLAYER" --json)

    local PUBLISH_OUTPUT PUBLISH_EXIT
    PUBLISH_OUTPUT=$(bash "${PUBLISH_CMD[@]}" 2>&1)
    PUBLISH_EXIT=$?

    local EVENT_ID
    EVENT_ID=$(echo "$PUBLISH_OUTPUT" | jq -r '.event_id // empty' 2>/dev/null || true)
    [[ -z "$EVENT_ID" ]] && EVENT_ID=$(echo "$PUBLISH_OUTPUT" | \
        grep -oE '"event_id"\s*:\s*"[a-f0-9]{64}"' | grep -oE '[a-f0-9]{64}' | head -1)

    if [[ $PUBLISH_EXIT -eq 0 && -n "$EVENT_ID" ]]; then
        echo "✅ Vidéo publiée sur NOSTR! Event: ${EVENT_ID:0:16}..."
        espeak "Video published"
    elif [[ $PUBLISH_EXIT -eq 0 ]]; then
        echo "⚠️  Upload OK mais event ID absent"
        echo "$PUBLISH_OUTPUT"
        espeak "Upload done but event ID missing"
    else
        echo "❌ Publication NOSTR échouée (code: $PUBLISH_EXIT):"
        echo "$PUBLISH_OUTPUT"
        espeak "Publication failed"
        command -v zenity &>/dev/null && \
            zenity --error --width 640 --title="Erreur publication NOSTR" \
            --text="❌ Publication échouée (code $PUBLISH_EXIT)\n\n$(echo "$PUBLISH_OUTPUT" | tail -5)" \
            2>/dev/null || true
    fi

    rm -f "$UPLOAD_OUTPUT_FILE"
    [[ -n "${TMDB_METADATA_FILE:-}" && -f "$TMDB_METADATA_FILE" ]] && rm -f "$TMDB_METADATA_FILE"
}

########################################################################
########################################################################
case ${CAT} in
########################################################################
# CASE ## VLOG - Redirect to webcam endpoint
########################################################################
    vlog)
        espeak "Opening webcam interface"
        xdg-open "${API_URL}/webcam" 2>/dev/null || echo "Open ${API_URL}/webcam in your browser"
    exit 0
    ;;

########################################################################
# CASE ## YOUTUBE
########################################################################
    youtube)
    espeak "youtube : video copying"

    YTURL="$URL"
    [ ! $2 ] && [[ $YTURL == "" ]] && YTURL=$(zenity --entry --width 420 --title "Lien ou identifiant à copier" --text "Indiquez le lien (URL) ou l'ID de la vidéo" --entry-text="")
    [[ $YTURL == "" ]] && echo "URL EMPTY " && exit 1

    echo "VIDEO $YTURL"
    echo "Processing URL: $YTURL"

    # Create temporary download directory
    TEMP_YOUTUBE_DIR="$HOME/.zen/tmp.media/youtube_$(date -u +%s%N | cut -b1-13)"
    mkdir -p "$TEMP_YOUTUBE_DIR"

    # CONSERVÉ : Monitor download progress (feedback vocal)
    monitor_download_progress() {
        local download_dir="$1"
        local start_time=$(date +%s)
        local last_announce_time=$start_time
        local announce_interval=30
        local step=0
        
        while true; do
            sleep 5
            local mp4_files=$(find "$download_dir" -maxdepth 1 -name "*.mp4" -type f 2>/dev/null)
            if [[ -n "$mp4_files" ]]; then
                local file_size1=$(stat -c%s "$mp4_files" 2>/dev/null || echo "0")
                sleep 3
                local file_size2=$(stat -c%s "$mp4_files" 2>/dev/null || echo "0")
                if [[ "$file_size1" == "$file_size2" ]] && [[ $file_size1 -gt 1000000 ]]; then
                    espeak "Download complete" 2>/dev/null || true
                    break
                fi
            fi
            
            local current_time=$(date +%s)
            local elapsed=$((current_time - last_announce_time))
            local total_elapsed=$((current_time - start_time))
            
            if [[ $total_elapsed -gt 7200 ]]; then break; fi
            
            if [[ $elapsed -ge $announce_interval ]]; then
                step=$((step + 1))
                local minutes=$((total_elapsed / 60))
                local seconds=$((total_elapsed % 60))
                if [[ -n "$mp4_files" ]]; then
                    local current_size=$(stat -c%s "$mp4_files" 2>/dev/null || echo "0")
                    local size_mb=$(echo "$current_size" | awk '{printf "%.1f", $1 / (1024 * 1024)}')
                    espeak "Download in progress. Step $step. ${minutes} minutes ${seconds} seconds. ${size_mb} megabytes downloaded" 2>/dev/null || true
                else
                    espeak "Download in progress. Step $step. ${minutes} minutes ${seconds} seconds" 2>/dev/null || true
                fi
                last_announce_time=$current_time
            fi
        done
    }

    espeak "Starting YouTube download" 2>/dev/null || true
    monitor_download_progress "$TEMP_YOUTUBE_DIR" &
    MONITOR_PID=$!

    JSON_OUTPUT_FILE="$HOME/.zen/tmp/youtube_json_$$.json"
    mkdir -p "$(dirname "$JSON_OUTPUT_FILE")"

    # $PLAYER pour les cookies
    echo "📥 Downloading YouTube video (Max 480p) via process_youtube.sh..."
    ${MY_PATH}/IA/process_youtube.sh --json-file "$JSON_OUTPUT_FILE" --output-dir "$TEMP_YOUTUBE_DIR" "$YTURL" "mp4" "$PLAYER"
    YTDLP_EXIT=$?

    # Stop monitoring
    kill $MONITOR_PID 2>/dev/null || true
    wait $MONITOR_PID 2>/dev/null || true

    # Validation JSON
    if [[ ! -f "$JSON_OUTPUT_FILE" || ! -s "$JSON_OUTPUT_FILE" ]]; then
        echo "❌ ERROR: Le JSON de retour est manquant ou vide."
        espeak "YouTube download failed"
        exit 1
    fi

    YOUTUBE_JSON=$(cat "$JSON_OUTPUT_FILE")
    rm -f "$JSON_OUTPUT_FILE"

    if echo "$YOUTUBE_JSON" | jq -e '.error' >/dev/null 2>&1; then
        ERROR_MSG=$(echo "$YOUTUBE_JSON" | jq -r '.error')
        [ -z "$2" ] && command -v zenity &> /dev/null && zenity --error --width 600 --title="YouTube Download Error" --text="❌ ERROR: $ERROR_MSG" 2>/dev/null || true
        echo "❌ ERROR: $ERROR_MSG"
        espeak "YouTube processing error"
        exit 1
    fi

    # Extraction des données
    TITLE_RAW=$(echo "$YOUTUBE_JSON" | jq -r '.title // empty')
    TITLE=$(echo "$TITLE_RAW" | sed 's/_/ /g' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//')
    DURATION=$(echo "$YOUTUBE_JSON" | jq -r '.duration // "0"')
    FILENAME=$(echo "$YOUTUBE_JSON" | jq -r '.filename // empty')
    FILE_PATH_DOWNLOADED=$(echo "$YOUTUBE_JSON" | jq -r '.file_path // empty')
    METADATA_FILE_FROM_JSON=$(echo "$YOUTUBE_JSON" | jq -r '.metadata_file // empty')

    if [[ -z "$FILENAME" || -z "$FILE_PATH_DOWNLOADED" || ! -f "$FILE_PATH_DOWNLOADED" ]]; then
        echo "❌ ERROR: Downloaded file not found."
        espeak "Download failed"
        exit 1
    fi

    echo "✅ Downloaded: $FILENAME (Duration: $DURATION s)"
    espeak "Download completed successfully." 2>/dev/null || true

    # NIP-42 Authentication
    echo "🔐 Sending NIP-42 authentication event..."
    send_nip42_auth

    # Extraction Complète des Métadonnées Youtube (Pour le contrat UPlanet v2.0)
    YOUTUBE_METADATA_JSON_FILE="$HOME/.zen/tmp/youtube_metadata_$(date +%s).json"
    if [[ -n "$METADATA_FILE_FROM_JSON" ]] && [[ -f "$METADATA_FILE_FROM_JSON" ]] && command -v jq &> /dev/null; then
        echo "📋 Extracting comprehensive YouTube metadata..."
        jq '{
            youtube_id: .id, youtube_url: .webpage_url, youtube_short_url: .short_url,
            title: .title, description: .description, uploader: .uploader,
            uploader_id: .uploader_id, uploader_url: .uploader_url, channel: .channel,
            channel_id: .channel_id, channel_url: .channel_url, channel_follower_count: .channel_follower_count,
            duration: .duration, view_count: .view_count, like_count: .like_count, comment_count: .comment_count,
            average_rating: .average_rating, age_limit: .age_limit, upload_date: .upload_date, release_date: .release_date,
            timestamp: .timestamp, availability: .availability, live_status: .live_status, was_live: .was_live,
            format: .format, format_id: .format_id, format_note: .format_note, width: .width, height: .height,
            fps: .fps, vcodec: .vcodec, acodec: .acodec, abr: .abr, vbr: .vbr, tbr: .tbr, filesize: .filesize,
            filesize_approx: .filesize_approx, ext: .ext, resolution: .resolution, categories: .categories,
            tags: .tags, chapters: .chapters, subtitles: .subtitles, automatic_captions: .automatic_captions,
            thumbnail: .thumbnail, thumbnails: .thumbnails, license: .license, language: .language,
            languages: .languages, location: .location, artist: .artist, album: .album, track: .track,
            creator: .creator, alt_title: .alt_title, series: .series, season: .season, season_number: .season_number,
            episode: .episode, episode_number: .episode_number, playlist: .playlist, playlist_id: .playlist_id,
            playlist_title: .playlist_title, playlist_index: .playlist_index, n_entries: .n_entries,
            webpage_url_basename: .webpage_url_basename, webpage_url_domain: .webpage_url_domain, extractor: .extractor,
            extractor_key: .extractor_key, epoch: .epoch, modified_timestamp: .modified_timestamp, modified_date: .modified_date,
            requested_subtitles: .requested_subtitles, has_drm: .has_drm, is_live: .is_live, release_timestamp: .release_timestamp, heatmap: .heatmap
        }' "$METADATA_FILE_FROM_JSON" > "$YOUTUBE_METADATA_JSON_FILE" 2>/dev/null || rm -f "$YOUTUBE_METADATA_JSON_FILE"
    fi

    # API UPLOAD
    echo "📤 Uploading video via /api/fileupload..."
    espeak "Starting video upload to IPFS" 2>/dev/null || true
    
    if [[ -f "$YOUTUBE_METADATA_JSON_FILE" ]]; then
        UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" -F "file=@${FILE_PATH_DOWNLOADED}" -F "npub=${NPUB}" -F "youtube_metadata=@${YOUTUBE_METADATA_JSON_FILE}")
    else
        UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" -F "file=@${FILE_PATH_DOWNLOADED}" -F "npub=${NPUB}")
    fi
    
    if ! echo "$UPLOAD_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
        echo "❌ ERROR: /api/fileupload failed. Response: $UPLOAD_RESPONSE"
        espeak "Upload failed"
        exit 1
    fi

    IPFS_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.new_cid // empty')
    INFO_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.info // empty')
    THUMBNAIL_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.thumbnail_ipfs // empty')
    GIFANIM_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.gifanim_ipfs // empty')
    FILE_HASH=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileHash // empty')
    DIMENSIONS=$(echo "$UPLOAD_RESPONSE" | jq -r '.dimensions // empty')
    UPLOAD_CHAIN=$(echo "$UPLOAD_RESPONSE" | jq -r '.upload_chain // empty')

    echo "✅ Video uploaded to IPFS! CID: $IPFS_CID"
    espeak "Video uploaded successfully" 2>/dev/null || true

    # User Input & Description
    [ ! $2 ] && VIDEO_TITLE=$(zenity --entry --width 600 --title "Titre de la vidéo" --text "Confirmez le titre" --entry-text="$TITLE")
    [[ -z "$VIDEO_TITLE" ]] && VIDEO_TITLE="$TITLE"
    VIDEO_TITLE=$(echo "${VIDEO_TITLE}" | tr '\n\r' ' ')

    [ ! $2 ] && VIDEO_DESC=$(zenity --entry --width 600 --title "Description" --text "Description de la vidéo (optionnel)" --entry-text="")
    VIDEO_DESC=$(echo "${VIDEO_DESC}" | tr '\n\r' ' ')
    
    # Auto-enrich desc with YouTube Info
    if [[ -f "$YOUTUBE_METADATA_JSON_FILE" ]] && command -v jq &> /dev/null; then
        YT_UPLOADER=$(jq -r '.uploader // .channel // empty' "$YOUTUBE_METADATA_JSON_FILE" 2>/dev/null)
        YT_URL=$(jq -r '.youtube_url // .webpage_url // empty' "$YOUTUBE_METADATA_JSON_FILE" 2>/dev/null)
        if [[ -n "$YT_UPLOADER" ]] || [[ -n "$YT_URL" ]]; then
            [[ -n "$VIDEO_DESC" ]] && VIDEO_DESC="${VIDEO_DESC}  Source YouTube: ${YT_UPLOADER}\n${YT_URL}" || VIDEO_DESC="Source YouTube: ${YT_UPLOADER}\n${YT_URL}"
        fi
    fi

    # Renouveler l'auth NIP-42 (TTL 5 min, download peut dépasser ça)
    echo "🔐 Refreshing NIP-42 authentication..."
    send_nip42_auth

    # API PUBLISH (NIP-71)
    echo "📹 Publishing video via /webcam endpoint..."
    PUBLISH_DATA="player=${PLAYER}&ipfs_cid=${IPFS_CID}&thumbnail_ipfs=${THUMBNAIL_CID}&gifanim_ipfs=${GIFANIM_CID}&info_cid=${INFO_CID}&file_hash=${FILE_HASH}&mime_type=video/mp4&upload_chain=${UPLOAD_CHAIN}&duration=${DURATION}&video_dimensions=${DIMENSIONS}&title=${VIDEO_TITLE}&description=${VIDEO_DESC}&publish_nostr=true&npub=${NPUB}&youtube_url=${YTURL}"
    
    PUBLISH_RESPONSE=$(curl -s -X POST "${API_URL}/webcam" -H "Content-Type: application/x-www-form-urlencoded" -d "$PUBLISH_DATA")
    
    if echo "$PUBLISH_RESPONSE" | grep -q "success\|✅"; then
        echo "✅ Video published successfully!"
        espeak "YouTube video published"
    else
        echo "❌ Publication échouée. Réponse: $PUBLISH_RESPONSE"
        espeak "YouTube video publication failed"
        command -v zenity &>/dev/null && \
            zenity --error --width 640 --title="Erreur publication YouTube" \
            --text="❌ Publication échouée\n\n$(echo "$PUBLISH_RESPONSE" | head -5)" \
            2>/dev/null || true
    fi

    # Cleanup
    rm -rf "$TEMP_YOUTUBE_DIR"
    [[ -f "$YOUTUBE_METADATA_JSON_FILE" ]] && rm -f "$YOUTUBE_METADATA_JSON_FILE"
    ;;

########################################################################
# CASE ## PDF
########################################################################
    pdf)
        espeak "Importing file or web page to P D F"

        [ ! $2 ] && [[ $URL == "" ]] && URL=$(zenity --entry --width 500 --title "Convertir lien PDF (ANNULER ET CHOISIR UN FICHIER LOCAL)" --text "Indiquez le lien (URL)" --entry-text="")

        if [[ $URL != "" ]]; then
    ## record one page to PDF
            [ ! $2 ] && [[ ! $(which chromium) ]] && zenity --warning --width 600 --text "Utilitaire de copie de page web absent.. Lancez la commande 'sudo apt install chromium'" && exit 1

            cd ~/.zen/tmp/ && rm -f output.pdf

            ${MY_PATH}/tools/timeout.sh -t 30 \
            chromium --headless --use-mobile-user-agent --no-sandbox --print-to-pdf "$URL"
        fi

        if [[ $URL == "" ]]; then
            # SELECT FILE TO ADD
            [ ! $2 ] && FILE=$(zenity --file-selection --title="Sélectionner le fichier à ajouter")
            echo "${FILE}"
            [[ ! -s "${FILE}" ]] && echo "NO FILE" && exit 1

            FILE_NAME="$(basename "${FILE}")"
            cp "${FILE}" ~/.zen/tmp/output.pdf
        fi

        [[ ! -s ~/.zen/tmp/output.pdf ]] && espeak "No file Sorry. Exit" && exit 1

        espeak "OK P D F received"

        CTITLE=$(echo $URL | rev | cut -d '/' -f 1 | rev 2>/dev/null || echo "document")
        [ ! $2 ] && TITLE=$(zenity --entry --width 480 --title "Titre" --text "Quel nom donner à ce fichier ? " --entry-text="${CTITLE}") || TITLE="$CTITLE"
        [[ "$TITLE" == "" ]] && echo "NO TITLE" && exit 1

        FILE_NAME="$(echo "${TITLE}" | detox --inline).pdf"
        
        # Rename temp file (upload2ipfs.sh will handle uDRIVE storage)
        FILE_TO_UPLOAD="$HOME/.zen/tmp/$FILE_NAME"
        mv ~/.zen/tmp/output.pdf "$FILE_TO_UPLOAD"
        
        # Upload via API (upload2ipfs.sh will copy to uDRIVE)
        echo "📤 Uploading PDF via /api/fileupload..."
        
        if [[ -n "$NPUB" ]]; then
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" \
                -F "file=@${FILE_TO_UPLOAD}" \
                -F "npub=${NPUB}")
        else
            echo "⚠️  No NOSTR npub found, upload may fail"
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" \
                -F "file=@${FILE_TO_UPLOAD}" \
                -F "npub=")
        fi
        
        if ! echo "$UPLOAD_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
            echo "❌ Upload failed"
            echo "Response: $UPLOAD_RESPONSE"
            espeak "Upload failed"
            exit 1
        fi

        PDF_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.new_cid // empty')
        echo "✅ PDF uploadé sur IPFS! CID: $PDF_CID"

        # Publication NOSTR (kind 1 note avec lien IPFS)
        if [[ -n "$PDF_CID" && -n "$NPUB_HEX" ]]; then
            NOSTR_SEND_SCRIPT="${MY_PATH}/tools/nostr_send_note.py"
            SECRET_NOSTR_FILE="$HOME/.zen/game/nostr/${PLAYER}/.secret.nostr"
            PDF_IPFS_URL="https://ipfs.copylaradio.com/ipfs/${PDF_CID}"
            PDF_NOTE="${TITLE}
${URL:+Source: $URL
}${PDF_IPFS_URL}"
            if [[ -f "$NOSTR_SEND_SCRIPT" && -f "$SECRET_NOSTR_FILE" ]]; then
                echo "📢 Publication NOSTR (kind 1)..."
                python3 "$NOSTR_SEND_SCRIPT" --keyfile "$SECRET_NOSTR_FILE" \
                    --content "$PDF_NOTE" --kind 1 \
                    --relays "ws://127.0.0.1:7777" >/dev/null 2>&1 \
                    && echo "✅ PDF publié sur NOSTR!" || echo "⚠️ Publication NOSTR échouée (non bloquant)"
            fi
        fi
        espeak "Document ready"
        rm -f "$FILE_TO_UPLOAD"
    ;;

########################################################################
# CASE ## MP3
########################################################################
    mp3)
        [[ "$URL" == "" ]] && URL=$(zenity --entry --width 500 --title "Lien Youtube à convertir en MP3" --text "Indiquez le lien (URL)" --entry-text="")
        [[ "$URL" == "" ]] && echo "URL EMPTY" && exit 1
        
        echo "Processing URL: $URL"
        espeak "OK. Downloading MP 3"

        TEMP_MP3_DIR="$HOME/.zen/tmp.media/mp3_$(date -u +%s%N | cut -b1-13)"
        mkdir -p "$TEMP_MP3_DIR"
        MP3_JSON_FILE="$HOME/.zen/tmp/youtube_mp3_json_$$.json"
        
        # 1. Téléchargement local
        bash "${MY_PATH}/IA/process_youtube.sh" --json-file "$MP3_JSON_FILE" --output-dir "$TEMP_MP3_DIR" "$URL" "mp3"
        
        if [[ ! -f "$MP3_JSON_FILE" ]]; then
            espeak "MP3 processing failed"
            exit 1
        fi
        
        MP3_RESULT=$(cat "$MP3_JSON_FILE")
        rm -f "$MP3_JSON_FILE"
        
        if echo "$MP3_RESULT" | jq -e '.error' >/dev/null 2>&1; then
            ERROR_MSG=$(echo "$MP3_RESULT" | jq -r '.error')
            echo "MP3 processing failed: $ERROR_MSG"
            espeak "MP3 processing failed"
            exit 1
        fi
        
        FILE_TO_UPLOAD=$(echo "$MP3_RESULT" | jq -r '.file_path')
        FILENAME=$(echo "$MP3_RESULT" | jq -r '.filename')
        TITLE=$(echo "$MP3_RESULT" | jq -r '.title')
        DURATION=$(echo "$MP3_RESULT" | jq -r '.duration')
        YOUTUBE_METADATA_FILE=$(echo "$MP3_RESULT" | jq -r '.metadata_file')
        
        if [[ -z "$FILE_TO_UPLOAD" || ! -f "$FILE_TO_UPLOAD" ]]; then
            echo "⚠️ MP3 file not found."
            exit 1
        fi
        
        # Demande du titre à l'utilisateur
        [ ! "$2" ] && AUDIO_TITLE=$(zenity --entry --width 600 --title "Titre de l'audio" --text "Confirmez le titre" --entry-text="$TITLE")
        [[ -z "$AUDIO_TITLE" ]] && AUDIO_TITLE="$TITLE"

        # NIP-42 Authentication
        echo "🔐 Sending NIP-42 authentication event..."
        send_nip42_auth

        # 2. Upload IPFS (Phase 1 du workflow Audio)
        echo "📤 Uploading MP3 via /api/fileupload..."
        if [[ -f "$YOUTUBE_METADATA_FILE" ]]; then
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" -F "file=@${FILE_TO_UPLOAD}" -F "npub=${NPUB}" -F "youtube_metadata=@${YOUTUBE_METADATA_FILE}")
        else
            UPLOAD_RESPONSE=$(curl -s -X POST "${API_URL}/api/fileupload" -F "file=@${FILE_TO_UPLOAD}" -F "npub=${NPUB}")
        fi
        
        if ! echo "$UPLOAD_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
            echo "❌ Upload failed: $UPLOAD_RESPONSE"
            espeak "Upload failed"
            exit 1
        fi
        
        IPFS_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.new_cid // empty')
        INFO_CID=$(echo "$UPLOAD_RESPONSE" | jq -r '.info // empty')
        FILE_HASH=$(echo "$UPLOAD_RESPONSE" | jq -r '.fileHash // empty')

        echo "✅ MP3 uploaded to IPFS! CID: $IPFS_CID"

        # 3. Publication NOSTR via /vocals (Phase 2 du workflow Audio - Section 3.3 et 7.3.3)
        echo "🎤 Publishing audio via /vocals endpoint (NIP-A0)..."
        PUBLISH_DATA="player=${PLAYER}&ipfs_cid=${IPFS_CID}&info_cid=${INFO_CID}&file_hash=${FILE_HASH}&mime_type=audio/mp3&file_name=${FILENAME}&duration=${DURATION}&title=${AUDIO_TITLE}&description=Source YouTube: ${URL}&npub=${NPUB}&publish_nostr=true&encrypted=false"
        
        VOCALS_RESPONSE=$(curl -s -X POST "${API_URL}/vocals" -H "Content-Type: application/x-www-form-urlencoded" -d "$PUBLISH_DATA")
        
        echo "✅ MP3 published successfully!"
        espeak "Ready. MP3 file processed and published"
        
        # Nettoyage
        rm -rf "$TEMP_MP3_DIR"
    ;;

########################################################################
# CASE ## FILM / SERIE
########################################################################
    film | serie)
    espeak "please select your file"
    FILE=$(zenity --file-selection --title="Sélectionner le fichier à ajouter")
    echo "${FILE}"
    [[ -z "$FILE" ]] && exit 1
    FILE_NAME="$(basename "${FILE}")"
    FILE_EXT="${FILE_NAME##*.}"
    FILE_TITLE="${FILE_NAME%.*}"
    TITLE_FOR_FILENAME="" TITLE_WITH_EPISODE="" VIDEO_DESC="" TMDB_METADATA_FILE="" GENRES_ARRAY="[]"
    ask_tmdb_metadata "$CAT"
    convert_and_publish_video "$FILE"
    ;;

########################################################################
# CASE ## VIDEO (personal video)
########################################################################
    video)
        espeak "Add your personal video"
        FILE=$(zenity --file-selection --title="Sélectionner votre vidéo")
        echo "${FILE}"
        [[ -z "$FILE" ]] && exit 1
        FILE_NAME="$(basename "${FILE}")"
        FILE_EXT="${FILE_NAME##*.}"
        FILE_TITLE="${FILE_NAME%.*}"
        TMDB_METADATA_FILE="" GENRES_ARRAY="[]" SOURCE_TYPE="webcam"
        TITLE_FOR_FILENAME="" TITLE_WITH_EPISODE="" VIDEO_DESC=""

        TMDB_ENRICHMENT="Aucun"
        [ ! $2 ] && TMDB_ENRICHMENT=$(zenity --list --width 400 --height 200 \
            --title="Enrichissement TMDB" \
            --text="Enrichir avec des métadonnées TMDB ?" \
            --column="Option" "Aucun" "Film" "Serie" 2>/dev/null || echo "Aucun")
        [[ -z "$TMDB_ENRICHMENT" ]] && TMDB_ENRICHMENT="Aucun"

        if [[ "$TMDB_ENRICHMENT" != "Aucun" ]]; then
            tmdb_cat="film"
            [[ "$TMDB_ENRICHMENT" == "Serie" ]] && tmdb_cat="serie"
            ask_tmdb_metadata "$tmdb_cat"
        else
            TITLE=$(zenity --entry --width 600 --title "Titre" \
                --text "Titre de cette vidéo" --entry-text="${FILE_TITLE}")
            [[ -z "$TITLE" ]] && exit 1
            TITLE=$(echo "${TITLE}" | detox --inline)
            TITLE_FOR_PUBLICATION="$TITLE"
            TITLE_FOR_FILENAME="$TITLE"
            [ ! $2 ] && VIDEO_DESC=$(zenity --entry --width 600 \
                --title "Description" --text "Description (optionnel)" --entry-text="")
            VIDEO_DESC=$(echo "${VIDEO_DESC}" | tr '\n\r' ' ')
        fi

        convert_and_publish_video "$FILE"
    ;;

########################################################################
# CASE ## uDRIVE - Ouvrir l'espace de stockage IPNS personnel
########################################################################
    udrive)
        NOSTRNS=$(cat "$HOME/.zen/game/nostr/${PLAYER}/NOSTRNS" 2>/dev/null)
        if [[ -z "$NOSTRNS" ]]; then
            echo "❌ NOSTRNS introuvable pour $PLAYER"
            espeak "uDRIVE not found"
            exit 1
        fi
        UDRIVE_URL="${myIPFS}${NOSTRNS}/${PLAYER}/APP/uDRIVE"
        echo "🗄️  Ouverture uDRIVE : $UDRIVE_URL"
        xdg-open "$UDRIVE_URL" 2>/dev/null || echo "Ouvrez ce lien dans votre navigateur : $UDRIVE_URL"
        espeak "Opening uDRIVE"
    ;;

########################################################################
# CASE ## IA — Analyse IA d'un fichier IPFS → kind 30504 MineLife/Grimoire
# Usage: ajouter_media.sh <ipfs_cid_ou_fichier> <player> ia [skill_tag]
########################################################################
    ia | analyse)
        MEDIA_SRC="$URL"
        SKILL_TAG="${4:-}"

        # Sélection interactive si absente
        [[ -z "$MEDIA_SRC" ]] && MEDIA_SRC=$(zenity --entry --width 500 \
            --title "Analyse IA — Source" \
            --text "CID IPFS ou chemin fichier local à analyser" \
            --entry-text="")
        [[ -z "$MEDIA_SRC" ]] && echo "Source manquante. Exit." && exit 1

        [[ -z "$SKILL_TAG" ]] && SKILL_TAG=$(zenity --entry --width 400 \
            --title "Compétence MineLife" \
            --text "Tag skill pour kind 30504 (ex: Permaculture, Électronique)" \
            --entry-text="")

        # Résoudre le fichier local (CID → télécharger, ou chemin direct)
        LOCAL_FILE=""
        if [[ -f "$MEDIA_SRC" ]]; then
            LOCAL_FILE="$MEDIA_SRC"
        elif [[ "$MEDIA_SRC" =~ ^Qm[a-zA-Z0-9]{44}$|^bafy[a-zA-Z0-9]+$ ]]; then
            LOCAL_FILE="$HOME/.zen/tmp/ia_analyse_$(date +%s)"
            echo "📥 Récupération IPFS: $MEDIA_SRC"
            ipfs get "$MEDIA_SRC" -o "$LOCAL_FILE" 2>/dev/null || { echo "❌ ipfs get échoué"; exit 1; }
        else
            echo "❌ Source non reconnue (CID ou fichier attendu): $MEDIA_SRC"
            exit 1
        fi

        MIME=$(file --mime-type -b "$LOCAL_FILE")
        echo "🔍 Type: $MIME | Skill: ${SKILL_TAG:-non défini}"

        # Appel Ollama pour analyse (description/transcription du contenu)
        OLLAMA_SCRIPT="${MY_PATH}/tools/question.py"
        [[ ! -f "$OLLAMA_SCRIPT" ]] && OLLAMA_SCRIPT="${MY_PATH}/IA/question.py"
        ANALYSIS_TEXT=""

        if [[ -f "$OLLAMA_SCRIPT" ]] && curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
            espeak "Analyse IA en cours"
            PROMPT="Décris en français le contenu de ce média${SKILL_TAG:+ en lien avec la compétence '$SKILL_TAG'}. Extrait les concepts clés, techniques, et savoir-faire présents."
            ANALYSIS_TEXT=$(python3 "$OLLAMA_SCRIPT" "$PROMPT" "$LOCAL_FILE" 2>/dev/null | head -100)
            echo "📝 Analyse: ${ANALYSIS_TEXT:0:200}..."
        else
            echo "⚠️  Ollama indisponible — analyse textuelle ignorée"
            ANALYSIS_TEXT="Média archivé depuis UPlanet${SKILL_TAG:+ — compétence: $SKILL_TAG}"
        fi

        # Résoudre le CID IPFS
        if [[ "$MEDIA_SRC" =~ ^Qm|^bafy ]]; then
            MEDIA_CID="$MEDIA_SRC"
        else
            MEDIA_CID=$(ipfs add -q "$LOCAL_FILE" | tail -n 1)
        fi
        MEDIA_URL="${myIPFS}/ipfs/${MEDIA_CID}"

        # Publication kind 30504 (knowledge content — MineLife/Grimoire)
        SECRET_FILE="$HOME/.zen/game/nostr/${PLAYER}/.secret.nostr"
        NOSTR_SCRIPT="${MY_PATH}/tools/nostr_send_note.py"
        MOATS_IA=$(date -u +"%Y%m%d%H%M%S%4N")

        if [[ -f "$SECRET_FILE" && -f "$NOSTR_SCRIPT" ]]; then
            TAGS_30504=$(jq -cn \
                --arg d    "${SKILL_TAG:-media_${MOATS_IA}}" \
                --arg title "${SKILL_TAG:-Media UPlanet}" \
                --arg url   "$MEDIA_URL" \
                --arg m     "$MIME" \
                --arg skill "$SKILL_TAG" \
                --arg pub   "$(date +%s)" \
                '[
                    ["d",           $d],
                    ["title",       $title],
                    ["url",         $url],
                    ["m",           $m],
                    ["published_at",$pub],
                    (if ($skill|length)>0 then ["t", $skill] else empty end),
                    ["t", "knowledge"],
                    ["t", "UPlanet"],
                    ["t", "MineLife"]
                ]' 2>/dev/null)

            echo "📡 Publication kind 30504 (MineLife knowledge)..."
            python3 "$NOSTR_SCRIPT" \
                --keyfile "$SECRET_FILE" \
                --content "$ANALYSIS_TEXT" \
                --kind 30504 \
                --tags "$TAGS_30504" \
                --relays "${myRELAY:-wss://relay.copylaradio.com}" \
                --json 2>/dev/null \
                && echo "✅ Kind 30504 publié — skill '$SKILL_TAG' alimenté dans MineLife" \
                || echo "⚠️  Publication kind 30504 échouée"

            # Indexation Qdrant via knowledge_index.sh (si disponible)
            KI_SCRIPT="${MY_PATH}/admin/ia_db/knowledge_index.sh"
            if [[ -f "$KI_SCRIPT" && -n "$ANALYSIS_TEXT" ]]; then
                echo "$ANALYSIS_TEXT" | "$KI_SCRIPT" --stdin --tag "${SKILL_TAG:-media}" 2>/dev/null \
                    && echo "✅ Qdrant: texte indexé" \
                    || true
            fi
        else
            echo "⚠️  Clef NOSTR ou nostr_send_note.py absent — publication ignorée"
        fi

        espeak "Analyse terminée"
    ;;

    ########################################################################
# CASE ## DEFAULT
    ########################################################################
    *)
        [ ! $2 ] && zenity --warning --width 600 --text "Impossible d'interpréter votre commande $CAT"
    exit 1
    ;;

esac

end=$(date +%s)
dur=$((end - start))
espeak "It took $dur seconds to accomplish" 2>/dev/null || true

exit 0
