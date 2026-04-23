#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2025.12.04 (Updated with Picoport/SoundSpot autodetection)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# ASTROPORT MODE CONTROLLER - cron_VRFY.sh
########################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

echo '
########################################################################
# \\///
# qo-op
############# '$MY_PATH/$ME' '$1'
########################################################################
# Activate / Desactivate ASTROPORT 20h12.process.sh job & IPFS daemon
########################################################################'

# Normalize argument to uppercase
MODE=$(echo "$1" | tr '[:lower:]' '[:upper:]')
[[ -z "$MODE" ]] && MODE="TOGGLE"  # Default: toggle current state

########################################################################
# AUTODETECTION ASTROPORT CLASSIQUE vs PICOPORT (SoundSpot)
########################################################################
if [[ -f "/opt/soundspot/picoport/picoport_20h12.sh" ]]; then
    IS_PICOPORT=1
    CRON_JOB_NAME="picoport_20h12.sh"
    CRON_JOB_CMD="/bin/bash /opt/soundspot/picoport/picoport_20h12.sh"
    CRON_LOG_FILE="${HOME}/.zen/log/picoport_20h12.log"
    
    SVC_MAIN="picoport"
    SVC_SYNC="soundspot-swarm-sync"
    SVC_RELAY="" # strfry est déporté sur l'essaim pour les Pi Zero
    echo ".... 🌿 PICOPORT (SoundSpot) installation detected"
else
    IS_PICOPORT=0
    CRON_JOB_NAME="20h12.process.sh"
    CRON_JOB_CMD="/bin/bash $MY_PATH/../20h12.process.sh"
    CRON_LOG_FILE="${HOME}/.zen/log/20h12.log"
    
    SVC_MAIN="astroport"
    SVC_SYNC=""
    SVC_RELAY="strfry"
fi

########################################################################
# SOLAR TIME CALCULATION
########################################################################
SOLAR20H12="12 20"

if [[ -s ~/.zen/GPS ]]; then
    source ~/.zen/GPS
    echo ".... Calibrating to ~/.zen/GPS SOLAR 20H12"
    echo "     LAT=$LAT LON=$LON"
    
    SOLAR20H12=$(${MY_PATH}/solar_time.sh "$LAT" "$LON" 2>/dev/null | tail -n 1)
    
    if [[ -z "$SOLAR20H12" || ! "$SOLAR20H12" =~ ^[0-9]+\ [0-9]+$ ]]; then
        echo "WARNING: solar_time.sh returned invalid format, using default 20:12"
        SOLAR20H12="12 20"
    else
        CRON_MIN=$(echo "$SOLAR20H12" | awk '{print $1}')
        CRON_HOUR=$(echo "$SOLAR20H12" | awk '{print $2}')
        echo "     Solar 20h12 = Legal time $(printf "%02d:%02d" "$CRON_HOUR" "$CRON_MIN")"
    fi
else
    echo ".... No ~/.zen/GPS found, using default legal time 20:12"
fi

########################################################################
# CRONTAB MANAGEMENT
########################################################################
rm -f /tmp/mycron /tmp/newcron
crontab -l > /tmp/mycron 2>/dev/null || touch /tmp/mycron

CRON_EXISTS=$(grep -F "$CRON_JOB_NAME" /tmp/mycron)

awk -i inplace -v rmv="SHELL=" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="USER=" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="PATH=" '!index($0,rmv)' /tmp/mycron

grep -v "$CRON_JOB_NAME" /tmp/mycron > /tmp/mycron.clean
mv /tmp/mycron.clean /tmp/mycron

build_cron_header() {
    echo "SHELL=/bin/bash" > /tmp/newcron
    echo "USER=$USER" >> /tmp/newcron
    echo "PATH=$HOME/.astro/bin:$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> /tmp/newcron
    cat /tmp/mycron >> /tmp/newcron
}

add_20h12_cron() {
    echo "${SOLAR20H12}  *  *  *   $CRON_JOB_CMD >> ${CRON_LOG_FILE} 2>&1" >> /tmp/newcron
}

manage_service() {
    local action="$1"
    local svc="$2"
    if [[ -n "$svc" ]]; then
        if [[ "$action" == "start" ]]; then
            sudo systemctl enable "$svc" 2>/dev/null
            sudo systemctl restart "$svc" 2>/dev/null
        elif [[ "$action" == "stop" ]]; then
            sudo systemctl stop "$svc" 2>/dev/null
            sudo systemctl disable "$svc" 2>/dev/null
        fi
    fi
}

########################################################################
# MODE HANDLING
########################################################################

