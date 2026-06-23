#!/bin/bash
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ☁️  PROFIL nextcloud — NextCloud AIO (cloud privé 128Go)    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
## NextCloud AIO utilise son propre docker-compose dans _DOCKER/nextcloud/
## Ports : 8443 (AIO admin setup), 8001 (Apache nextcloud app), 8002 (AIO dashboard)

## ── Vérification et conseil disque BTRFS ────────────────────────────────
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  💾 STOCKAGE — /nextcloud-data                              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
if [[ -d /nextcloud-data ]]; then
    _NC_FS=$(stat -f -c %T /nextcloud-data 2>/dev/null || findmnt -no FSTYPE /nextcloud-data 2>/dev/null)
    _NC_SIZE=$(df -h /nextcloud-data | tail -1 | awk '{print $2" total, "$4" libre"}' 2>/dev/null)
    echo "║  ✅ /nextcloud-data existe (${_NC_FS:-?} — ${_NC_SIZE:-taille inconnue})  ║"
    if [[ "${_NC_FS}" != "btrfs" ]]; then
        echo "║  ⚡ Conseil: formater en BTRFS pour les avantages suivants :  ║"
        echo "║     • CoW + dédup IPFS (blocs identiques économisés)        ║"
        echo "║     • Snapshots instantanés (sauvegardes NextCloud)         ║"
        echo "║     • compression zstd transparente (~25% espace)           ║"
    else
        echo "║  🌿 Excellent : BTRFS détecté — CoW + compression actifs ✅  ║"
    fi
else
    echo "║  ⚠️  /nextcloud-data n'existe pas — création en cours...        ║"
    sudo mkdir -p /nextcloud-data
    sudo chown $USER:$USER /nextcloud-data 2>/dev/null || sudo chmod 777 /nextcloud-data
    echo "║  ✅ /nextcloud-data créé                                        ║"
    echo "║                                                               ║"
    echo "║  💡 RECOMMANDATION BTRFS (disque dédié) :                    ║"
    echo "║  Formatez un disque en BTRFS et montez-le sur /nextcloud-data ║"
    echo "║  pour y héberger NextCloud, ~/.zen et ~/.ipfs :               ║"
    echo "║                                                               ║"
    echo "║  sudo mkfs.btrfs -L astrodata /dev/sdX                       ║"
    echo "║  sudo mount -o compress=zstd,noatime /dev/sdX /nextcloud-data ║"
    echo "║  # Dans /etc/fstab :                                          ║"
    echo "║  # UUID=xxx /nextcloud-data btrfs compress=zstd,noatime 0 0  ║"
    echo "║                                                               ║"
    echo "║  Puis migrer les données (voir day3/captain ZINE) :          ║"
    echo "║  sudo mv ~/.zen /nextcloud-data/zen                          ║"
    echo "║  ln -s /nextcloud-data/zen ~/.zen                            ║"
    echo "║  sudo mv ~/.ipfs /nextcloud-data/ipfs                        ║"
    echo "║  ln -s /nextcloud-data/ipfs ~/.ipfs                          ║"
fi
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

_ASTRO_COMPOSE="$HOME/.zen/Astroport.ONE/docker/docker-compose.yml"
if [[ ! -f "$_ASTRO_COMPOSE" ]]; then
    echo "⚠️  Fichier introuvable : $_ASTRO_COMPOSE"
    echo "   → Vérifiez que Astroport.ONE est bien cloné"
else
    echo "⏳ Démarrage NextCloud AIO (peut prendre 2-3 minutes)..."
    (sg docker -c "docker compose -f '$_ASTRO_COMPOSE' --profile cloud up -d nextcloud" 2>/dev/null \
        || sudo docker compose -f "$_ASTRO_COMPOSE" --profile cloud up -d nextcloud) 2>&1
    _nc_exit=$?
    if [[ $_nc_exit -eq 0 ]]; then
        NEXTCLOUD_ACTIVE=true
        echo "✅ Conteneur nextcloud démarré"
        ## Attendre que le conteneur soit prêt avant de relancer NPM
        echo "⏳ Attente NextCloud (30s pour initialisation)..."
        sleep 30
        ## Re-lancer setup_npm.sh pour créer le proxy cloud.DOMAIN → :8001
        echo "🔧 Création proxy cloud.${DOMAIN_DISPLAY:-DOMAIN} via NPM..."
        bash "$HOME/.zen/Astroport.ONE/install/setup/setup_npm.sh" 2>/dev/null \
            && echo "✅ Proxy cloud.$DOMAIN créé dans NPM" \
            || echo "⚠️  NPM proxy non créé — relancez manuellement : setup_npm.sh"
    else
        echo "⚠️  Erreur démarrage NextCloud (code: $_nc_exit)"
        echo "   → Logs : docker compose -f $_NC_COMPOSE logs"
    fi
fi
cd - >/dev/null 2>/dev/null
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  📋 CONFIGURATION NEXTCLOUD AIO — 3 étapes                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                               ║"
echo "║  Ports NextCloud AIO :                                        ║"
echo "║    8443 = Interface admin AIO (setup initial, HTTPS)         ║"
echo "║    8001 = Apache NextCloud (app, après config AIO)           ║"
echo "║    8002 = Dashboard AIO (surveillance, HTTP)                 ║"
echo "║                                                               ║"
echo "║  1. SETUP INITIAL — interface AIO (première fois seul.) :   ║"
echo "║     https://127.0.0.1:8443                                   ║"
echo "║     → Acceptez le certificat auto-signé                      ║"
echo "║     → Entrez : cloud.${DOMAIN_DISPLAY:-VOTRE_DOMAINE}       ║"
echo "║     → AIO télécharge et installe automatiquement NextCloud   ║"
echo "║     → Activez les apps : Calendar, Contacts, Talk            ║"
echo "║                                                               ║"
echo "║  2. PROXY NPM cloud.${DOMAIN_DISPLAY:-DOMAINE} → :8001 :   ║"
if [[ "${NEXTCLOUD_ACTIVE}" == "true" ]]; then
echo "║     ✅ CRÉÉ AUTOMATIQUEMENT (setup_npm.sh relancé)           ║"
echo "║     Vérification : https://cloud.${DOMAIN_DISPLAY:-DOMAINE} ║"
else
echo "║     ⚠️  À créer manuellement (NextCloud non démarré) :       ║"
echo "║     sudo ~/.zen/Astroport.ONE/install/setup/setup_npm.sh    ║"
fi
echo "║     NPM admin : http://127.0.0.1:81                         ║"
echo "║     Mot de passe : cat ~/.zen/nginx-proxy-manager/data/.admin_pass ║"
echo "║                                                               ║"
echo "║  3. COMPTES ZEN CARD (1 compte = 1 abonné 128Go) :         ║"
echo "║     Interface web NextCloud : Utilisateurs → Nouveau         ║"
echo "║     CLI : docker exec -it nextcloud \   ║"
echo "║       bash                                                   ║"
echo "║     # puis : su -s /bin/bash www-data -c                    ║"
echo "║     # 'php /var/www/html/occ user:add --display-name U E'   ║"
echo "║                                                               ║"
echo "║  📖 Guide : pad.p2p.legal/Smartphone2NextCloud               ║"
echo "║  📖 Blog  : copylaradio.com — Le pas-à-pas du grand cloud   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
