#!/bin/bash
########################################################################
# Script 20H12 - Système de maintenance et gestion pour Astroport.ONE
#
# Description:
# Ce script effectue une série de tâches de maintenance pour un nœud Astroport.ONE,
# incluant la gestion des services IPFS, la mise à jour des composants logiciels,
# le rafraîchissement des données du réseau, et le monitoring du système.
#
# Fonctionnalités principales:
# - Vérification et gestion du démon IPFS
# - Mise à jour des dépôts Git (G1BILLET, UPassport, NIP-101, Astroport)
# - Maintenance du réseau P2P et des connexions SSH (DRAGON WOT)
# - Rafraîchissement des données UPlanet et Nostr
# - Gestion des services système via systemd
# - Journalisation et reporting par email
#
#
# Conçu pour s'exécuter régulièrement (via cron) avec des modes
# de fonctionnement différents selon l'environnement (LAN/public).
########################################################################
# Version: 1.2 - Analystes ♥️BOX extraites vers tools/heartbox_analysis.sh
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"${MY_PATH}\" && pwd )`"  # absolutized and normalized
if [ -s "$HOME/.astro/bin/activate" ]; then
    source $HOME/.astro/bin/activate
fi

. "${MY_PATH}/tools/my.sh"
start=`date +%s`

# Wrap everything in main() so bash loads the full function into memory
# before any git pull can modify this file mid-execution (git pull suicide prevention).
main() {

########################################################################
## LOGS PERMANENTS - Rotation 7 jours dans ~/.zen/log/
########################################################################
LOG_DIR="$HOME/.zen/log"
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -name "20h12_*.log" -mtime +7 -delete 2>/dev/null || true
LOG_FILE="$LOG_DIR/20h12_$(date +%Y%m%d).log"
touch "$LOG_FILE"
# Rediriger TOUT l'output (stdout + stderr) vers le log permanent daté
exec >> "$LOG_FILE" 2>&1
########################################################################

echo "20H12 (♥‿‿♥) 🌐 /ipns/$IPFSNODEID 🤓 $CAPTAINEMAIL $(hostname -f) $(date)"
# espeak "Ding" > /dev/null 2>&1

########################################################################
########################################################################
## POWER CONSUMPTION - 24/7 PowerJoular (systemd powerjoular.service)
########################################################################
# Report uses last 24h from /var/lib/powerjoular/power_24h.csv (no start/stop in this script)
POWER_24H_CSV="${POWER_24H_CSV:-/var/lib/powerjoular/power_24h.csv}"

########################################################################
## SOLAR TIME CALIBRATION - Recalcul quotidien de l'heure solaire 20H12
########################################################################
# L'équation du temps varie de ±15 min sur l'année → recalibration chaque jour
# RECALIBRATE met à jour la crontab uniquement, sans redémarrer les services
CURRENT_UTC_OFFSET=$(date +%z)
LAST_UTC_OFFSET_FILE="$HOME/.zen/.last_utc_offset"

if [[ -f "$LAST_UTC_OFFSET_FILE" ]]; then
    LAST_UTC_OFFSET=$(cat "$LAST_UTC_OFFSET_FILE")
    [[ "$CURRENT_UTC_OFFSET" != "$LAST_UTC_OFFSET" ]] \
        && echo "⏰ Changement DST détecté : $LAST_UTC_OFFSET → $CURRENT_UTC_OFFSET"
fi
echo "$CURRENT_UTC_OFFSET" > "$LAST_UTC_OFFSET_FILE"

echo "🔄 Recalibration heure solaire 20H12..."
${MY_PATH}/admin/system/cron_VRFY.sh RECALIBRATE

echo "PATH=$PATH"

########################################################################
## IPFS DAEMON STATUS
LOWMODE=$(sudo systemctl status ipfs | grep "preset: disabled") ## IPFS DISABLED - START ONLY FOR SYNC -
! ss -tln 2>/dev/null | grep -q ':5001 ' && LOWMODE="NO 5001" ## IPFS IS STOPPED
[[ ! $isLAN || ${zipit} != "" ]] && LOWMODE="" ## LOWMODE ONLY FOR LAN STATION

########################################################################
## CHECK IF IPFS NODE IS RESPONDING (ipfs name resolve ?)
########################################################################
ipfs --timeout=30s swarm peers 2>/dev/null > ~/.zen/tmp/ipfs.swarm.peers
[[ ! -s ~/.zen/tmp/ipfs.swarm.peers || $? != 0 ]] \
    && echo "---- SWARM COMMUNICATION BROKEN / RESTARTING IPFS DAEMON ----" \
    && sudo systemctl restart ipfs \
    && sleep 60

floop=0
while ! ss -tln 2>/dev/null | grep -q ':5001 '; do
    sleep 10
    ((floop++)) && [ $floop -gt 36 ] \
        && echo "ERROR. IPFS daemon not restarting" \
        && ${MY_PATH}/tools/mailjet.sh --template "$0" --expire 48h "support@qo-op.com" "$LOG_FILE" "IPFS RESTART ERROR 20H12" \
        && exit 1
done


########################################################################
## AUDIT ~/.local/bin — inventaire et réparation des symlinks du Capitaine
########################################################################
ASTRO_PROFILE="$HOME/.zen/.astro"
mkdir -p "$(dirname "$ASTRO_PROFILE")"
{
    echo "=== ~/.local/bin SYMLINK AUDIT — $(date '+%Y-%m-%d %H:%M') ==="
    _fixed=0
    _broken=0
    _ok=0
    for _lnk in "$HOME/.local/bin"/*; do
        [[ -L "$_lnk" ]] || continue
        _target=$(readlink "$_lnk")
        _name=$(basename "$_lnk")
        if [[ -e "$_lnk" ]]; then
            echo "  OK      $_name -> $_target"
            ((_ok++))
        else
            echo "  BROKEN  $_name -> $_target"
            ((_broken++))
            # Chercher le script dans admin/ ou tools/ de ASTRO
            _found=$(find "${MY_PATH}/admin" "${MY_PATH}/tools" \
                -maxdepth 3 \( -name "$_name" -o -name "${_name%.sh}.sh" \) 2>/dev/null \
                | head -1)
            if [[ -n "$_found" && -f "$_found" ]]; then
                ln -f -s "$_found" "$_lnk"
                echo "  FIXED   $_name -> $_found"
                ((_fixed++))
            fi
        fi
    done
    echo "  TOTAL: ${_ok} OK, ${_broken} broken (${_fixed} auto-réparés)"
    echo "=========================================================="
} >> "$ASTRO_PROFILE"

########################################################################
# show Ustats.sh cache of the day
echo "TODAY UPlanet landings"
ls ~/.zen/tmp/Ustats*.json 2>/dev/null # API v2 cache files

# N'afficher que les lignes BROKEN/FIXED dans le log principal
grep -E "BROKEN|FIXED|TOTAL" "$ASTRO_PROFILE" | tail -20 >> "$LOG_FILE" 2>/dev/null || true

echo "=== 22242 LOGIN/ROAMING ======================================" >> $LOG_FILE
cat $HOME/.zen/tmp/nostr.auth.22242.log 2>/dev/null >> $LOG_FILE

echo "=== SWARM INTRUDERS ==========================================" >> $LOG_FILE
cat $HOME/.zen/tmp/swarm_intruders.log 2>/dev/null >> $LOG_FILE
cat "$HOME/.zen/game/firewall_candidates.txt" | sort -u >> $LOG_FILE

echo "___________________bro_dm_daemon.log_______________"
tail -n 300 $HOME/.zen/tmp/bro_dm_daemon.log 2>/dev/null >> $LOG_FILE

echo "=== YOUTUBE / IA SCRAPERS ===================================" >> $LOG_FILE
tail -n 300 $HOME/.zen/tmp/IA.log 2>/dev/null >> $LOG_FILE
tail -n 300 $HOME/.zen/tmp/youtube.com_* 2>/dev/null >> $LOG_FILE

echo "=== NOSTR / CONSTELLATION ERRORS =============================" >> $LOG_FILE
for file in $HOME/.zen/tmp/nostr_*.log; do
    tail -n 300 "$file" 2>/dev/null >> "$LOG_FILE"
done
tail -n 300 $HOME/.zen/strfry/constellation-backfill.error.log 2>/dev/null >> $LOG_FILE

echo "=== SYSTEM/INSTALL ERRORS ====================================" >> $LOG_FILE
if [ -f "$HOME/.zen/install.errors.log" ]; then
    find "$HOME/.zen/install.errors.log" -mtime +7 -delete
fi
cat "$HOME/.zen/install.errors.log" 2>/dev/null >> $LOG_FILE

########################################################################
## NETTOYAGE TMP : On garde les dossiers de cache vitaux !! 
# On ne supprime que les fichiers/dossiers qui ne sont pas dans l'exclusion
find "$HOME/.zen/tmp/" -mindepth 1 -maxdepth 1 ! -name "swarm" ! -name "coucou" ! -name "$IPFSNODEID" -exec rm -rf {} +
## NETTOYAGE tmp.media (disque) : fichiers médias lourds de plus de 24h
[[ -d "$HOME/.zen/tmp.media" ]] && find "$HOME/.zen/tmp.media" -mindepth 1 -maxdepth 1 -mtime +1 -exec rm -rf {} + 2>/dev/null || true

########################################################################
## UPDATE G1BILLET code # 33101
[[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] \
&& cd ~/.zen/G1BILLET/ && git pull \
&& rm -Rf ~/.zen/G1BILLET/tmp/* ## CLEAN TMP

## UPDATE UPassport # 54321 API
[[ -s ~/.zen/UPassport/54321.py ]] \
&& cd ~/.zen/UPassport && git pull

## UPDATE NIP-101 # strfry filter rules
[[ -d ~/.zen/workspace/NIP-101 ]] \
&& cd ~/.zen/workspace/NIP-101 && git pull

## UPDATE UPlanet (./earth CID = /ipns/copylaradio.com)
if [[ -d ~/.zen/workspace/UPlanet ]]; then
    cd ~/.zen/workspace/UPlanet
    # Store current commit hash before pull
    BEFORE_HASH=$(git rev-parse HEAD)
    if git pull; then
        # Store new commit hash after pull
        AFTER_HASH=$(git rev-parse HEAD)
        # Compare hashes to detect changes
        if [[ "$BEFORE_HASH" != "$AFTER_HASH" ]]; then
            echo "UPlanet updated from $BEFORE_HASH to $AFTER_HASH (ipfs add)"
            if ipfs add -rwq ~/.zen/workspace/UPlanet/*; then
                echo "✅ UPlanet successfully added to IPFS"
            else
                echo "❌ Error adding UPlanet to IPFS"
            fi
        else
            echo "UPlanet already up to date"
        fi
    else
        echo "❌ Error pulling UPlanet updates"
    fi
else
    mkdir -p ~/.zen/workspace
    cd ~/.zen/workspace
    if git clone --depth 1 https://github.com/papiche/UPlanet; then
        echo "UPlanet cloned, adding to IPFS..."
        if ipfs add -rwq ~/.zen/workspace/UPlanet/*; then
            echo "✅ UPlanet successfully added to IPFS"
        else
            echo "❌ Error adding UPlanet to IPFS"
        fi
    else
        echo "❌ Error cloning UPlanet"
    fi
fi

## UPDATE OC2UPlanet (Open Collective ZEN Economy bridge + AstroBot Triple Agents)
if [[ -d ~/.zen/workspace/OC2UPlanet ]]; then
    cd ~/.zen/workspace/OC2UPlanet
    git pull
else
    mkdir -p ~/.zen/workspace
    cd ~/.zen/workspace
    git clone --depth 1 https://github.com/papiche/OC2UPlanet.git
fi

## UPDATE sound-spot (Picoport streaming audio + IA swarm)
## Fournit tools/heartbox_analysis.sh aux nœuds Picoport (RPi Zero 2W)
## via ~/.zen/workspace/sound-spot/src/picoport/picoport.sh
if [[ -d ~/.zen/workspace/sound-spot ]]; then
    cd ~/.zen/workspace/sound-spot && git pull
else
    mkdir -p ~/.zen/workspace
    cd ~/.zen/workspace
    git clone --depth 1 https://github.com/papiche/sound-spot.git
fi

## UPDATE cabine-33 (ATOM4LOVE — Interféromètre cosmique et social)
## APK Android servi par UPassport sur /apk/atom4love.apk
CABINE_DIR="$HOME/.zen/workspace/cabine-33"
CABINE_APK="$CABINE_DIR/build/android/atom4love.apk"
CABINE_REPO="https://github.com/papiche/cabine-33.git"
if [[ -d "$CABINE_DIR" ]]; then
    cd "$CABINE_DIR"
    CABINE_BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "none")
    git fetch --depth 1 origin 2>&1 | tail -3
    git reset --hard origin/HEAD 2>&1 | tail -1
    CABINE_AFTER=$(git rev-parse HEAD 2>/dev/null || echo "none")
    if [[ "$CABINE_BEFORE" != "$CABINE_AFTER" || ! -f "$CABINE_APK" ]]; then
        echo "🎮 cabine-33 mis à jour ou APK manquant"
    else
        echo "🎮 cabine-33 à jour (APK existant : $CABINE_APK)"
    fi
else
    echo "🎮 cabine-33 : premier clone..."
    mkdir -p "$HOME/.zen/workspace"
    cd "$HOME/.zen/workspace"
    if git clone --depth 1 "$CABINE_REPO"; then
        echo "🎮 cabine-33 cloné — build APK en arrière-plan..."
    else
        echo "⚠️  cabine-33 : clone échoué"
    fi
fi

## RUN OC2UPlanet monthly — recharge MULTIPASS des membres résidents
## Traite les transactions CREDIT du mois en cours via oc2uplanet.sh
## (cotisation cloud-usage + membre-resident → process_locataire)
OC2UP_MARKER="$HOME/.zen/game/.oc2uplanet_monthly.done"
OC2UP_MONTH=$(date +%Y-%m)
OC2UP_LAST=$(cat "$OC2UP_MARKER" 2>/dev/null)
if [[ "$OC2UP_LAST" != "$OC2UP_MONTH" ]]; then
    if [[ -x ~/.zen/workspace/OC2UPlanet/oc2uplanet.sh ]]; then
        echo "OC2UPlanet: monthly sync for $OC2UP_MONTH"
        (cd ~/.zen/workspace/OC2UPlanet && ./oc2uplanet.sh) \
            && echo "$OC2UP_MONTH" > "$OC2UP_MARKER"
    else
        echo "OC2UPlanet: oc2uplanet.sh not executable — skipping"
    fi
fi

## RAMDISK ~/.zen/tmp — réduit l'usure des cartes SD (idempotent)
${MY_PATH}/install/.zen_tmp_ramdisk.sh

## INSTALL/UPGRADE gcli + cleanup legacy jaklis/silkaj
${MY_PATH}/install/install_gcli.sh

########################################################################
## UPDATE Astroport.ONE code
cd ${MY_PATH}/
git pull

########################################################################
## Updating yt-dlp
${MY_PATH}/install/youtube-dl.sh # retry install if needed
yt-dlp -U #Update yt-dlp

########################################################################
## PING BOOSTRAP & SWARM NODES
${MY_PATH}/ping_bootstrap.sh > /dev/null 2>&1

################## NOSTR Cards (Notes and Other Stuff Transmitted by Relays)
rm "${HOME}/.zen/strfry/amisOfAmis.txt" 2>/dev/null ## RESET Friends of Friends List
${MY_PATH}/RUNTIME/NOSTRCARD.refresh.sh

######################################################### UPLANET ######
########################################################################
## ZEN CARD -- send ZINEs to PARRAINS -- 
${MY_PATH}/RUNTIME/PLAYER.refresh.sh

#####################################
# UPLANET : GeoKeys UMAP / SECTOR / REGION ...
#####################################
${MY_PATH}/RUNTIME/UPLANET.refresh.sh
############### SOCIAL NETWORK + UPLANET SHARING & CARING #########

########################################################################
## REMOVE TMP BUT KEEP swarm, ${IPFSNODEID} and coucou
find "$HOME/.zen/tmp/" -mindepth 1 ! -name "swarm" ! -name "coucou" ! -name "$IPFSNODEID" -delete
## NETTOYAGE tmp.media (disque) : purge finale des médias orphelins de plus de 24h
[[ -d "$HOME/.zen/tmp.media" ]] && find "$HOME/.zen/tmp.media" -mindepth 1 -maxdepth 1 -mtime +1 -exec rm -rf {} + 2>/dev/null || true

########################################################################
################################# updating ipfs bootstrap
# ipfs bootstrap rm --all
for bootnode in $(cat ${STRAPFILE} | grep -Ev "#") # remove comments
do
    ipfsnodeid=${bootnode##*/}
    ipfs bootstrap add $bootnode
done

########################################################################
echo "IPFS DAEMON LEVEL"
######### IPFS DAMEON NOT RUNNING ALL DAY
## IF IPFS DAEMON DISABLED : WAIT 1H & STOP IT
if [[ $LOWMODE != "" ]]; then
    echo "LOW MODE: $LOWMODE - IPFS will run for 1 hour only"
    
    ## Run constellation sync before IPFS shutdown
    if [[ -s ~/.zen/workspace/NIP-101/backfill_constellation.sh ]]; then
        echo "🔄 Running constellation sync (LOW mode)..."
        ~/.zen/workspace/NIP-101/backfill_constellation.sh --days 1 --verbose
        echo "✅ Constellation sync completed"
    else
        echo "⚠️ backfill_constellation.sh not found, skipping constellation sync"
    fi
    
    echo "💤 Sleeping 1 hour before IPFS shutdown..."
    sleep 3600
    
    sudo systemctl stop ipfs
    echo "🛑 IPFS stopped (LOW mode)"
    exit 0
fi

########################################################
### DRAGON WOT : fermeture tunnels AVANT restart IPFS
########################################################
echo "DRAGONS SHIELD OFF - fermeture tunnels P2P avant restart IPFS"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh off

echo "RESTARTING IPFS"
sudo systemctl restart ipfs

################################ attente reconnexion bootstrap (30s suffisent)
sleep 30

########################################################
### DRAGON WOT : réouverture tunnels P2P après bootstrap
########################################################
echo "DRAGONS SHIELD ON - propagation authorized keys + réouverture tunnels P2P"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh
########################################################

## RESTART ASTROPORT
## CLOSING API PORT
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid) > /dev/null 2>&1
## KILL ALL REMAINING nc
killall nc 12345.sh > /dev/null 2>&1

