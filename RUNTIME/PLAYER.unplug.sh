#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS] INDEX PLAYER [ONE] [SHOUT]"
    echo ""
    echo "Unplug a player from Astroport.ONE station"
    echo ""
    echo "Arguments:"
    echo "  INDEX     Path to player's TW index.html file"
    echo "  PLAYER    Player email address"
    echo "  ONE       Transfer amount: 'ALL' (default) or 'ONE' (1 G1)"
    echo "  SHOUT     Reason for unplugging (optional)"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Description:"
    echo "  This script unplugs a player from the Astroport.ONE station."
    echo "  It removes IPNS keys, cleans up local cache, and optionally"
    echo "  transfers excess G1 balance to UPLANETNAME_G1 central bank."
    echo ""
    echo "  ZEN Card Preservation:"
    echo "  - ZEN Card is preserved for capital shares transit via UPLANET.official.sh"
    echo "  - Keeps minimum 1 G1 for capital shares management"
    echo "  - Only transfers excess balance (balance - 1 G1)"
    echo ""
    echo "Examples:"
    echo "  $0 ~/.zen/game/players/user@example.com/ipfs/moa/index.html user@example.com"
    echo "  $0 ~/.zen/game/players/user@example.com/ipfs/moa/index.html user@example.com ALL 'Migration'"
    echo "  $0 ~/.zen/game/players/user@example.com/ipfs/moa/index.html user@example.com ONE 'Quick exit'"
    echo ""
    exit 0
}

# Check for help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

################################################################################
## UNPLUG A PLAYER FROM ASTROPORT STATION
############################################
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

INDEX="$1"
[[ ! -s ${INDEX} ]] && echo "INDEX ${INDEX} NOT FOUND - EXIT -" && exit 1

PLAYER="$2"
[[ ! -s ~/.zen/game/players/${PLAYER}/secret.dunikey ]] && echo "PLAYER ${PLAYER} NOT FOUND - EXIT -" && exit 1

ONE="$3"

## EXPLAIN WHY !
SHOUT="$4"


MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

## PLAYER UMAP ?
## GET "GPS" TIDDLER
tiddlywiki --load ${INDEX} \
    --output ~/.zen/tmp/${MOATS} \
    --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'  ## GPS Tiddler
TWMAPNS=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].umap)
LAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lat)
            [[ $LAT == "null" || $LAT == "" ]] && LAT="0.00"
LON=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lon)
            [[ $LON == "null" || $LON == "" ]] && LON="0.00"
echo "LAT=${LAT}; LON=${LON}; UMAPNS=${TWMAPNS}"
rm ~/.zen/tmp/${MOATS}/GPS.json

########## SEND COINS TO UPLANETNAME_G1 - ẐEN CENTRAL BANK ;)
LAT=$(makecoord $LAT)
LON=$(makecoord $LON)
##############################################################
## POPULATE UMAP IPNS & G1PUB
$($MY_PATH/../tools/getUMAP_ENV.sh ${LAT} ${LON} | tail -n 1)

## GET COINS
COINS=$($MY_PATH/../tools/G1check.sh ${UPLANETNAME_G1} | tail -n 1)
echo "SECTOR WALLET = ${COINS} G1 : ${UPLANETNAME_G1}"

## ZEN CARD PRESERVATION FOR CAPITAL SHARES TRANSIT
## The ZEN Card is used to transit capital shares acquired via UPLANET.official.sh
## It should NOT be emptied during unplug - only transfer excess G1 if needed

ALL="ALL"
[[ $ONE == "ONE" ]] && ALL=1

YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})


