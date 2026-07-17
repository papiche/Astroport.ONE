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
## LOGS PERMANENTS dans ~/.zen/log/ - Rotation : compression >2j, purge >30j
########################################################################
LOG_DIR="$HOME/.zen/log"
mkdir -p "$LOG_DIR"
find "$LOG_DIR" -name "20h12_*.log" -mtime +2 -exec gzip -f {} \; 2>/dev/null || true
find "$LOG_DIR" -name "20h12_*.log.gz" -mtime +30 -delete 2>/dev/null || true
## Rotation défensive du log brut cron (sortie écrite avant que ce script
## ne source my.sh / ne redirige vers le log daté ci-dessous, ex: erreur de PATH)
_RAW_CRON_LOG="$LOG_DIR/20h12.log"
if [[ -f "$_RAW_CRON_LOG" ]] && [[ $(stat -c%s "$_RAW_CRON_LOG" 2>/dev/null || echo 0) -gt 2000000 ]]; then
    tail -n 200 "$_RAW_CRON_LOG" > "${_RAW_CRON_LOG}.tmp" && mv "${_RAW_CRON_LOG}.tmp" "$_RAW_CRON_LOG"
fi
LOG_FILE="$LOG_DIR/20h12_$(date +%Y%m%d).log"

## Anti-doublon : le cron horaire fixe (heure solaire) ET le rattrapage @reboot
## (cron_VRFY.sh) peuvent tous deux déclencher ce script le même jour, par exemple
## si la machine était éteinte à l'heure solaire calculée puis redémarrée plus tard.
## On ne relance pas une exécution déjà terminée avec succès aujourd'hui.
if [[ "$1" != "--force" ]] && grep -q "EXECUTION TERMINÉE" "$LOG_FILE" 2>/dev/null; then
    echo "$(date) - 20H12 déjà exécuté avec succès aujourd'hui ($LOG_FILE) - skip (--force pour forcer)"
    exit 0
fi

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
## IPFS DAEMON STATUS - calculé APRES la boucle d'attente ci-dessus : à ce
## stade le port 5001 est garanti UP (sinon le script a déjà quitté plus haut).
## Calculer LOWMODE avant cette boucle créait un faux positif "NO 5001" lors
## d'un simple redémarrage IPFS en cours, ce qui faisait sortir le script en
## LOW MODE (cf. plus bas) AVANT l'envoi du mail de rapport quotidien.
LOWMODE=$(sudo systemctl status ipfs | grep "preset: disabled") ## IPFS DISABLED - START ONLY FOR SYNC -
! ss -tln 2>/dev/null | grep -q ':5001 ' && LOWMODE="NO 5001" ## IPFS IS STOPPED (ne devrait plus arriver ici)
[[ ! $isLAN || ${zipit} != "" ]] && LOWMODE="" ## LOWMODE ONLY FOR LAN STATION


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
            # Chercher le script dans admin/, tools/ ou racine du repo
            _found=$(find "${MY_PATH}/admin" "${MY_PATH}/tools" \
                -maxdepth 3 \( -name "$_name" -o -name "${_name%.sh}.sh" \) 2>/dev/null \
                | head -1)
            [[ -z "$_found" ]] && _found=$(find "${MY_PATH}" \
                -maxdepth 1 \( -name "$_name" -o -name "${_name%.sh}.sh" \) 2>/dev/null \
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
} > "$ASTRO_PROFILE"

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

########################################################################
## NODE OBSERVABILITY DIGEST (24H) — résumé structuré JSONL, cf. bro_log_event()
## dans IA/bro/bro_common_lib.sh (~/.zen/tmp/$IPFSNODEID/observability/
## node-activity.jsonl). Vient EN PLUS des dumps texte libre ci-dessous
## (IA.log, bro_dm_daemon.log) — ne les remplace pas, les rend juste lisibles
## d'un coup d'œil dans l'email quotidien (comptage par script/catégorie/succès)
## au lieu de forcer le capitaine à parcourir 300 lignes de texte libre.
########################################################################
echo "=== NODE OBSERVABILITY DIGEST (24H) ==========================" >> $LOG_FILE
python3 - "$HOME/.zen/tmp/${IPFSNODEID}/observability/node-activity.jsonl" 24 <<'PYEOF' >> "$LOG_FILE" 2>/dev/null
import sys, json, time