## RESTART UPassport API
sudo systemctl restart upassport
## RESTART Astroport Swarm Balise
sudo systemctl restart astroport
echo "UPassport & Astroport processes systemd restart"


## Wait for _12345.sh to be ready and trigger immediate publication
echo "Waiting for _12345.sh to start..."
for i in {1..30}; do
    if pgrep -au $USER -f '_12345.sh' > /dev/null; then
        echo "_12345.sh is running"
        break
    fi
    sleep 1
done

## Force immediate IPNS publication by triggering a cycle
echo "Triggering immediate IPNS publication of 12345.json..."
sleep 5  # Give time for HTTP server to initialize
curl -s -m 5 "http://127.0.0.1:12345" > /dev/null 2>&1 &
echo "Publication trigger sent"

## ComfyUI need to get restarted to reduce VRAM
[[ -s ~/.zen/tmp/${IPFSNODEID}/x_comfyui.sh ]] && sudo systemctl restart comfyui

## Restart ollama
[[ -s ~/.zen/tmp/${IPFSNODEID}/x_ollama.sh ]] && sudo systemctl restart ollama

#####################################
# Node refreshing
#####################################
${MY_PATH}/RUNTIME/NODE.refresh.sh
#####################################

########################################################################
## ANALYSE FINALE ET RAPPORT - Optimisée avec cache
########################################################################
end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600))
minutes=$(( (dur % 3600) / 60 ))
seconds=$((dur % 60))

