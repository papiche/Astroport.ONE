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
echo "20H12 (♥‿‿♥) 🌐 /ipns/$IPFSNODEID 🤓 $CAPTAINEMAIL $(hostname -f) $(date)"
# espeak "Ding" > /dev/null 2>&1

########################################################################
## POWER CONSUMPTION - 24/7 PowerJoular (systemd powerjoular.service)
########################################################################
# Report uses last 24h from /var/lib/powerjoular/power_24h.csv (no start/stop in this script)
POWER_24H_CSV="${POWER_24H_CSV:-/var/lib/powerjoular/power_24h.csv}"

########################################################################
## SOLAR TIME CALIBRATION - Recalibrate cron for DST changes
########################################################################
# Check if we need to recalibrate (DST transition detection)
# Compare current UTC offset with last recorded offset
CURRENT_UTC_OFFSET=$(date +%z)
LAST_UTC_OFFSET_FILE="$HOME/.zen/tmp/.last_utc_offset"

if [[ -f "$LAST_UTC_OFFSET_FILE" ]]; then
    LAST_UTC_OFFSET=$(cat "$LAST_UTC_OFFSET_FILE")
    if [[ "$CURRENT_UTC_OFFSET" != "$LAST_UTC_OFFSET" ]]; then
        echo "⏰ DST change detected: $LAST_UTC_OFFSET → $CURRENT_UTC_OFFSET"
        echo "🔄 Recalibrating solar time cron job..."
        
        # Detect current mode (LOW or ON) based on IPFS service status
        if systemctl is-enabled ipfs 2>/dev/null | grep -q "disabled"; then
            echo "   Mode: LOW (IPFS disabled)"
            ${MY_PATH}/tools/cron_VRFY.sh LOW
        else
            echo "   Mode: ON (IPFS enabled)"
            ${MY_PATH}/tools/cron_VRFY.sh ON
        fi
        echo "✅ Solar 20H12 cron recalibrated"
    fi
fi
# Save current UTC offset for next run comparison
echo "$CURRENT_UTC_OFFSET" > "$LAST_UTC_OFFSET_FILE"

echo "PATH=$PATH"

########################################################################
## IPFS DAEMON STATUS
LOWMODE=$(sudo systemctl status ipfs | grep "preset: disabled") ## IPFS DISABLED - START ONLY FOR SYNC -
[[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]] && LOWMODE="NO 5001" ## IPFS IS STOPPED
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
while [[ ! $(netstat -tan | grep 5001 | grep LISTEN) ]]; do
    sleep 10
    ((floop++)) && [ $floop -gt 36 ] \
        && echo "ERROR. IPFS daemon not restarting" \
        && ${MY_PATH}/tools/mailjet.sh "support@qo-op.com" "/tmp/20h12.log" "IPFS RESTART ERROR 20H12" \
        && exit 1
done

