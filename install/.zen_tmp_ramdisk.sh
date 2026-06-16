#!/bin/bash
########################################################################
# RAMDISK SETUP (~/.zen/tmp)
# Idempotent : vérifie mountpoint avant fstab avant montage.
# Appelé par 20h12.process.sh à chaque cycle de maintenance.
########################################################################
ZEN_TMP="$HOME/.zen/tmp"
mkdir -p "$ZEN_TMP"

FSTAB_ENTRY="tmpfs $ZEN_TMP tmpfs defaults,noatime,nosuid,nodev,mode=1777 0 0"

if mountpoint -q "$ZEN_TMP"; then
    echo "ℹ️  RAMdisk déjà monté ($ZEN_TMP)"
elif grep -qF "$ZEN_TMP" /etc/fstab; then
    # Fstab configuré mais pas encore monté (ex: premier démarrage post-install)
    echo "Montage RAMdisk depuis fstab : $ZEN_TMP"
    sudo mount "$ZEN_TMP" && echo "✅ RAMdisk monté ($ZEN_TMP)" \
        || echo "WARN: mount $ZEN_TMP échoué (services déjà en cours ?)"
else
    echo "Configuration RAMdisk tmpfs pour $ZEN_TMP ..."
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
    sudo mount "$ZEN_TMP" && echo "✅ RAMdisk activé ($ZEN_TMP)" \
        || echo "WARN: mount $ZEN_TMP échoué après ajout fstab"
fi
