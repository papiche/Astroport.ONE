#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2025.12.04
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# ASTROPORT MODE CONTROLLER - cron_VRFY.sh
########################################################################
#
# USAGE: cron_VRFY.sh [ON|OFF|LOW]
#
# MODES:
# ------
#   ON (default) - Full Astroport mode
#       - 20h12 cron job: ENABLED
#       - IPFS daemon: ENABLED (24/7)
#       - Astroport API: ENABLED
#       - Constellation sync: Every hour via _12345.sh
#
#   OFF - Complete shutdown
#       - 20h12 cron job: DISABLED
#       - IPFS daemon: DISABLED
#       - Astroport API: DISABLED
#       - Constellation sync: NONE
#
#   LOW - Resource-saving mode (for low disk/bandwidth stations)
#       - 20h12 cron job: ENABLED (runs at solar 20h12)
#       - IPFS daemon: DISABLED (starts only at 20h12, runs 1h, then stops)
#       - Astroport API: DISABLED (not restarted in LOW mode)
#       - Constellation sync: Once per day during 20h12 window
#
# SOLAR TIME CALIBRATION:
# -----------------------
# If ~/.zen/GPS exists with LAT and LON variables, the script calculates
# the legal time corresponding to 20h12 SOLAR time at that location.
#
# Example: For Paris (LAT=48.8566, LON=2.3522), solar 20h12 might be
# legal time 21:04 in summer (UTC+2) or 20:04 in winter (UTC+1).
#
# The solar_time.sh script accounts for:
#   - Longitude offset (4 min per degree from timezone meridian)
#   - Equation of time (±15 min seasonal variation)
#   - Local timezone offset (DST aware)
#
# OUTPUT FORMAT: "MINUTE HOUR" for cron (e.g., "4 21" = 21:04)
#
# MODE TRANSITIONS:
# -----------------
#   Current → Target | Action
#   -----------------+--------------------------------------------------
#   OFF → ON         | Add cron, enable+start IPFS/astroport/g1billet
#   OFF → LOW        | Add cron, IPFS disabled (starts only at 20h12)
#   ON → OFF         | Remove cron, stop+disable all services
#   ON → LOW         | Keep cron, stop+disable IPFS (20h12 will restart it)
#   LOW → ON         | Keep cron, enable+start IPFS (24/7 mode)
#   LOW → OFF        | Remove cron, ensure all services stopped
#
# 20H12.PROCESS.SH BEHAVIOR BY MODE:
# ----------------------------------
#   ON mode:  Full sync, restarts astroport/_12345.sh, IPFS stays on
#   LOW mode: Full sync + constellation backfill, waits 1h, stops IPFS
#   OFF mode: Script not scheduled (no cron entry)
#
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
# SOLAR TIME CALCULATION
########################################################################
# Default: 20:12 legal time (no GPS calibration)
SOLAR20H12="12 20"

# Calibrate to local solar time if GPS coordinates available
if [[ -s ~/.zen/GPS ]]; then
    source ~/.zen/GPS
    echo ".... Calibrating to ~/.zen/GPS SOLAR 20H12"
    echo "     LAT=$LAT LON=$LON"
    
    # solar_time.sh outputs: "MINUTE HOUR" on the last line
    # Example: "4 21" means cron should run at 21:04
    SOLAR20H12=$(${MY_PATH}/solar_time.sh "$LAT" "$LON" 2>/dev/null | tail -n 1)
    
    if [[ -z "$SOLAR20H12" || ! "$SOLAR20H12" =~ ^[0-9]+\ [0-9]+$ ]]; then
        echo "WARNING: solar_time.sh returned invalid format, using default 20:12"
        SOLAR20H12="12 20"
    else
        # Parse for display
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
# Clean temporary files
rm -f /tmp/mycron /tmp/newcron

# Get current crontab
crontab -l > /tmp/mycron 2>/dev/null || touch /tmp/mycron

# Check if 20h12 cron job exists
CRON_EXISTS=$(grep -F '20h12.process.sh' /tmp/mycron)

# Remove environment lines (will be re-added cleanly)
awk -i inplace -v rmv="SHELL=" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="USER=" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="PATH=" '!index($0,rmv)' /tmp/mycron

# Remove any existing 20h12 entry (will be re-added if needed)
grep -v '20h12.process.sh' /tmp/mycron > /tmp/mycron.clean
mv /tmp/mycron.clean /tmp/mycron

