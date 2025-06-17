#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 1.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Configuration des exporters Prometheus pour la ♥️box UPlanet
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
. "${MY_PATH}/my.sh"

# Configuration
PROMETHEUS_CONFIG_DIR="/etc/prometheus"
PROMETHEUS_EXPORTERS_DIR="/etc/prometheus/exporters"
PROMETHEUS_CONFIG_FILE="${PROMETHEUS_CONFIG_DIR}/prometheus.yml"

#######################################################################
# Fonction d'aide
#######################################################################
show_help() {
    cat << EOF
Configuration des exporters Prometheus pour la ♥️box UPlanet
========================================================

UTILISATION:
    $0 [COMMANDE]

COMMANDES:
    install            Installation et configuration des exporters (défaut)
    status            Vérification du statut des exporters
    --help            Affiche cette aide

EXEMPLES:
    $0                # Installation complète
    $0 status        # Vérification du statut

LICENCE: AGPL-3.0
AUTEUR: Fred (support@qo-op.com)
EOF
}

#######################################################################
# Vérification des prérequis
#######################################################################
check_prerequisites() {
    echo "Vérification des prérequis..."
    
    # Vérifier si Prometheus est installé
    if ! command -v prometheus &> /dev/null; then
        echo "❌ Prometheus n'est pas installé. Installation..."
        sudo apt-get update
        sudo apt-get install -y prometheus
    else
        echo "✅ Prometheus est installé"
    fi
    
    # Vérifier si node_exporter est installé
    if ! command -v prometheus-node-exporter &> /dev/null; then
        echo "❌ Node Exporter n'est pas installé. Installation..."
        sudo apt-get install -y prometheus-node-exporter
    else
        echo "✅ Node Exporter est installé"
    fi
    
    # Créer les répertoires nécessaires
    sudo mkdir -p "${PROMETHEUS_EXPORTERS_DIR}"
}

#######################################################################
# Configuration de l'exporter IPFS
#######################################################################
setup_ipfs_exporter() {
    echo "Configuration de l'exporter IPFS..."
    
    # Vérifier si l'exporter IPFS est déjà installé
    if ! command -v ipfs-exporter &> /dev/null; then
        echo "Installation de l'exporter IPFS..."
        
        # Créer le script de l'exporter
        cat << 'EOF' | sudo tee "${PROMETHEUS_EXPORTERS_DIR}/ipfs-exporter.sh"
#!/bin/bash
# Exporter Prometheus pour IPFS

while true; do
    # Récupérer les métriques IPFS
    PEERS=$(ipfs swarm peers 2>/dev/null | wc -l)
    REPO_SIZE=$(du -sb ~/.ipfs 2>/dev/null | cut -f1)
    
    # Générer les métriques au format Prometheus
    echo "# HELP ipfs_peers_total Nombre de peers IPFS connectés"
    echo "# TYPE ipfs_peers_total gauge"
    echo "ipfs_peers_total $PEERS"
    
    echo "# HELP ipfs_repo_size_bytes Taille du repo IPFS en bytes"
    echo "# TYPE ipfs_repo_size_bytes gauge"
    echo "ipfs_repo_size_bytes $REPO_SIZE"
    
    # Attendre 15 secondes
    sleep 15
done
EOF
        
        # Rendre le script exécutable
        sudo chmod +x "${PROMETHEUS_EXPORTERS_DIR}/ipfs-exporter.sh"
        
        # Créer le service systemd
        cat << EOF | sudo tee /etc/systemd/system/ipfs-exporter.service
[Unit]
Description=IPFS Prometheus Exporter
After=network.target

[Service]
User=$USER
ExecStart=${PROMETHEUS_EXPORTERS_DIR}/ipfs-exporter.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        
        # Activer et démarrer le service
        sudo systemctl daemon-reload
        sudo systemctl enable ipfs-exporter
        sudo systemctl start ipfs-exporter
    else
        echo "✅ Exporter IPFS déjà installé"
    fi
}

#######################################################################
# Configuration de l'exporter NextCloud
#######################################################################
setup_nextcloud_exporter() {
    echo "Configuration de l'exporter NextCloud..."
    
    # Vérifier si l'exporter NextCloud est déjà installé
    if ! command -v nextcloud-exporter &> /dev/null; then
        echo "Installation de l'exporter NextCloud..."
        
        # Créer le script de l'exporter
        cat << 'EOF' | sudo tee "${PROMETHEUS_EXPORTERS_DIR}/nextcloud-exporter.sh"
#!/bin/bash
# Exporter Prometheus pour NextCloud

while true; do
    # Vérifier si NextCloud est actif
    if docker ps --filter "name=nextcloud" --format "{{.Names}}" | grep -q nextcloud; then
        NC_UP=1
        # Compter les utilisateurs (à adapter selon votre configuration)
        NC_USERS=$(docker exec nextcloud occ user:list 2>/dev/null | wc -l)
    else
        NC_UP=0
        NC_USERS=0
    fi
    
    # Générer les métriques au format Prometheus
    echo "# HELP nextcloud_up État de NextCloud (1 = actif, 0 = inactif)"
    echo "# TYPE nextcloud_up gauge"
    echo "nextcloud_up $NC_UP"
    
    echo "# HELP nextcloud_users_total Nombre d'utilisateurs NextCloud"
    echo "# TYPE nextcloud_users_total gauge"
    echo "nextcloud_users_total $NC_USERS"
    
    # Attendre 15 secondes
    sleep 15
done
EOF
        
        # Rendre le script exécutable
        sudo chmod +x "${PROMETHEUS_EXPORTERS_DIR}/nextcloud-exporter.sh"
        
        # Créer le service systemd
        cat << EOF | sudo tee /etc/systemd/system/nextcloud-exporter.service
[Unit]
Description=NextCloud Prometheus Exporter
After=network.target

[Service]
User=$USER
ExecStart=${PROMETHEUS_EXPORTERS_DIR}/nextcloud-exporter.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        
        # Activer et démarrer le service
        sudo systemctl daemon-reload
        sudo systemctl enable nextcloud-exporter
        sudo systemctl start nextcloud-exporter
    else
        echo "✅ Exporter NextCloud déjà installé"
    fi
}