case "$MODE" in
    "ON")
        echo ""
        echo ">>> ACTIVATING SYSTEM (ON mode - Full 24/7)"
        echo ""
        
        build_cron_header
        add_20h12_cron
        crontab /tmp/newcron
        
        manage_service start ipfs
        manage_service start "$SVC_RELAY"
        manage_service start "$SVC_MAIN"
        manage_service start "$SVC_SYNC"
        manage_service start upassport

        if [[ "$IS_PICOPORT" == 0 ]]; then
            echo "📡 Déclenchement de la synchronisation constellation..."
            (
                sleep 15
                bash "$MY_PATH/../bootstrap_constellation.sh" > ~/.zen/tmp/coucou/bootstrap_on_start.log 2>&1
            ) &
        fi

        echo "✅ SYSTEM is ON"
        echo "   - 20h12 cron: ENABLED (solar time: $SOLAR20H12)"
        echo "   - IPFS: ENABLED (24/7)"
        echo "   - Core API ($SVC_MAIN): ENABLED"
        ;;
        
    "OFF")
        echo ""
        echo ">>> DEACTIVATING SYSTEM (OFF mode - Complete shutdown)"
        echo ""
        
        build_cron_header
        crontab /tmp/newcron
        
        manage_service stop "$SVC_RELAY"
        manage_service stop upassport
        manage_service stop "$SVC_MAIN"
        manage_service stop "$SVC_SYNC"
        manage_service stop ipfs
        
        echo "🛑 SYSTEM is OFF"
        ;;
        
    "LOW")
        echo ""
        echo ">>> ACTIVATING SYSTEM (LOW mode - Resource saving)"
        echo ""
        
        build_cron_header
        add_20h12_cron
        crontab /tmp/newcron
        
        manage_service start "$SVC_RELAY"
        manage_service stop upassport
        manage_service stop "$SVC_MAIN"
        manage_service stop "$SVC_SYNC"
        manage_service stop ipfs
        
        echo "⚡ SYSTEM is in LOW mode"
        echo "   - 20h12 cron: ENABLED (solar time: $SOLAR20H12)"
        echo "   - IPFS & Core ($SVC_MAIN): DISABLED (starts only at 20h12, runs ~1h)"
        ;;
        
    "HELP"|"-H"|"--HELP")
        cat <<EOF

USAGE: $ME [ON|OFF|LOW|RESTART|TOGGLE|HELP]

MODES:
  ON       - Mode complet 24/7
  OFF      - Arrêt complet
  LOW      - Mode économique (IPFS et Core coupés en dehors de 20h12)
  RESTART  - Redémarre selon le mode courant (auto-détecté)
  TOGGLE   - Bascule ON↔OFF
  HELP     - Affiche ce message

  Environnement détecté : $([[ $IS_PICOPORT == 1 ]] && echo "🌿 Picoport/SoundSpot" || echo "🚀 Astroport Classique")
  Cron 20h12 actuelle :
EOF
        crontab -l 2>/dev/null | grep "$CRON_JOB_NAME" | sed 's/^/    /' || echo "    (aucune entrée 20h12)"
        echo ""
        echo "  Services :"
        for svc in ipfs "$SVC_MAIN" "$SVC_SYNC" "$SVC_RELAY" upassport; do
            [[ -z "$svc" ]] && continue
            printf "    %-20s %s (enabled: %s)\n" "$svc" \
                "$(systemctl is-active "$svc" 2>/dev/null || echo 'n/a')" \
                "$(systemctl is-enabled "$svc" 2>/dev/null || echo 'n/a')"
        done
        echo ""
        exit 0
        ;;

    "RECALIBRATE")
        if [[ -n "$CRON_EXISTS" ]]; then
            build_cron_header
            add_20h12_cron
            crontab /tmp/newcron
            echo "🔄 Heure solaire recalibrée : $SOLAR20H12"
            echo "   ($(printf "%02d:%02d" $(echo $SOLAR20H12 | awk '{print $2}') $(echo $SOLAR20H12 | awk '{print $1}')) heure légale)"
        else
            echo "⚠️  Aucune cron 20h12 active — recalibration ignorée (utiliser ON ou LOW)"
        fi
        ;;

    "RESTART")
        if [[ -n "$CRON_EXISTS" ]]; then
            IPFS_ENABLED=$(systemctl is-enabled ipfs 2>/dev/null)
            [[ "$IPFS_ENABLED" == "enabled" ]] && DETECTED="ON" || DETECTED="LOW"
        else
            DETECTED="OFF"
        fi
        echo "Mode détecté : $DETECTED  -> relance avec cron_VRFY.sh $DETECTED"
        exec "$0" "$DETECTED"
        ;;

    "TOGGLE"|*)
        if [[ -n "$CRON_EXISTS" ]]; then
            echo "Detected: 20h12 cron is ACTIVE -> Switching to OFF"
            exec "$0" OFF
        else
            echo "Detected: 20h12 cron is INACTIVE -> Switching to ON"
            exec "$0" ON
        fi
        ;;
esac

########################################################################
# DISPLAY CURRENT STATUS
########################################################################
echo ""
echo "Current crontab 20h12 entry:"
crontab -l 2>/dev/null | grep "$CRON_JOB_NAME" || echo "  (none)"
echo ""
echo "Service status:"
get_service_status() {
    local svc="$1"
    [[ -z "$svc" ]] && return
    local status
    status=$(systemctl is-active "$svc" 2>/dev/null)
    if [[ -z "$status" ]]; then
        echo "not-installed"
    else
        echo "$status"
    fi
}

echo "  IPFS:       $(get_service_status ipfs)"
echo "  Core ($SVC_MAIN): $(get_service_status "$SVC_MAIN")"
[[ -n "$SVC_SYNC" ]]  && echo "  Swarm Sync: $(get_service_status "$SVC_SYNC")"
[[ -n "$SVC_RELAY" ]] && echo "  Relay ($SVC_RELAY): $(get_service_status "$SVC_RELAY")"
echo "  UPassport:  $(get_service_status upassport)"

exit 0