########################################################################
# BUILD NEW CRONTAB
########################################################################
build_cron_header() {
    echo "SHELL=/bin/bash" > /tmp/newcron
    echo "USER=$USER" >> /tmp/newcron
    echo "PATH=$HOME/.astro/bin:$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" >> /tmp/newcron
    # Add remaining entries (without 20h12)
    cat /tmp/mycron >> /tmp/newcron
}

add_20h12_cron() {
    echo "${SOLAR20H12}  *  *  *   /bin/bash $MY_PATH/../20h12.process.sh > /tmp/20h12.log 2>&1" >> /tmp/newcron
}

########################################################################
# MODE HANDLING
########################################################################

case "$MODE" in
    "ON")
        echo ""
        echo ">>> ACTIVATING ASTROPORT (ON mode - Full 24/7)"
        echo ""
        
        build_cron_header
        add_20h12_cron
        crontab /tmp/newcron
        
        # Enable and start all services
        sudo systemctl enable ipfs 2>/dev/null
        sudo systemctl enable astroport 2>/dev/null
        sudo systemctl enable g1billet 2>/dev/null
        sudo systemctl start ipfs 2>/dev/null
        sudo systemctl start astroport 2>/dev/null
        sudo systemctl start g1billet 2>/dev/null
        
        echo "✅ ASTROPORT is ON"
        echo "   - 20h12 cron: ENABLED (solar time: $SOLAR20H12)"
        echo "   - IPFS: ENABLED (24/7)"
        echo "   - Astroport API: ENABLED"
        echo "   - Constellation sync: Every hour via _12345.sh"
        ;;
        
    "OFF")
        echo ""
        echo ">>> DEACTIVATING ASTROPORT (OFF mode - Complete shutdown)"
        echo ""
        
        build_cron_header
        # Do NOT add 20h12 cron
        crontab /tmp/newcron
        
        # Stop and disable all services
        sudo systemctl stop astroport 2>/dev/null
        sudo systemctl stop g1billet 2>/dev/null
        sudo systemctl stop ipfs 2>/dev/null
        sudo systemctl disable astroport 2>/dev/null
        sudo systemctl disable g1billet 2>/dev/null
        sudo systemctl disable ipfs 2>/dev/null
        
        echo "🛑 ASTROPORT is OFF"
        echo "   - 20h12 cron: DISABLED"
        echo "   - IPFS: DISABLED"
        echo "   - Astroport API: DISABLED"
        echo "   - Constellation sync: NONE"
        ;;
        
    "LOW")
        echo ""
        echo ">>> ACTIVATING ASTROPORT (LOW mode - Resource saving)"
        echo ""
        
        build_cron_header
        add_20h12_cron
        crontab /tmp/newcron
        
        # Disable IPFS from starting automatically (20h12 will start it)
        sudo systemctl stop ipfs 2>/dev/null
        sudo systemctl disable ipfs 2>/dev/null
        
        # Keep astroport and g1billet disabled in LOW mode
        # (they won't be restarted by 20h12.process.sh in LOW mode)
        sudo systemctl stop astroport 2>/dev/null
        sudo systemctl stop g1billet 2>/dev/null
        
        echo "⚡ ASTROPORT is in LOW mode"
        echo "   - 20h12 cron: ENABLED (solar time: $SOLAR20H12)"
        echo "   - IPFS: DISABLED (starts only at 20h12, runs ~1h)"
        echo "   - Astroport API: DISABLED"
        echo "   - Constellation sync: Once per day during 20h12 window"
        echo ""
        echo "   In LOW mode, 20h12.process.sh will:"
        echo "   1. Start IPFS daemon"
        echo "   2. Run PLAYER/UPLANET sync"
        echo "   3. Run backfill_constellation.sh (NOSTR sync)"
        echo "   4. Wait 1 hour"
        echo "   5. Stop IPFS daemon"
        ;;
        
    "TOGGLE"|*)
        # Toggle based on current state
        if [[ -n "$CRON_EXISTS" ]]; then
            # Cron exists -> turn OFF
            echo "Detected: 20h12 cron is ACTIVE -> Switching to OFF"
            exec "$0" OFF
        else
            # Cron doesn't exist -> turn ON
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
crontab -l 2>/dev/null | grep '20h12' || echo "  (none)"
echo ""
echo "Service status:"
get_service_status() {
    local svc="$1"
    local status
    status=$(systemctl is-active "$svc" 2>/dev/null)
    if [[ -z "$status" ]]; then
        echo "not-installed"
    else
        echo "$status"
    fi
}
echo "  IPFS:      $(get_service_status ipfs)"
echo "  Astroport: $(get_service_status astroport)"
echo "  G1Billet:  $(get_service_status g1billet)"

exit 0
