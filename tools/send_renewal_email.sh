#!/bin/bash
################################################################################
# send_renewal_email.sh - Send renewal notification email for WoTx2 credentials
#
# Usage: send_renewal_email.sh EMAIL PERMIT_NAME PERMIT_ID CREDENTIAL_ID DAYS_REMAINING NOTIFICATION_LEVEL
#
# Author: UPlanet Oracle System
# License: AGPL-3.0
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "$MY_PATH/my.sh"
ME="${0##*/}"

# Arguments
EMAIL="$1"
PERMIT_NAME="$2"
PERMIT_ID="$3"
CREDENTIAL_ID="$4"
DAYS_REMAINING="$5"
NOTIFICATION_LEVEL="$6"
ISSUED_DATE="${7:-$(date -d '-330 days' '+%d/%m/%Y')}"
EXPIRY_DATE="${8:-$(date -d "+${DAYS_REMAINING} days" '+%d/%m/%Y')}"
USER_NAME="${9:-Astronaute}"

# Validate input
if [[ -z "$EMAIL" ]] || [[ -z "$PERMIT_NAME" ]]; then
    echo "[ERROR] Missing required arguments"
    echo "Usage: $0 EMAIL PERMIT_NAME PERMIT_ID CREDENTIAL_ID DAYS_REMAINING NOTIFICATION_LEVEL [ISSUED_DATE] [EXPIRY_DATE] [USER_NAME]"
    exit 1
fi

echo "[INFO] Sending renewal email to: $EMAIL"
echo "[INFO] Permit: $PERMIT_NAME ($PERMIT_ID)"
echo "[INFO] Days remaining: $DAYS_REMAINING"
echo "[INFO] Notification level: $NOTIFICATION_LEVEL"

# Create temp directory
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

# Determine colors and messages based on notification level
case "$NOTIFICATION_LEVEL" in
    "EXPIRED")
        HEADER_COLOR_START="#dc2626"
        HEADER_COLOR_END="#ef4444"
        CTA_COLOR_START="#dc2626"
        CTA_COLOR_END="#ef4444"
        ACCENT_COLOR="#dc2626"
        COUNTDOWN_BG="linear-gradient(135deg, #fef2f2, #fee2e2)"
        COUNTDOWN_COLOR="#dc2626"
        HEADER_EMOJI="🔴"
        HEADER_TITLE="Certificat Expiré"
        URGENCY_BADGE="ACTION IMMÉDIATE REQUISE"
        MESSAGE_INTRO="Votre certificat de maîtrise <strong>${PERMIT_NAME}</strong> a expiré. Pour continuer à bénéficier de votre statut de maître certifié, vous devez renouveler votre certification."
        COUNTDOWN_LABEL="CERTIFICAT EXPIRÉ"
        ;;
    "URGENT_1_DAY")
        HEADER_COLOR_START="#f59e0b"
        HEADER_COLOR_END="#fbbf24"
        CTA_COLOR_START="#f59e0b"
        CTA_COLOR_END="#fbbf24"
        ACCENT_COLOR="#f59e0b"
        COUNTDOWN_BG="linear-gradient(135deg, #fffbeb, #fef3c7)"
        COUNTDOWN_COLOR="#d97706"
        HEADER_EMOJI="🟠"
        HEADER_TITLE="Expiration Imminente"
        URGENCY_BADGE="⚡ URGENT - DERNIERS JOURS"
        MESSAGE_INTRO="Votre certificat de maîtrise <strong>${PERMIT_NAME}</strong> expire très bientôt ! Renouvelez-le dès maintenant pour éviter toute interruption de votre statut."
        COUNTDOWN_LABEL="jours restants"
        ;;
    "WARNING_7_DAYS")
        HEADER_COLOR_START="#eab308"
        HEADER_COLOR_END="#facc15"
        CTA_COLOR_START="#6366f1"
        CTA_COLOR_END="#8b5cf6"
        ACCENT_COLOR="#eab308"
        COUNTDOWN_BG="linear-gradient(135deg, #fefce8, #fef9c3)"
        COUNTDOWN_COLOR="#ca8a04"
        HEADER_EMOJI="🟡"
        HEADER_TITLE="Renouvellement Recommandé"
        URGENCY_BADGE="⏰ Expire dans ${DAYS_REMAINING} jours"
        MESSAGE_INTRO="Votre certificat de maîtrise <strong>${PERMIT_NAME}</strong> expire bientôt. Nous vous recommandons de planifier votre renouvellement."
        COUNTDOWN_LABEL="jours restants"
        ;;
    "WARNING_30_DAYS")
        HEADER_COLOR_START="#6366f1"
        HEADER_COLOR_END="#8b5cf6"
        CTA_COLOR_START="#6366f1"
        CTA_COLOR_END="#8b5cf6"
        ACCENT_COLOR="#6366f1"
        COUNTDOWN_BG="linear-gradient(135deg, #eef2ff, #e0e7ff)"
        COUNTDOWN_COLOR="#4f46e5"
        HEADER_EMOJI="ℹ️"
        HEADER_TITLE="Rappel de Renouvellement"
        URGENCY_BADGE="📅 Expire dans ${DAYS_REMAINING} jours"
        MESSAGE_INTRO="Votre certificat de maîtrise <strong>${PERMIT_NAME}</strong> expirera dans environ un mois. Pensez à planifier votre renouvellement."
        COUNTDOWN_LABEL="jours restants"
        ;;
    *)
        echo "[ERROR] Unknown notification level: $NOTIFICATION_LEVEL"
        exit 1
        ;;