#### COPY LOGS - before erase
# cat $HOME/.zen/tmp/MULTIPASS.refresh.log >> /tmp/20h12.log
cat $HOME/.zen/tmp/youtube.com_* >> /tmp/20h12.log
cat $HOME/.zen/tmp/nostr*.log >> /tmp/20h12.log
########################################################################
# show ZONE.sh cache of the day
echo "TODAY UPlanet landings"
# ls ~/.zen/tmp/ZONE_* 2>/dev/null # API v1 deprecated
ls ~/.zen/tmp/Ustats*.json 2>/dev/null # API v2
########################################################################
## REMOVE TMP BUT KEEP swarm, flashmem and coucou
mv ~/.zen/tmp/swarm ~/.zen/swarm
mv ~/.zen/tmp/coucou ~/.zen/coucou
mv ~/.zen/tmp/flashmem ~/.zen/flashmem
rm -Rf ~/.zen/tmp/*
mv ~/.zen/swarm ~/.zen/tmp/swarm
mv ~/.zen/coucou ~/.zen/tmp/coucou
mv ~/.zen/flashmem ~/.zen/tmp/flashmem

## STOPPING ASTROPORT
sudo systemctl stop astroport

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

## RUN OC2UPlanet monthly — recharge MULTIPASS des membres résidents
## Traite les transactions CREDIT du mois en cours via oc2uplanet.sh
## (cotisation cloud-usage + membre-resident → process_locataire)
OC2UP_MARKER="$HOME/.zen/game/.oc2uplanet_monthly.done"
OC2UP_MONTH=$(date +%Y-%m)
OC2UP_LAST=$(cat "$OC2UP_MARKER" 2>/dev/null)
if [[ "$OC2UP_LAST" != "$OC2UP_MONTH" ]]; then
    if [[ -s ~/.zen/workspace/OC2UPlanet/.env && -x ~/.zen/workspace/OC2UPlanet/oc2uplanet.sh ]]; then
        echo "OC2UPlanet: monthly sync for $OC2UP_MONTH"
        (cd ~/.zen/workspace/OC2UPlanet && ./oc2uplanet.sh) \
            && echo "$OC2UP_MONTH" > "$OC2UP_MARKER"
    else
        echo "OC2UPlanet: .env missing or oc2uplanet.sh not executable — skipping"
    fi
fi

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
## ZEN CARD -- send ZINEs seeking for GODFATHERs -- 
${MY_PATH}/RUNTIME/PLAYER.refresh.sh

#####################################
# UPLANET : GeoKeys UMAP / SECTOR / REGION ...
##################################### ORIGIN
${MY_PATH}/RUNTIME/UPLANET.refresh.sh
############### SOCIAL NETWORK + UPLANET SHARING & CARING #########

########################################################################
## REMOVE TMP BUT KEEP swarm, flashmem ${IPFSNODEID} and coucou
mv ~/.zen/tmp/${IPFSNODEID} ~/.zen/${IPFSNODEID}
mv ~/.zen/tmp/swarm ~/.zen/swarm
mv ~/.zen/tmp/coucou ~/.zen/coucou
mv ~/.zen/tmp/flashmem ~/.zen/flashmem
rm -Rf ~/.zen/tmp/*
mv ~/.zen/${IPFSNODEID} ~/.zen/tmp/${IPFSNODEID}
mv ~/.zen/swarm ~/.zen/tmp/swarm
mv ~/.zen/coucou ~/.zen/tmp/coucou
mv ~/.zen/flashmem ~/.zen/tmp/flashmem

########################################################################
################################# updating ipfs bootstrap
ipfs bootstrap rm --all > /dev/null 2>&1
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

echo "HIGH. RESTART IPFS"
sleep 60
sudo systemctl restart ipfs

################################ wait for bootstraping....
sleep 30
########################################################
### DRAGON WOT : SSH IPFS P2P SERVICES OPENING
########################################################
echo "DRAGONS SHIELD OFF"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh off
echo "DRAGONS SHIELD ON"
${MY_PATH}/RUNTIME/DRAGON_p2p_ssh.sh
########################################################

## RESTART ASTROPORT
## CLOSING API PORT
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid) > /dev/null 2>&1
## KILL ALL REMAINING nc
killall nc 12345.sh > /dev/null 2>&1

## SYSTEMD OR NOT SYSTEMD
if [[ ! -f /etc/systemd/system/astroport.service ]]; then
    ${MY_PATH}/12345.sh > ~/.zen/tmp/12345.log &
    PID=$!
    echo $PID > ~/.zen/.pid
else
    sudo systemctl restart astroport
    [[ -s ~/.zen/G1BILLET/G1BILLETS.sh ]] && sudo systemctl restart g1billet
    echo "Astroport processes systemd restart"
fi

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
#######################################################################" >> /tmp/20h12.log

echo "📊 Mise à jour de l'analyse de la ♥️BOX - Captain ${CAPTAINEMAIL}..."

# Utiliser le système de cache optimisé
ANALYSIS_JSON=$(${MY_PATH}/tools/heartbox_analysis.sh export --json)

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
    ${MY_PATH}/tools/heartbox_analysis.sh update
fi

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

if [[ -f "${MY_PATH}/tools/power_monitor.sh" ]] && [[ -f "$POWER_24H_CSV" ]] || sudo test -f "$POWER_24H_CSV" 2>/dev/null; then
    echo "📊 Generating power consumption report (last 24h from 24/7 CSV)..."
    if "${MY_PATH}/tools/power_monitor.sh" report-from-24h \
            "$POWER_REPORT_HTML" \
            "20H12 Power Consumption - Last 24h" \
            "/tmp/20h12.log" \
            "$(hostname -f)" \
            "24h" 2>&1 | tee -a /tmp/20h12.log; then
        if [[ -f "$POWER_REPORT_HTML" ]]; then
            echo "✅ Power consumption report generated: $POWER_REPORT_HTML" >> /tmp/20h12.log
        fi
        # Trim 24/7 CSV to last 24h only to avoid filling disk
        echo "🗜️ Trimming 24/7 power CSV to last 24h..." >> /tmp/20h12.log
        "${MY_PATH}/tools/power_monitor.sh" trim-24h-csv "$POWER_24H_CSV" 2>&1 | tee -a /tmp/20h12.log || true
    else
        echo "⚠️ Power report from 24/7 CSV failed or insufficient data" >> /tmp/20h12.log
    fi
else
    echo "⚠️ 24/7 PowerJoular CSV not found ($POWER_24H_CSV); is powerjoular.service running?" >> /tmp/20h12.log
fi

## MAIL LOG : support@qo-op.com ##
# Send email with power consumption report if available (report is written to /tmp/)
POWER_REPORT_HTML="/tmp/20h12_power_report.html"
if [[ -f "$POWER_REPORT_HTML" ]]; then
    echo "📧 Sending 20H12 report with power consumption analysis..."
    ${MY_PATH}/tools/mailjet.sh --expire 48h "$CAPTAINEMAIL" "$POWER_REPORT_HTML" \
        "20H12 : $(cat ~/.zen/game/players/.current/.player 2>/dev/null) ($(cat ~/.zen/GPS 2>/dev/null)) - Power Consumption Report"
else
    ${MY_PATH}/tools/mailjet.sh --expire 48h "$CAPTAINEMAIL" "/tmp/20h12.log" \
        "20H12 : $(cat ~/.zen/game/players/.current/.player 2>/dev/null) ($(cat ~/.zen/GPS 2>/dev/null))"
fi

# espeak "TOTAL DURATION ${hours} hours ${minutes} minutes ${seconds} seconds" > /dev/null 2>&1 &

exit 0