# Ajouter un résumé final au log avec analyse finale
echo "
#######################################################################
20H12 EXECUTION TERMINÉE - $(date)
#######################################################################
DURÉE: ${hours}h ${minutes}m ${seconds}s ($dur secondes)
HOSTNAME: $(hostname -f)
IPFS NODE: ${IPFSNODEID}
UPLANET: ${UPLANETG1PUB}
STATUS: SUCCESS
#######################################################################" >> $LOG_FILE

echo "📊 Mise à jour de l'analyse de la ♥️BOX - Captain ${CAPTAINEMAIL}..."

# Utiliser le système de cache optimisé
ANALYSIS_JSON=$(${MY_PATH}/admin/monitor/heartbox_analysis.sh export --json)

if [[ -n "$ANALYSIS_JSON" ]]; then
    # Extraire les capacités depuis l'analyse JSON
    ZENCARD_SLOTS=$(echo "$ANALYSIS_JSON" | jq -r '.capacities.zencard_slots' 2>/dev/null)
    NOSTR_SLOTS=$(echo "$ANALYSIS_JSON" | jq -r '.capacities.nostr_slots' 2>/dev/null)
    AVAILABLE_SPACE_GB=$(echo "$ANALYSIS_JSON" | jq -r '.capacities.available_space_gb' 2>/dev/null)

    # Extraire les statuts des services
    IPFS_ACTIVE=$(echo "$ANALYSIS_JSON" | jq -r '.services.ipfs.active' 2>/dev/null)
    ASTROPORT_ACTIVE=$(echo "$ANALYSIS_JSON" | jq -r '.services.astroport.active' 2>/dev/null)
    NEXTCLOUD_ACTIVE=$(echo "$ANALYSIS_JSON" | jq -r '.services.nextcloud.active' 2>/dev/null)
    STRFRY_ACTIVE=$(echo "$ANALYSIS_JSON" | jq -r '.services.strfry.active' 2>/dev/null)
    UPASSPORT_ACTIVE=$(echo "$ANALYSIS_JSON" | jq -r '.services.upassport.active' 2>/dev/null)
    G1BILLET_ACTIVE=$(echo "$ANALYSIS_JSON" | jq -r '.services.g1billet.active' 2>/dev/null)

    echo "Capacités UPlanet détectées:"
    echo "  ZenCard Slots (128GB/slot): $ZENCARD_SLOTS"
    echo "  NOSTR/MULTIPASS Slots (10GB/slot): $NOSTR_SLOTS"
    echo "  Espace disque disponible (GB): $AVAILABLE_SPACE_GB"

    echo "Statuts des services:"
    echo "  IPFS: $IPFS_ACTIVE"
    echo "  Astroport: $ASTROPORT_ACTIVE"
    echo "  NextCloud: $NEXTCLOUD_ACTIVE"
    echo "  strfry: $STRFRY_ACTIVE"
    echo "  UPassport: $UPASSPORT_ACTIVE"
    echo "  G1Billet: $G1BILLET_ACTIVE"

    # Sauvegarder l'analyse JSON dans le cache
    mkdir -p ~/.zen/tmp/$IPFSNODEID
    ANALYSIS_FILE=~/.zen/tmp/$IPFSNODEID/heartbox_analysis.json
    echo "$ANALYSIS_JSON" > "$ANALYSIS_FILE"
    echo "✅ Analyse JSON sauvegardée dans $ANALYSIS_FILE"

    # Mettre à jour 12345.json avec les données fraîches
    if [[ -f "$HOME/.zen/tmp/${IPFSNODEID}/12345.json" ]]; then
        # Extraire capacities et services de l'analyse fraîche
        capacities=$(echo "$ANALYSIS_JSON" | jq -r '.capacities' 2>/dev/null)
        services=$(echo "$ANALYSIS_JSON" | jq -r '.services' 2>/dev/null)

        # Mettre à jour 12345.json
        jq --argjson capacities "$capacities" --argjson services "$services" \
           '.capacities = $capacities | .services = $services' \
           "$HOME/.zen/tmp/${IPFSNODEID}/12345.json" > "$HOME/.zen/tmp/${IPFSNODEID}/12345.json.tmp" 2>/dev/null

        if [[ $? -eq 0 ]]; then
            mv "$HOME/.zen/tmp/${IPFSNODEID}/12345.json.tmp" "$HOME/.zen/tmp/${IPFSNODEID}/12345.json"
            echo "✅ 12345.json mis à jour avec les données fraîches"
        fi
    fi
