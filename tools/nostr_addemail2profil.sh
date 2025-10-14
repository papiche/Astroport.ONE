#!/bin/bash
################################################################################
# Script: nostr_addemail2profil.sh
# Description: Met à jour tous les profils NOSTR avec l'email correspondant
#
# Ce script :
# 1. Liste tous les comptes dans ~/.zen/game/nostr
# 2. Pour chaque compte, extrait l'email depuis le nom du dossier
# 3. Met à jour le profil NOSTR avec l'email via nostr_update_profile.py
#
# Usage: ./nostr_addemail2profil.sh [RELAY_URL]
# Si RELAY_URL n'est pas fourni, utilise ws://127.0.0.1:7777
################################################################################

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"

# Configuration
NOSTR_BASE="${HOME}/.zen/game/nostr"
DEFAULT_RELAY="ws://127.0.0.1:7777"
RELAY_URL="${1:-$DEFAULT_RELAY}"

echo "🔍 NOSTR Email Profile Updater"
echo "================================"
echo "📁 Scanning: $NOSTR_BASE"
echo "📡 Relay: $RELAY_URL"
echo ""

# Vérifier que le répertoire existe
if [[ ! -d "$NOSTR_BASE" ]]; then
    echo "❌ Error: NOSTR base directory not found: $NOSTR_BASE"
    exit 1
fi

# Vérifier que nostr_update_profile.py existe
if [[ ! -f "${MY_PATH}/nostr_update_profile.py" ]]; then
    echo "❌ Error: nostr_update_profile.py not found in ${MY_PATH}"
    exit 1
fi

# Compteurs
TOTAL_ACCOUNTS=0
UPDATED_ACCOUNTS=0
FAILED_ACCOUNTS=0
SKIPPED_ACCOUNTS=0

echo "🔍 Scanning for NOSTR accounts..."
echo ""

# Parcourir tous les dossiers dans ~/.zen/game/nostr
for account_dir in "$NOSTR_BASE"/*; do
    # Vérifier que c'est un dossier
    if [[ ! -d "$account_dir" ]]; then
        continue
    fi
    
    # Extraire le nom du compte (nom du dossier)
    account_name=$(basename "$account_dir")
    
    # Ignorer les dossiers qui ne contiennent pas d'@ (pas des emails)
    if [[ ! "$account_name" =~ @ ]]; then
        # echo "⏭️  Skipping non-email account: $account_name"
        ((SKIPPED_ACCOUNTS++))
        continue
    fi
    
    ((TOTAL_ACCOUNTS++))
    echo "📧 Processing account: $account_name"
    
    # Vérifier que les fichiers nécessaires existent
    secret_file="$account_dir/.secret.nostr"
    hex_file="$account_dir/HEX"
    
    if [[ ! -f "$secret_file" ]]; then
        echo "   ⚠️  Warning: .secret.nostr not found, skipping..."
        ((FAILED_ACCOUNTS++))
        continue
    fi
    
    if [[ ! -f "$hex_file" ]]; then
        echo "   ⚠️  Warning: HEX file not found, skipping..."
        ((FAILED_ACCOUNTS++))
        continue
    fi
    
    # Utiliser source pour récupérer NSEC depuis .secret.nostr
    echo "   🔐 Loading NSEC from .secret.nostr..."
    
    # Source le fichier .secret.nostr pour récupérer NSEC
    if [[ -f "$secret_file" ]]; then
        # Source le fichier pour récupérer les variables NSEC, NPUB, HEX
        source "$secret_file" 2>/dev/null
        
        if [[ -n "$NSEC" ]]; then
            echo "   ✅ NSEC loaded successfully"
            echo "   📧 Adding email: $account_name"
        else
            echo "   ❌ Error: NSEC not found in $secret_file"
            ((FAILED_ACCOUNTS++))
            continue
        fi
    else
        echo "   ❌ Error: .secret.nostr file not found: $secret_file"
        ((FAILED_ACCOUNTS++))
        continue
    fi
    
    # Mettre à jour le profil avec l'email
    echo "   📤 Updating NOSTR profile..."
    
    if python3 "${MY_PATH}/nostr_update_profile.py" \
        "$NSEC" \
        "$RELAY_URL" \
        --email "$account_name" 2>/dev/null; then
        echo "   ✅ Profile updated successfully"
        ((UPDATED_ACCOUNTS++))
    else
        echo "   ❌ Failed to update profile"
        ((FAILED_ACCOUNTS++))
    fi
    
    echo ""
done

# Résumé
echo "📊 Summary"
echo "=========="
echo "📧 Total accounts found: $TOTAL_ACCOUNTS"
echo "✅ Successfully updated: $UPDATED_ACCOUNTS"
echo "❌ Failed updates: $FAILED_ACCOUNTS"
echo "⏭️  Skipped (non-email): $SKIPPED_ACCOUNTS"
echo ""

if [[ $UPDATED_ACCOUNTS -gt 0 ]]; then
    echo "🎉 Successfully updated $UPDATED_ACCOUNTS NOSTR profiles with email information!"
else
    echo "⚠️  No profiles were updated. Check the logs above for details."
fi

if [[ $FAILED_ACCOUNTS -gt 0 ]]; then
    echo "⚠️  $FAILED_ACCOUNTS accounts failed to update. Check the logs above for details."
fi

echo ""
echo "🔍 You can verify the updates by checking the profiles in the NOSTR viewer:"
echo "   ${myIPFS}/ipns/copylaradio.com/nostr_profile_viewer.html"
echo ""

exit 0