esac

# Extract level from permit_id (e.g., PERMIT_BOULANGER_X1 -> X1)
PERMIT_LEVEL=$(echo "$PERMIT_ID" | grep -oP '_X\d+$' | sed 's/_//')
[[ -z "$PERMIT_LEVEL" ]] && PERMIT_LEVEL="X1"

# Build renewal URL
RENEWAL_URL="${uSPOT:-http://127.0.0.1:54321}/wotx2_renewal?permit_id=${PERMIT_ID}&credential_id=${CREDENTIAL_ID}"
ORACLE_URL="${uSPOT:-http://127.0.0.1:54321}/wotx2"
WOTX2_URL="${uSPOT:-http://127.0.0.1:54321}/wotx2"

# Template path
TEMPLATE_PATH="${MY_PATH}/../templates/NOSTR/oracle_renewal_notification.html"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
    echo "[ERROR] Template not found: $TEMPLATE_PATH"
    exit 1
fi

# Generate email HTML from template
EMAIL_HTML="${HOME}/.zen/tmp/${MOATS}/renewal_email.html"

cat "$TEMPLATE_PATH" \
    | sed -e "s|_HEADER_COLOR_START_|${HEADER_COLOR_START}|g" \
    | sed -e "s|_HEADER_COLOR_END_|${HEADER_COLOR_END}|g" \
    | sed -e "s|_CTA_COLOR_START_|${CTA_COLOR_START}|g" \
    | sed -e "s|_CTA_COLOR_END_|${CTA_COLOR_END}|g" \
    | sed -e "s|_ACCENT_COLOR_|${ACCENT_COLOR}|g" \
    | sed -e "s|_COUNTDOWN_BG_|${COUNTDOWN_BG}|g" \
    | sed -e "s|_COUNTDOWN_COLOR_|${COUNTDOWN_COLOR}|g" \
    | sed -e "s|_HEADER_EMOJI_|${HEADER_EMOJI}|g" \
    | sed -e "s|_HEADER_TITLE_|${HEADER_TITLE}|g" \
    | sed -e "s|_URGENCY_BADGE_|${URGENCY_BADGE}|g" \
    | sed -e "s|_MESSAGE_INTRO_|${MESSAGE_INTRO}|g" \
    | sed -e "s|_COUNTDOWN_LABEL_|${COUNTDOWN_LABEL}|g" \
    | sed -e "s|_USER_NAME_|${USER_NAME}|g" \
    | sed -e "s|_PERMIT_NAME_|${PERMIT_NAME}|g" \
    | sed -e "s|_PERMIT_ID_|${PERMIT_ID}|g" \
    | sed -e "s|_PERMIT_LEVEL_|${PERMIT_LEVEL}|g" \
    | sed -e "s|_CREDENTIAL_ID_|${CREDENTIAL_ID}|g" \
    | sed -e "s|_DAYS_REMAINING_|${DAYS_REMAINING}|g" \
    | sed -e "s|_ISSUED_DATE_|${ISSUED_DATE}|g" \
    | sed -e "s|_EXPIRY_DATE_|${EXPIRY_DATE}|g" \
    | sed -e "s|_RENEWAL_URL_|${RENEWAL_URL}|g" \
    | sed -e "s|_ORACLE_URL_|${ORACLE_URL}|g" \
    | sed -e "s|_WOTX2_URL_|${WOTX2_URL}|g" \
    | sed -e "s|_STATION_NAME_|$(myHostName)|g" \
    | sed -e "s|_IPFSNODEID_|${IPFSNODEID:-N/A}|g" \
    > "$EMAIL_HTML"

# Determine email subject based on notification level
case "$NOTIFICATION_LEVEL" in
    "EXPIRED")
        SUBJECT="🔴 EXPIRÉ - Certificat ${PERMIT_NAME}"
        ;;
    "URGENT_1_DAY")
        SUBJECT="🟠 URGENT - Certificat ${PERMIT_NAME} expire dans ${DAYS_REMAINING} jour(s)"
        ;;
    "WARNING_7_DAYS")
        SUBJECT="🟡 ATTENTION - Certificat ${PERMIT_NAME} expire dans ${DAYS_REMAINING} jours"
        ;;
    "WARNING_30_DAYS")
        SUBJECT="ℹ️ RAPPEL - Certificat ${PERMIT_NAME} expire dans ${DAYS_REMAINING} jours"
        ;;
esac

# Send email using mailjet.sh
MAILJET_SCRIPT="${MY_PATH}/mailjet.sh"

if [[ -f "$MAILJET_SCRIPT" ]]; then
    echo "[INFO] Sending email via mailjet.sh..."
    "$MAILJET_SCRIPT" "$EMAIL" "$EMAIL_HTML" "$SUBJECT"
    EXIT_CODE=$?
    
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "[SUCCESS] Renewal email sent to: $EMAIL"
    else
        echo "[WARNING] Failed to send email (exit code: $EXIT_CODE)"
    fi
else
    echo "[WARNING] mailjet.sh not found at: $MAILJET_SCRIPT"
    echo "[INFO] Email content saved to: $EMAIL_HTML"
fi

# Cleanup
rm -rf ~/.zen/tmp/${MOATS}

echo "[DONE] Renewal notification processed"