else
    echo "❌ Erreur: Impossible d'obtenir les données d'analyse JSON de heartbox_analysis.sh."
    echo "🔄 Tentative de mise à jour du cache..."
    ${MY_PATH}/admin/monitor/heartbox_analysis.sh update
fi

## Rafraîchissement quotidien du cache boots (lu par _12345.sh à chaque cycle)
_BOOTS_CACHE="$HOME/.zen/tmp/station_boots.json"
python3 "${MY_PATH}/tools/station_boots.py" > "${_BOOTS_CACHE}.tmp" 2>/dev/null \
    && mv "${_BOOTS_CACHE}.tmp" "$_BOOTS_CACHE" \
    || echo "⚠️  station_boots.py : échec de rafraîchissement"

end=`date +%s`
dur=`expr $end - $start`
hours=$((dur / 3600))
minutes=$(( (dur % 3600) / 60 ))
seconds=$((dur % 60))

echo "TOTAL DURATION ${hours} hours ${minutes} minutes ${seconds} seconds"
echo "20H12 (♥‿‿♥) Execution time was $dur seconds."

########################################################################
## POWER CONSUMPTION REPORT - Last 24h from 24/7 PowerJoular (powerjoular.service)
########################################################################
POWER_REPORT_HTML="/tmp/20h12_power_report.html"
rm -f "$POWER_REPORT_HTML"