path, hours = sys.argv[1], float(sys.argv[2])
cutoff = time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(time.time() - hours * 3600))

try:
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
except FileNotFoundError:
    print("(aucun évènement structuré — observabilité NODE pas encore active sur ce composant)")
    sys.exit(0)

counts = {}
total = 0
for line in lines:
    try:
        e = json.loads(line)
    except Exception:
        continue
    if e.get("timestamp", "") < cutoff:
        continue
    key = (e.get("script", "?"), e.get("category", ""), bool(e.get("success")))
    counts[key] = counts.get(key, 0) + 1
    total += 1

if total == 0:
    print("(aucun évènement dans les dernières 24h)")
else:
    for (script, category, ok), n in sorted(counts.items(), key=lambda kv: -kv[1]):
        label = f"{script}/{category}" if category else script
        print(f"- {label} : {n}x ({'ok' if ok else 'echec'})")
PYEOF

########################################################################
## BRO OBSERVABILITY DIGEST (24H) — pendant PAR UTILISATEUR du digest NODE
## ci-dessus, cf. IA/observability.py::log_event (~/.zen/flashmem/<email>/
## observability/activity.jsonl, câblé dans IA/bro_watch_core.py : dispatch
## d'outils, réponses conversationnelles, alertes proactives). Glob direct
## sous flashmem/ : seuls les comptes ayant eu une activité BRO possèdent un
## sous-répertoire observability/, pas besoin de croiser avec game/nostr/.
########################################################################
echo "=== BRO OBSERVABILITY DIGEST (24H) ===========================" >> $LOG_FILE
python3 - 24 <<'PYEOF' >> "$LOG_FILE" 2>/dev/null
import sys, os, glob, json, time

hours = float(sys.argv[1])
cutoff = time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(time.time() - hours * 3600))

