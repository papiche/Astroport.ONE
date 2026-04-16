#!/bin/bash
########################################################################
# RAMDISK SETUP (~/.zen/tmp)
########################################################################
echo "######### CONFIGURATION RAMDISK (~/.zen/tmp) #######"
ZEN_TMP="$HOME/.zen/tmp"
mkdir -p "$ZEN_TMP"

# Vérifie si le point de montage n'est pas déjà dans fstab
if ! grep -q "$ZEN_TMP" /etc/fstab; then
    echo "Montage de $ZEN_TMP en RAMdisk (tmpfs) pour limiter les écritures disque..."
    
    # On définit une taille de 50% de la RAM (comportement par défaut) 
    # ou une taille fixe (ex: size=1G) pour éviter l'OOM (Out Of Memory)
    FSTAB_ENTRY="tmpfs $ZEN_TMP tmpfs defaults,noatime,nosuid,nodev,mode=1777 0 0"
    
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab > /dev/null
    
    # Montage immédiat sans redémarrer
    sudo mount "$ZEN_TMP" 2>/dev/null || sudo mount -a
    echo "✅ RAMdisk activé pour $ZEN_TMP !"
else
    echo "ℹ️ RAMdisk déjà configuré dans /etc/fstab"
fi