## WATCHDOG powerjoular.service — relance si inactif, réinitialise le CSV si stale
if systemctl is-enabled powerjoular.service &>/dev/null; then
    if ! systemctl is-active --quiet powerjoular.service; then
        echo "⚡ powerjoular.service inactif — réinitialisation CSV + relance..." >> $LOG_FILE
        # Vider le CSV stale avant redémarrage (powerjoular append, pas écrase)
        if sudo test -f "$POWER_24H_CSV" 2>/dev/null; then
            sudo systemctl stop powerjoular.service 2>/dev/null || true
            sudo truncate -s 0 "$POWER_24H_CSV" 2>/dev/null \
                || sudo bash -c "> '$POWER_24H_CSV'" 2>/dev/null || true
            echo "🗑️ CSV réinitialisé : $POWER_24H_CSV" >> $LOG_FILE
        fi
        if sudo systemctl start powerjoular.service 2>&1 | tee -a $LOG_FILE; then
            sleep 5
            if systemctl is-active --quiet powerjoular.service; then
                echo "✅ powerjoular.service relancé avec succès" >> $LOG_FILE
            else
                echo "⚠️ powerjoular.service n'a pas démarré — vérifiez : sudo systemctl status powerjoular" >> $LOG_FILE
            fi
        fi
    else
        echo "✅ powerjoular.service actif" >> $LOG_FILE
    fi