paths = glob.glob(os.path.expanduser("~/.zen/flashmem/*/observability/activity.jsonl"))
counts = {}
active_users = set()
total = 0
for path in paths:
    email = path.split(os.sep + "flashmem" + os.sep, 1)[-1].split(os.sep, 1)[0]
    try:
        with open(path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except Exception:
        continue
    for line in lines:
        try:
            e = json.loads(line)
        except Exception:
            continue
        if e.get("timestamp", "") < cutoff:
            continue
        active_users.add(email)
        key = (e.get("tool", "?"), bool(e.get("success")))
        counts[key] = counts.get(key, 0) + 1
        total += 1

if total == 0:
    print("(aucune activité BRO dans les dernières 24h)")
else:
    print(f"{len(active_users)} compte(s) BRO actif(s)")
    for (tool, ok), n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print(f"- {tool} : {n}x ({'reussi' if ok else 'echec'})")
PYEOF

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

## UPDATE zelkova (Ẑelkova — wallet ẐEN MULTIPASS)
## APK téléchargé depuis GitHub Releases, servi par UPassport sur /zelkova-apk/zelkova.apk
ZELKOVA_APK_DIR="$HOME/.zen/workspace/zelkova"
ZELKOVA_APK="$ZELKOVA_APK_DIR/zelkova.apk"
ZELKOVA_VERSION_FILE="$ZELKOVA_APK_DIR/.version"
mkdir -p "$ZELKOVA_APK_DIR"

ZELKOVA_LATEST=$(curl -fsSL "https://api.github.com/repos/papiche/zelkova/releases/latest" 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tag_name',''))" 2>/dev/null || echo "")
ZELKOVA_CURRENT=$(cat "$ZELKOVA_VERSION_FILE" 2>/dev/null || echo "none")

if [[ -n "$ZELKOVA_LATEST" && ( "$ZELKOVA_CURRENT" != "$ZELKOVA_LATEST" || ! -f "$ZELKOVA_APK" ) ]]; then
    echo "📱 zelkova : nouvelle version $ZELKOVA_LATEST — téléchargement APK..."
    ZELKOVA_APK_URL="https://github.com/papiche/zelkova/releases/download/${ZELKOVA_LATEST}/zelkova-production-release.apk"
    if curl -fsSL --max-time 300 -o "${ZELKOVA_APK}.tmp" "$ZELKOVA_APK_URL"; then
        mv "${ZELKOVA_APK}.tmp" "$ZELKOVA_APK"
        echo "$ZELKOVA_LATEST" > "$ZELKOVA_VERSION_FILE"
        echo "📱 zelkova APK $ZELKOVA_LATEST téléchargé : $ZELKOVA_APK"
    else
        rm -f "${ZELKOVA_APK}.tmp"
        echo "⚠️  zelkova : échec téléchargement depuis $ZELKOVA_APK_URL"
    fi
elif [[ -z "$ZELKOVA_LATEST" ]]; then
    echo "📱 zelkova : pas de release GitHub disponible — skip"
else
    echo "📱 zelkova à jour ($ZELKOVA_LATEST)"
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

## Nettoyage atom4love_certified.txt — supprime les entrées > 180 jours
_a4l_cert="${HOME}/.zen/strfry/atom4love_certified.txt"
if [[ -f "$_a4l_cert" ]]; then
    _a4l_cutoff=$(( $(date +%s) - 180*86400 ))
    awk -F: -v cut="$_a4l_cutoff" 'NF>=2 && $2+0 >= cut' "$_a4l_cert" > "${_a4l_cert}.tmp" \
        && mv "${_a4l_cert}.tmp" "$_a4l_cert"
    echo "[20h12] atom4love_certified.txt : $(wc -l < "$_a4l_cert") pubkeys actifs"
fi

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

    ## Envoi du rapport quotidien AVANT extinction d'IPFS : la section de
    ## reporting complète (power report, mailjet) se trouve après ce bloc,
    ## qui se termine par exit 0 avant de jamais l'atteindre. Sans cela les
    ## stations LOW/LAN ne recevaient jamais le mail 20H12.
    _STATION="$(hostname -f)"
    ${MY_PATH}/tools/mailjet.sh --template "$0" --expire 48h "$CAPTAINEMAIL" "$LOG_FILE" \
        "20H12 ${_STATION} <${CAPTAINEMAIL}> (LOW mode)"

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
    ## Le log complet du jour peut peser plusieurs centaines de Ko sur une
    ## journée bruyante (retries P2P, backfill constellation...). Embarqué tel
    ## quel dans le rapport HTML à côté du graphique en base64, il fait souvent
    ## dépasser la limite de sécurité 1 Mo de mailjet.sh, qui bascule alors
    ## silencieusement sur un email "lien seul" SANS graphique ni mise en forme.
    ## On n'embarque donc qu'un extrait (dernières ~100 Ko) dans le rapport.
    _POWER_REPORT_LOG_TAIL="/tmp/20h12_power_report_log_tail.txt"
    tail -c 100000 "$LOG_FILE" > "$_POWER_REPORT_LOG_TAIL" 2>/dev/null || cp "$LOG_FILE" "$_POWER_REPORT_LOG_TAIL"
    ## Publication du log complet du jour sur IPFS : le rapport n'embarque
    ## qu'un extrait (cf. ci-dessus), ce lien permet de consulter le log en
    ## entier. Note : les toutes dernières lignes (ce bloc + la suite du
    ## script) ne peuvent pas être incluses, le CID devant être calculé avant.
    _LOG_FULL_CID=$(timeout 15s ipfs add -q --pin=false "$LOG_FILE" 2>/dev/null)
    _LOG_FULL_URL=""
    [[ -n "$_LOG_FULL_CID" ]] && _LOG_FULL_URL="${myLIBRA}/ipfs/${_LOG_FULL_CID}"
    if "${MY_PATH}/admin/monitor/power_monitor.sh" report-from-24h \
            "$POWER_REPORT_HTML" \
            "20H12 - $(hostname -f) - Last 24h /ipns/${IPFSNODEID:-} " \
            "$_POWER_REPORT_LOG_TAIL" \
            "$(hostname -f)" \
            "24h" \
            "${IPFSNODEID:-}" \
            "${_LOG_FULL_URL}" 2>&1 | tee -a $LOG_FILE; then
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
    rm -f "$_POWER_REPORT_LOG_TAIL"
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
## CODEBASE INDEX — Rafraîchissement incrémental Qdrant (collection codebase)
########################################################################
CODEBASE_IDX="${MY_PATH}/admin/ia_db/codebase_index.sh"
if [[ -x "$CODEBASE_IDX" ]] && curl -sf --max-time 2 "http://127.0.0.1:6333/healthz" &>/dev/null; then
    echo "🧠 Rafraîchissement incrémental codebase → Qdrant..."
    bash "$CODEBASE_IDX" --incremental >> "$LOG_FILE" 2>&1 \
        && echo "✅ codebase_index --incremental OK" \
        || echo "⚠️  codebase_index --incremental échoué (non bloquant)"
else
    echo "ℹ️  Qdrant absent ou codebase_index.sh introuvable — skip codebase index"
fi

########################################################################
## BRO ARBOR — Détection continue de besoins Web2 récurrents (tous comptes)
## N'écrit ni ne génère aucun code : signale au capitaine par DM NODE les
## patterns de demandes non satisfaites par BRO (voir arbor_self_improve.py).
########################################################################
ARBOR_MINER="${MY_PATH}/IA/arbor_self_improve.py"
if [[ -f "$ARBOR_MINER" ]]; then
    echo "🔍 BRO Arbor : analyse des besoins récurrents (tous comptes)..."
    python3 "$ARBOR_MINER" --mine-requests --notify-captain >> "$LOG_FILE" 2>&1 \
        && echo "✅ arbor_self_improve --mine-requests OK" \
        || echo "⚠️  arbor_self_improve --mine-requests échoué (non bloquant)"
else
    echo "ℹ️  arbor_self_improve.py introuvable — skip mining BRO"
fi

########################################################################
## BRO PROACTIF — balayage quotidien de tous les comptes locaux.
## check_proactive_alerts() (goal_drift, low_g1_balance) et
## _resume_pending_algorithm_plan() ne se déclenchent normalement qu'en
## réaction à un message reçu (fin de process_incoming_commands, appelé par
## bro_dm_daemon.sh) — un compte qui ne reparle jamais à BRO ne verrait donc
## jamais ses alertes proactives ni la reprise d'un plan ALGORITHM interrompu.
## Ce balayage réutilise EXACTEMENT le même chemin (check-commands), sans
## nouvelle logique : traiter 0 nouvelle commande puis vérifier
## alertes/plans est déjà le comportement normal de cette fonction.
########################################################################
BRO_WATCH_CORE="${MY_PATH}/IA/bro_watch_core.py"
BRO_CHECK_LOCKS_DIR="$HOME/.zen/tmp/bro_check_commands_locks"
if [[ -x "$BRO_WATCH_CORE" || -f "$BRO_WATCH_CORE" ]]; then
    echo "🔔 BRO proactif : balayage quotidien alertes/plans (tous comptes)..."
    mkdir -p "$BRO_CHECK_LOCKS_DIR"
    for _bro_account_dir in "$HOME"/.zen/game/nostr/*@*; do
        [[ -d "$_bro_account_dir" ]] || continue
        _bro_email="$(basename "$_bro_account_dir")"
        # Même verrou que bro_dm_daemon.sh::_check_commands_locked — évite une
        # exécution concurrente si le daemon temps réel traite ce compte au
        # même moment (deux appels LLM / deux réponses pour la même fenêtre).
        (
            flock -n 9 || { echo "ℹ️  check-commands déjà en cours pour ${_bro_email} — passe son tour"; exit 0; }
            timeout 60 python3 "$BRO_WATCH_CORE" check-commands "$_bro_email" >> "$LOG_FILE" 2>&1
        ) 9>"$BRO_CHECK_LOCKS_DIR/$(echo -n "$_bro_email" | md5sum | cut -d' ' -f1).lock" \
            || echo "⚠️  check-commands échoué pour ${_bro_email} (non bloquant)"
    done
    echo "✅ Balayage proactif BRO terminé"
else
    echo "ℹ️  bro_watch_core.py introuvable — skip balayage proactif BRO"
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
