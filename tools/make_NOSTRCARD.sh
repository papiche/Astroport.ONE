#!/bin/bash
################################################################################
# Script: Make_NOSTRCARD.sh
# Version: 0.2
# Description: Crée une carte NOSTR complète avec système d'identité décentralisé
################################################################################
set -euo pipefail  # Stricter error handling

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

# Constants
MAX_RETRIES=3
IPFS_TIMEOUT=20
IPFS_QR_TIMEOUT=20

# Function to validate email format
validate_email() {
    local email="$1"
    if [[ ! $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "Error: Invalid email format: $email"
        return 1
    fi
    return 0
}

# Function to generate random string
generate_random_string() {
    local length="${1:-42}"
    tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w"$length" | head -n1
}

# Function to handle IPFS operations with retry
ipfs_operation() {
    local operation="$1"
    local retries=0
    local result=""
    
    while [[ $retries -lt $MAX_RETRIES ]]; do
        result=$(eval "$operation")
        if [[ $? -eq 0 ]]; then
            echo "$result"
            return 0
        fi
        retries=$((retries + 1))
        sleep 2
    done
    return 1
}

usage() {
    cat << EOF
Usage: Make_NOSTRCARD.sh [OPTIONS] <EMAIL> [IMAGE] [LATITUDE] [LONGITUDE] [SALT] [PEPPER]

  Generates a NOSTR card and related cryptographic keys, stores them
  locally, and prepares files for a NOSTR application.

Arguments:
  <EMAIL>       Email address to associate with the NOSTR card.
                Must be a valid email format.
  [IMAGE]       Optional: Path to an image file to use as profile picture.
                Alternatively, a two-letter language code (e.g., 'en', 'fr')
                to set the language. If omitted, defaults to 'fr'.
  [LATITUDE]    Optional: UMAP Latitude for location data.
  [LONGITUDE]   Optional: UMAP Longitude for location data.
  [SALT]        Optional: Salt for key generation. If omitted, a random salt is generated.
  [PEPPER]      Optional: Pepper for key generation. If omitted, a random pepper is generated.

Options:
  -h, --help    Display this help message and exit.

Example:
  make_NOSTRCARD.sh john.doe@example.com ./profile.png 48.85 2.35
  make_NOSTRCARD.sh jane.doe@example.com en
EOF
    exit 1
}

# Parse command line arguments
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

if [[ "$#" -lt 1 ]]; then
    echo "Error: Missing EMAIL parameter."
    usage
fi

# Initialize variables
PARAM="$1"
EMAIL="${PARAM,,}"  # lowercase
IMAGE="${2:-}"
ZLAT=$(makecoord "${3:-}")
ZLON=$(makecoord "${4:-}")
SALT="${5:-}"
PEPPER="${6:-}"

echo "Make_NOSTRCARD.sh >>>>>>>>>> $EMAIL"

# Create temporary directory
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
TEMP_DIR="$HOME/.zen/tmp/${MOATS}"
mkdir -p "$TEMP_DIR"

# Validate email
if ! validate_email "$EMAIL"; then
    echo "BAD EMAIL PARAMETER"
    exit 1
fi

# Generate SALT and PEPPER if not provided
[[ -z "$SALT" ]] && SALT=$(generate_random_string)
[[ -z "$PEPPER" ]] && PEPPER=$(generate_random_string)

# Create DISCO string
DISCO="/?${EMAIL}=${SALT}&nostr=${PEPPER}"

# Split DISCO using ssss
echo "$DISCO" | ssss-split -t 2 -n 3 -q > "$TEMP_DIR/${EMAIL}.ssss"
HEAD=$(head -n 1 "$TEMP_DIR/${EMAIL}.ssss")
MIDDLE=$(head -n 2 "$TEMP_DIR/${EMAIL}.ssss" | tail -n 1)
TAIL=$(tail -n 1 "$TEMP_DIR/${EMAIL}.ssss")

# Verify SSSS decoding
if ! echo "$HEAD
$TAIL" | ssss-combine -t 2 -q; then
    echo "ERROR! SSSSKEY DECODING FAILED"
    echo "${MY_PATH}/../templates/wallet.html"
    exit 1
fi

# Generate NOSTR keys
NPRIV=$(${MY_PATH}/../tools/keygen -t nostr "${SALT}" "${PEPPER}" -s)
NPUBLIC=$(${MY_PATH}/../tools/keygen -t nostr "${SALT}" "${PEPPER}")
HEX=$(${MY_PATH}/../tools/nostr2hex.py "$NPUBLIC")

echo "Nostr Public Key: $NPUBLIC = $HEX"

# Store keys
echo "$NPRIV" > "$TEMP_DIR/${EMAIL}.nostr.priv"
echo "$NPUBLIC" > "$TEMP_DIR/${EMAIL}.nostr.pub"

# Create G1CARD
${MY_PATH}/../tools/keygen -t duniter -o "$TEMP_DIR/${EMAIL}.g1card.dunikey" "${SALT}" "${PEPPER}"
G1PUBNOSTR=$(grep 'pub:' "$TEMP_DIR/${EMAIL}.g1card.dunikey" | cut -d ' ' -f 2)
echo "G1NOSTR _WALLET: $G1PUBNOSTR"

# Create user space
NOSTR_DIR="$HOME/.zen/game/nostr/${EMAIL}"
mkdir -p "$NOSTR_DIR"

# Handle profile picture
if [[ -s "${IMAGE}" ]]; then
    cp "${IMAGE}" "$NOSTR_DIR/picture.png"
elif [[ "${IMAGE}" =~ ^[a-z]{2}$ ]]; then
    LANG="${IMAGE}"
else
    LANG="fr"
fi

# Store basic information
echo "${LANG}" > "$NOSTR_DIR/LANG"
echo "$HEX" > "$NOSTR_DIR/HEX"
echo "$NPUBLIC" > "$NOSTR_DIR/NPUB"

# Generate cryptocurrency addresses
BITCOIN=$(${MY_PATH}/../tools/keygen -t bitcoin "${SALT}" "${PEPPER}" | tail -n 1 | rev | cut -f 1 -d ' ' | rev)
echo "$BITCOIN" > "$NOSTR_DIR/BITCOIN"

MONERO=$(${MY_PATH}/../tools/keygen -t monero "${SALT}" "${PEPPER}" | tail -n 1 | rev | cut -f 1 -d ' ' | rev)
echo "$MONERO" > "$NOSTR_DIR/MONERO"

# Encrypt SSSS parts
${MY_PATH}/../tools/natools.py encrypt -p "$G1PUBNOSTR" -i "$TEMP_DIR/${EMAIL}.ssss.head" -o "$NOSTR_DIR/.ssss.head.player.enc"
${MY_PATH}/../tools/natools.py encrypt -p "$CAPTAING1PUB" -i "$TEMP_DIR/${EMAIL}.ssss.mid" -o "$NOSTR_DIR/.ssss.mid.captain.enc"
${MY_PATH}/../tools/natools.py encrypt -p "$UPLANETG1PUB" -i "$TEMP_DIR/${EMAIL}.ssss.tail" -o "$NOSTR_DIR/ssss.tail.uplanet.enc"

# Create IPNS key
${MY_PATH}/../tools/keygen -t ipfs -o "$TEMP_DIR/${MOATS}.nostr.ipns" "${SALT}" "${PEPPER}"
ipfs key rm "${G1PUBNOSTR}:NOSTR" > /dev/null 2>&1 || true
NOSTRNS=$(ipfs key import "${G1PUBNOSTR}:NOSTR" -f pem-pkcs8-cleartext "$TEMP_DIR/${MOATS}.nostr.ipns")
echo "${G1PUBNOSTR}:NOSTR ${EMAIL} STORAGE: /ipns/$NOSTRNS"
echo "/ipns/$NOSTRNS" > "$NOSTR_DIR/NOSTRNS"

# Generate QR codes
amzqr "${uSPOT}/scan" -l H -p "${MY_PATH}/../templates/img/key.png" \
    -c -n uSPOT.QR.png -d "$NOSTR_DIR/" 2>/dev/null

uSPOT_QR_ipfs=$(ipfs_operation "ipfs --timeout ${IPFS_TIMEOUT}s add -q $NOSTR_DIR/uSPOT.QR.png")

amzqr "${myIPFS}/ipns/$NOSTRNS" -l H -p "${MY_PATH}/../templates/img/no_stripfs.png" \
    -c -n IPNS.QR.png -d "$NOSTR_DIR/" 2>/dev/null

VAULTNSQR=$(ipfs_operation "ipfs --timeout ${IPFS_TIMEOUT}s add -q $NOSTR_DIR/IPNS.QR.png")

if [[ $? -ne 0 ]]; then
    cat ~/.zen/UPassport/templates/wallet.html \
        | sed -e "s~_WALLET_~$(date -u) <br> ${EMAIL}~g" \
             -e "s~_AMOUNT_~IPFS DAEMON ERROR~g" \
        > "${MY_PATH}/tmp/${MOATS}.out.html"
    echo "${MY_PATH}/tmp/${MOATS}.out.html"
    exit 0
fi

# Generate player QR code
amzqr "$HEAD:$NOSTRNS" -l H -p "${MY_PATH}/../templates/img/key.png" \
    -c -n "${EMAIL}.QR.png" -d "$TEMP_DIR/" 2>/dev/null

SSSSQR=$(ipfs_operation "ipfs --timeout ${IPFS_TIMEOUT}s add -q $TEMP_DIR/${EMAIL}.QR.png")
ipfs pin rm "/ipfs/${SSSSQR}" 2>/dev/null || true

# Generate G1PUBNOSTR QR code
[[ -s "$NOSTR_DIR/picture.png" ]] \
    && FDQR="$NOSTR_DIR/picture.png" \
    || FDQR="${MY_PATH}/../templates/img/nature_cloud_face.png"

[[ $UPLANETNAME != "EnfinLibre" ]] && Z=":ZEN" || Z=""
amzqr "${G1PUBNOSTR}${Z}" -l H -p "$FDQR" -c -n G1PUBNOSTR.QR.png -d "$NOSTR_DIR/" 2>/dev/null
echo "${G1PUBNOSTR}" > "$NOSTR_DIR/G1PUBNOSTR"

# Move webcam picture
mv "$NOSTR_DIR/picture.png" "$NOSTR_DIR/scan_${MOATS}.png"

G1PUBNOSTRQR=$(ipfs_operation "ipfs --timeout ${IPFS_QR_TIMEOUT}s add -q $NOSTR_DIR/G1PUBNOSTR.QR.png")
echo "${G1PUBNOSTRQR}" > "$NOSTR_DIR/G1PUBNOSTR.QR.png.cid"

# Create NOSTR oracolo app
sed -e "s~npub1w25fyk90kknw499ku6q9j77sfx3888eyfr20kq2rj7f5gnm8qrfqd6uqu8~${NPUBLIC}~g" \
    -e "s~_MYRELAY_~${myRELAY}~g" \
    "${MY_PATH}/../templates/NOSTR/oracolo/index.html" > "$NOSTR_DIR/_BLOG.html"

# Store metadata
echo "${TODATE}" > "$NOSTR_DIR/TODATE"
echo "_${ZLAT}_${ZLON}" > "$NOSTR_DIR/ZUMAP"
echo "LAT=${ZLAT}; LON=${ZLON};" > "$NOSTR_DIR/GPS"

# Create NOSTR zine
sed -e "s~npub1w25fyk90kknw499ku6q9j77sfx3888eyfr20kq2rj7f5gnm8qrfqd6uqu8~${NPUBLIC}~g" \
    -e "s~nsec13x0643lc3al5fk92auurh7ww0993syj566eh7ta8r2jpkprs44rs33cute~${NPRIV}~g" \
    -e "s~toto@yopmail.com~${EMAIL}~g" \
    -e "s~QmdmeZhD8ncBFptmD5VSJoszmu41edtT265Xq3HVh8PhZP~${SSSSQR}~g" \
    -e "s~Qma4ceUiYD2bAydL174qCSrsnQRoDC3p5WgRGKo9tEgRqH~${G1PUBNOSTRQR}~g" \
    -e "s~Qmeu1LHnTTHNB9vex5oUwu3VVbc7uQZxMb8bYXuX56YAx2~${VAULTNSQR}~g" \
    -e "s~/ipfs/QmNd3abeAoUH1nGzwnaLNafRgtvwTSBCZyKqT8eBnEPQK9/u.scan.qr.png~/ipfs/${uSPOT_QR_ipfs}~g" \
    -e "s~_NSECTAIL_~${NPRIV: -33}~g" \
    -e "s~_UMAP_~_${ZLAT}_${ZLON}~g" \
    -e "s~_NOSTRVAULT_~/ipns/${NOSTRNS}~g" \
    -e "s~_SALT_~${SALT}~g" \
    -e "s~_PEPPER_~${PEPPER}~g" \
    -e "s~_MYRELAY_~${myRELAY}~g" \
    -e "s~_uSPOT_~${uSPOT}~g" \
    -e "s~_CAPTAINEMAIL_~${CAPTAINEMAIL}~g" \
    -e "s~_NOSTRG1PUB_~${G1PUBNOSTR}~g" \
    -e "s~_UPLANET8_~UPlanet:${UPLANETG1PUB:0:8}~g" \
    -e "s~_DATE_~$(date -u)~g" \
    -e "s~http://127.0.0.1:8080~${myIPFS}~g" \
    "${MY_PATH}/../templates/NOSTR/zine/nostr.html" > "$NOSTR_DIR/.nostr.zine.html"

# Setup uDRIVE and uWORLD
mkdir -p "$NOSTR_DIR/APP/uDRIVE/G1"
echo '<meta http-equiv="refresh" content="0;url='${CESIUMIPFS}/#/app/wot/${ISSUERPUB}/'">' \
    > "$NOSTR_DIR/APP/uDRIVE/G1/CESIUM.v1.html"

cd "$NOSTR_DIR/APP/uDRIVE/"
ln -sf "${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_structure.sh" ./generate_ipfs_structure.sh
. ./generate_ipfs_structure.sh --log .

mkdir -p "$NOSTR_DIR/APP/uWORLD/"
cd "$NOSTR_DIR/APP/uWORLD"
ln -sf "${HOME}/.zen/Astroport.ONE/tools/generate_ipfs_RPG.sh" ./generate_ipfs_RPG.sh
. ./generate_ipfs_RPG.sh --log .

cd -

# Publish to IPFS
NOSTRIPFS=$(ipfs_operation "ipfs --timeout ${IPFS_TIMEOUT}s add -rwq $NOSTR_DIR/ | tail -n 1")
ipfs name publish --key "${G1PUBNOSTR}:NOSTR" "/ipfs/${NOSTRIPFS}" 2>&1 >/dev/null &

# Setup NOSTR profile
YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh "${EMAIL}")
${MY_PATH}/../tools/nostr_setup_profile.py \
    "$NPRIV" \
    "[•͡˘㇁•͡˘] $YOUSER" "${G1PUBNOSTR}" \
    "⏰ UPlanet MULTIPASS ... 🪙 ... UPlanet ${UPLANETG1PUB:0:8}" \
    "$myIPFS/ipfs/${G1PUBNOSTRQR}" \
    "$myIPFS/ipfs/QmSMQCQDtcjzsNBec1EHLE78Q1S8UXGfjXmjt8P6o9B8UY/ComfyUI_00841_.jpg" \
    "" "$myIPFS/ipns/${NOSTRNS}/${EMAIL}/APP" "" "" "" "" \
    "wss://relay.copylaradio.com" "$myRELAY" \
    --ipns_vault "/ipns/${NOSTRNS}"

# Create CESIUM profile
${MY_PATH}/../tools/jaklis/jaklis.py -k "$TEMP_DIR/${EMAIL}.g1card.dunikey" set \
    --name "UPlanet MULTIPASS" \
    --avatar "$NOSTR_DIR/IPNS.QR.png" \
    --site "https://coracle.copylaradio.com" \
    -d "UPlanet MULTIPASS : $HEX : UPlanet ${UPLANETG1PUB:0:8}"

# Cleanup
rm -rf "$TEMP_DIR"

echo "$NOSTR_DIR/.nostr.zine.html"
exit 0