fi

if [[ -f "${MY_PATH}/admin/monitor/power_monitor.sh" ]] && [[ -f "$POWER_24H_CSV" ]] || sudo test -f "$POWER_24H_CSV" 2>/dev/null; then
    echo "📊 Generating power consumption report (last 24h from 24/7 CSV)..."
    if "${MY_PATH}/admin/monitor/power_monitor.sh" report-from-24h \
            "$POWER_REPORT_HTML" \
            "20H12 - $(hostname -f) - Last 24h /ipns/${IPFSNODEID:-} " \
            "$LOG_FILE" \
            "$(hostname -f)" \
            "24h" \
            "${IPFSNODEID:-}" 2>&1 | tee -a $LOG_FILE; then
        if [[ -f "$POWER_REPORT_HTML" ]]; then
            echo "✅ Power consumption report generated: $POWER_REPORT_HTML" >> $LOG_FILE
        fi
        # Trim 24/7 CSV to last 24h only to avoid filling disk
        echo "🗜️ Trimming 24/7 power CSV to last 24h..." >> $LOG_FILE
        "${MY_PATH}/admin/monitor/power_monitor.sh" trim-24h-csv "$POWER_24H_CSV" 2>&1 | tee -a $LOG_FILE || true
        # Vérification post-trim : le trim stoppe/relance powerjoular — s'assurer qu'il tourne toujours
        sleep 3
        if systemctl is-enabled powerjoular.service &>/dev/null && ! systemctl is-active --quiet powerjoular.service; then
            echo "⚠️ powerjoular.service est tombé après le trim — relance de secours..." >> $LOG_FILE
            sudo systemctl start powerjoular.service 2>&1 | tee -a $LOG_FILE || \
                echo "❌ Impossible de relancer powerjoular.service après trim" >> $LOG_FILE
        fi
    else
        echo "⚠️ Power report from 24/7 CSV failed or insufficient data" >> $LOG_FILE
    fi