#######################################################################
# Configuration de l'exporter Astroport
#######################################################################
setup_astroport_exporter() {
    echo "Configuration de l'exporter Astroport..."
    
    # Vérifier si l'exporter Astroport est déjà installé
    if ! command -v astroport-exporter &> /dev/null; then
        echo "Installation de l'exporter Astroport..."
        
        # Créer le script de l'exporter
        cat << 'EOF' | sudo tee "${PROMETHEUS_EXPORTERS_DIR}/astroport-exporter.sh"
#!/bin/bash
# Exporter Prometheus pour Astroport

while true; do
    # Vérifier si Astroport est actif
    if pgrep -f "12345" > /dev/null; then
        ASTROPORT_UP=1
    else
        ASTROPORT_UP=0
    fi
    
    # Générer les métriques au format Prometheus
    echo "# HELP astroport_up État d'Astroport (1 = actif, 0 = inactif)"
    echo "# TYPE astroport_up gauge"
    echo "astroport_up $ASTROPORT_UP"
    
    # Attendre 15 secondes
    sleep 15
done
EOF
        
        # Rendre le script exécutable
        sudo chmod +x "${PROMETHEUS_EXPORTERS_DIR}/astroport-exporter.sh"
        
        # Créer le service systemd
        cat << EOF | sudo tee /etc/systemd/system/astroport-exporter.service
[Unit]
Description=Astroport Prometheus Exporter
After=network.target

[Service]
User=$USER
ExecStart=${PROMETHEUS_EXPORTERS_DIR}/astroport-exporter.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        
        # Activer et démarrer le service
        sudo systemctl daemon-reload
        sudo systemctl enable astroport-exporter
        sudo systemctl start astroport-exporter
    else
        echo "✅ Exporter Astroport déjà installé"
    fi
}

#######################################################################
# Configuration de Prometheus
#######################################################################
setup_prometheus_config() {
    echo "Configuration de Prometheus..."
    
    # Créer la configuration Prometheus
    cat << EOF | sudo tee "${PROMETHEUS_CONFIG_FILE}"
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'ipfs'
    static_configs:
      - targets: ['localhost:9101']

  - job_name: 'nextcloud'
    static_configs:
      - targets: ['localhost:9102']

  - job_name: 'astroport'
    static_configs:
      - targets: ['localhost:9103']
EOF
    
    # Redémarrer Prometheus
    sudo systemctl restart prometheus
}

#######################################################################
# Vérification du statut
#######################################################################
check_status() {
    echo "Vérification du statut des exporters..."
    
    # Vérifier Prometheus
    echo "Prometheus:"
    systemctl status prometheus | grep "Active:"
    
    # Vérifier Node Exporter
    echo "Node Exporter:"
    systemctl status prometheus-node-exporter | grep "Active:"
    
    # Vérifier IPFS Exporter
    echo "IPFS Exporter:"
    systemctl status ipfs-exporter | grep "Active:"
    
    # Vérifier NextCloud Exporter
    echo "NextCloud Exporter:"
    systemctl status nextcloud-exporter | grep "Active:"
    
    # Vérifier Astroport Exporter
    echo "Astroport Exporter:"
    systemctl status astroport-exporter | grep "Active:"
    
    # Vérifier les métriques
    echo "Métriques disponibles:"
    curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, state: .health}'
}

#######################################################################
# Installation complète
#######################################################################
install_all() {
    check_prerequisites
    setup_ipfs_exporter
    setup_nextcloud_exporter
    setup_astroport_exporter
    setup_prometheus_config
    check_status
}

#######################################################################
# Interface en ligne de commande
#######################################################################
case "${1:-install}" in
    "install")
        install_all
        ;;
    "status")
        check_status
        ;;
    "--help"|"help")
        show_help
        ;;
    *)
        echo "Usage: $0 [install|status|--help]"
        echo ""
        echo "Commandes:"
        echo "  install            - Installation complète (défaut)"
        echo "  status            - Vérification du statut"
        echo "  --help            - Affiche l'aide complète"
        echo ""
        echo "Pour plus d'informations: $0 --help"
        ;;
esac 