## REMOVING PLAYER from ASTROPORT
ipfs key rm "${PLAYER}" "${PLAYER}_feed" "${G1PUB}"
for vk in $(ls -d ~/.zen/game/players/${PLAYER}/voeux/*/* 2>/dev/null | rev | cut -d / -f 1 | rev); do
    echo "removing wish ${vk}"
    [[ ${vk} != "" ]] && ipfs key rm ${vk}
done

## SEND CAPTAINEMAIL PLAYER UNPLUG NOTIFICATION
TW=$(ipfs add -Hq ${INDEX} | tail -n 1)

# Create professional unplug notification email
UNPLUG_EMAIL=$(mktemp)
cat > "$UNPLUG_EMAIL" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Player Unplugged from Astroport.ONE</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px 10px 0 0; margin: -20px -20px 20px -20px; }
        .content { padding: 20px 0; }
        .info-box { background: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin: 15px 0; border-radius: 4px; }
        .warning-box { background: #fff3e0; border-left: 4px solid #ff9800; padding: 15px; margin: 15px 0; border-radius: 4px; }
        .success-box { background: #e8f5e8; border-left: 4px solid #4caf50; padding: 15px; margin: 15px 0; border-radius: 4px; }
        .code { background: #f5f5f5; padding: 10px; border-radius: 4px; font-family: monospace; margin: 10px 0; }
        .button { display: inline-block; background: #2196f3; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; margin: 10px 5px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; color: #666; font-size: 12px; }
        h1 { margin: 0; }
        h2 { color: #333; margin-top: 25px; }
        .highlight { background: #fff3cd; padding: 2px 4px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Player Unplugged from Astroport.ONE</h1>
            <p>Station: <strong>${IPFSNODEID:0:8}...</strong> | Date: $(date '+%Y-%m-%d %H:%M:%S UTC')</p>
        </div>
        
        <div class="content">
            <div class="info-box">
                <h2>📋 Player Information</h2>
                <p><strong>Player Email:</strong> ${PLAYER}</p>
                <p><strong>Reason:</strong> ${SHOUT:-"Standard unplug"}</p>
                <p><strong>GPS Location:</strong> ${LAT}, ${LON}</p>
            </div>
            
            <div class="success-box">
                <h2>✅ Unplug Operations Completed</h2>
                <ul>
                    <li>IPNS keys removed from station</li>
                    <li>Player directory cleaned up</li>
                    <li>Node cache cleared</li>
                </ul>
            </div>
            
            <div class="info-box">
                <h2>📦 TimeWarp Backup</h2>
                <p>The player's TW has been backed up to IPFS:</p>
                <div class="code">
                    IPFS CID: <strong>${TW}</strong><br>
                    Access: <a href="${myIPFS}/ipfs/${TW}" target="_blank">${myIPFS}/ipfs/${TW}</a>
                </div>
            </div>
            
            <div class="warning-box">
                <h2>⚠️ Important Notes</h2>
                <ul>
                    <li>Player can reconnect to any Astroport.ONE station</li>
                    <li>TimeWarp backup contains all player data</li>
                    <li>Player may need to recreate ZEN Card on new station</li>
                </ul>
            </div>
            
            <div class="info-box">
                <h2>🔑 ZEN Card Address</h2>
                <div class="code">
                    $(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null || echo "No ZEN Card wallet address found")
                </div>
                <p><small>This address contains ZEN Card capital owning history received from $UPLANETNAME_SOCIETY</small></p>
            </div>
            
            <h2>🛠️ Captain Actions</h2>
            <p>As the station captain, you may want to:</p>
            <ul>
                <li>Verify the unplug was intentional</li>
                <li>Check if player needs assistance with migration</li>
                <li>Monitor station resources after player departure</li>
            </ul>
            
            <div style="text-align: center; margin: 30px 0;">
                <a href="${myIPFS}/ipfs/${TW}" class="button" target="_blank">📱 View Player TimeWarp</a>
                <a href="${myIPFS}/ipns/${IPFSNODEID}" class="button" target="_blank">🌐 Access Station</a>
            </div>
        </div>
        
        <div class="footer">
            <p><strong>Astroport.ONE Station Management</strong></p>
            <p>Station ID: ${IPFSNODEID} | Generated: $(date '+%Y-%m-%d %H:%M:%S UTC')</p>
            <p>This is an automated notification from your Astroport.ONE station.</p>
        </div>
    </div>
</body>
</html>
EOF

# Send the professional notification email
${MY_PATH}/../tools/mailjet.sh "${CAPTAINEMAIL}" "$UNPLUG_EMAIL" "🚀 Player Unplugged: ${PLAYER} - ${SHOUT:-'Standard unplug'}"

# Clean up temporary email file
rm -f "$UNPLUG_EMAIL"

echo "PLAYER IPNS KEYS UNPLUGED"
echo "#######################"
echo "CLEANING ~/.zen/game/players/${PLAYER}"
rm -Rf ~/.zen/game/players/${PLAYER-empty}

echo "CLEANING NODE CACHE ~/.zen/tmp/${IPFSNODEID-empty}/*/${PLAYER-empty}*"
rm -Rf ~/.zen/tmp/${IPFSNODEID-empty}/*/${PLAYER-empty}*

##################### REMOVE NEXTCLOUD ACCOUNT
YOUSER=$($MY_PATH/../tools/clyuseryomail.sh "${PLAYER}")
#~ sudo docker exec --user www-data -it nextcloud-aio-nextcloud php occ user:delete ${YOUSER}

echo "CLEANING SESSION CACHE"
rm -Rf ~/.zen/tmp/${MOATS}

exit 0