else
    echo "⚠️ 24/7 PowerJoular CSV not found ($POWER_24H_CSV); is powerjoular.service running?" >> $LOG_FILE
fi

########################################################################
## TUNNEL WATCHDOG — Relance les tunnels P2P persistants tombés
## Les tunnels activés via `astrosystemctl enable` sont dans ~/.zen/tunnels/enabled/
########################################################################
TUNNELS_ENABLED_DIR="$HOME/.zen/tunnels/enabled"
if [[ -d "$TUNNELS_ENABLED_DIR" ]] && [[ -n "$(ls -A "$TUNNELS_ENABLED_DIR" 2>/dev/null)" ]]; then
    echo "🔍 WATCHDOG TUNNELS : vérification des tunnels persistants..."
    for tunnel_wrapper in "$TUNNELS_ENABLED_DIR"/x_*.sh; do
        [[ -f "$tunnel_wrapper" ]] || continue
        # Extraire le nom du service depuis le nom de fichier (x_SERVICE_NODEID.sh)
        svc=$(basename "$tunnel_wrapper" | sed 's/x_//;s/_[^_]*\.sh$//')
        # Vérifier si un tunnel IPFS P2P est actif pour ce service
        if ipfs p2p ls 2>/dev/null | grep -qi "${svc}"; then
            echo "  ✅ Tunnel ${svc} : actif"
        else
            echo "  ⚡ Tunnel ${svc} : tombé — relance..."
            bash "$tunnel_wrapper" >> "$HOME/.zen/tmp/tunnel.log" 2>&1 &
            sleep 2
            if ipfs p2p ls 2>/dev/null | grep -qi "${svc}"; then
                echo "  ✅ Tunnel ${svc} : relancé avec succès"
            else
                echo "  ⚠️  Tunnel ${svc} : relance échouée (vérifiez le nœud distant)"
            fi
        fi
    done
else
    echo "ℹ️  Aucun tunnel persistant configuré (astrosystemctl enable <service>)"
fi

########################################################################
## MIROFISH FEEDER — Alimente le RAG MiroFish si le service est local
## Exécuté seulement si mirofish tourne en local (pas via tunnel P2P/SSH)
########################################################################
HEARTBOX_CACHE="$HOME/.zen/tmp/${IPFSNODEID}/heartbox_analysis.json"
if [[ -s "$HEARTBOX_CACHE" ]]; then
    MIROFISH_SOURCE=$(jq -r '.services.ai_company.mirofish.source // "none"' \
        "$HEARTBOX_CACHE" 2>/dev/null || echo "none")
    if [[ "$MIROFISH_SOURCE" == "local" ]]; then
        echo "🐟 MiroFish local détecté — alimentation du RAG..." >> $LOG_FILE
        bash "${MY_PATH}/IA/feed_mirofish.sh" >> $LOG_FILE 2>&1 || \
            echo "⚠️  feed_mirofish.sh échoué (non bloquant)" >> $LOG_FILE
    else
        echo "ℹ️  MiroFish absent ou distant (source=$MIROFISH_SOURCE) — skip feeder" >> $LOG_FILE
    fi
else
    echo "ℹ️  heartbox_analysis.json absent — skip MiroFish feeder" >> $LOG_FILE
fi

## MAIL LOG : support@qo-op.com ##
# Send email with power consumption report if available (report is written to /tmp/)
POWER_REPORT_HTML="/tmp/20h12_power_report.html"
_STATION="$(hostname -f)"
_PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
_GPS="$(cat ~/.zen/GPS 2>/dev/null)"

if [[ -f "$POWER_REPORT_HTML" ]]; then
    echo "📧 Sending 20H12 report with power consumption analysis..."
    ${MY_PATH}/tools/mailjet.sh --template "$0" --expire 48h "$CAPTAINEMAIL" "$POWER_REPORT_HTML" \
        "20H12 ${_STATION} <${CAPTAINEMAIL}> : ${_PLAYER} (${_GPS}) - Power Consumption Report"
else
    ${MY_PATH}/tools/mailjet.sh --template "$0" --expire 48h "$CAPTAINEMAIL" "$LOG_FILE" \
        "20H12 ${_STATION} <${CAPTAINEMAIL}> : ${_PLAYER} (${_GPS})"
fi

# espeak "TOTAL DURATION ${hours} hours ${minutes} minutes ${seconds} seconds" > /dev/null 2>&1 &

} # end main()
main "$@"
