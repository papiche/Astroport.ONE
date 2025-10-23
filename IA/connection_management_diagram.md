# Gestion des Connexions et Vérifications des Services IA - UPlanet

## Architecture de Gestion des Connexions

Le système UPlanet IA utilise une architecture de gestion des connexions en plusieurs niveaux pour s'assurer que tous les services IA sont disponibles avant de traiter les requêtes.

### 1. Services IA Gérés

#### **Ollama (Port 11434)**
- **Script**: `ollama.me.sh`
- **Vérification**: `netstat -tulnp | grep 11434`
- **Tunnel SSH**: `scorpio.copylaradio.com:2122`
- **Usage**: Réponses IA conversationnelles, analyse d'images

#### **ComfyUI (Port 8188)**
- **Script**: `comfyui.me.sh`
- **Vérification**: `netstat -tulnp | grep 8188`
- **Tunnel SSH**: `scorpio.copylaradio.com:2122`
- **Usage**: Génération d'images, vidéos, musique

#### **Perplexica (Port 3001)**
- **Script**: `perplexica.me.sh`
- **Vérification**: `netstat -tulnp | grep 3001`
- **Test API**: `curl http://localhost:3001/api/models`
- **Usage**: Recherche web intelligente

#### **Orpheus TTS (Port 5005)**
- **Script**: `orpheus.me.sh`
- **Vérification**: Docker + `netstat -tulnp | grep 5005`
- **Connexion IPFS P2P**: Swarm nodes avec `x_orpheus.sh`
- **Usage**: Synthèse vocale (voix Pierre/Aurélie)

### 2. Flux de Vérification des Connexions

```
UPlanet_IA_Responder.sh
├── 1. Vérification Ollama (OBLIGATOIRE)
│   └── ollama.me.sh
│       ├── Check local port 11434
│       ├── Si fermé → Tunnel SSH vers scorpio.copylaradio.com
│       └── Exit si échec
│
├── 2. Vérifications Spécialisées (selon tags)
│   ├── #search → perplexica.me.sh
│   │   ├── Check port 3001
│   │   ├── Test API /api/models
│   │   └── Tunnel SSH si nécessaire
│   │
│   ├── #image/#video/#music → comfyui.me.sh
│   │   ├── Check port 8188
│   │   ├── Test connexion ComfyUI
│   │   └── Tunnel SSH si nécessaire
│   │
│   └── #pierre/#amelie → orpheus.me.sh
│       ├── Check Docker + port 5005
│       ├── Découverte nodes swarm
│       ├── Connexion IPFS P2P
│       └── Test API /docs
│
└── 3. Traitement de la Requête
    ├── Si toutes connexions OK → Exécution
    └── Si échec → Message d'erreur
```

### 3. Mécanismes de Vérification

#### **Vérification de Port (Standard)**
```bash
check_port() {
    if netstat -tulnp 2>/dev/null | grep $PORT; then
        echo "Port $PORT est ouvert"
        return 0
    else
        echo "Port $PORT n'est pas ouvert"
        return 1
    fi
}
```

#### **Test de Connexion API**
```bash
test_api() {
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/api/endpoint")
    if [ "$RESPONSE" == "200" ]; then
        return 0
    else
        return 1
    fi
}
```

#### **Établissement de Tunnel SSH**
```bash
establish_tunnel() {
    ssh -fN -L 127.0.0.1:$LOCAL_PORT:127.0.0.1:$REMOTE_PORT $USER@$HOST -p $SSH_PORT
}
```

#### **Connexion IPFS P2P (Orpheus)**
```bash
establish_ipfs_p2p() {
    # Découverte des nodes swarm
    for orpheus_script in ~/.zen/tmp/swarm/*/x_orpheus.sh; do
        bash "$orpheus_script"  # Établit tunnel IPFS P2P
    done
}
```

### 4. Gestion des Erreurs

#### **Niveaux de Vérification**
1. **Port local** - Vérification rapide
2. **Test API** - Vérification fonctionnelle
3. **Tunnel SSH** - Connexion distante
4. **IPFS P2P** - Connexion swarm (Orpheus)

#### **Messages d'Erreur Spécialisés**
- **Ollama**: "Error: Failed to maintain Ollama connection"
- **ComfyUI**: "Erreur : Le port ComfyUI n'est pas accessible"
- **Perplexica**: "Could not establish connection to Perplexica API"
- **Orpheus**: "Could not establish connection to any Orpheus TTS API"

### 5. Optimisations

#### **Vérifications Préventives**
- Ollama vérifié au démarrage du script principal
- Services spécialisés vérifiés uniquement si tags détectés
- Connexions maintenues pendant la session

#### **Gestion des Tunnels**
- Fermeture automatique des tunnels inactifs
- Réutilisation des connexions existantes
- Load balancing sur les nodes swarm (Orpheus)

### 6. Configuration des Services

#### **Variables d'Environnement**
```bash
# Ollama
OLLAMA_PORT=11434
REMOTE_HOST="scorpio.copylaradio.com"
REMOTE_PORT=2122

# ComfyUI
COMFYUI_PORT=8188
COMFYUI_URL="http://127.0.0.1:8188"

# Perplexica
PERPLEXICA_PORT=3001

# Orpheus
ORPHEUS_PORT=5005
```

#### **Scripts de Maintenance**
- `ollama.me.sh OFF` - Fermer tunnel Ollama
- `comfyui.me.sh OFF` - Fermer tunnel ComfyUI
- `perplexica.me.sh OFF` - Fermer tunnel Perplexica
- `orpheus.me.sh OFF` - Fermer connexions IPFS P2P

### 7. Migration vers IPFS P2P en Production UPlanet ẐEN[0]

#### **Architecture Future - Tous Services via IPFS P2P**

En production UPlanet ẐEN[0], **tous les services IA** utiliseront des connexions IPFS P2P au lieu des tunnels SSH, suivant le modèle d'Orpheus :

```bash
# Architecture future - Tous services via IPFS P2P
~/.zen/tmp/swarm/*/x_ollama.sh      # Ollama via IPFS P2P
~/.zen/tmp/swarm/*/x_comfyui.sh    # ComfyUI via IPFS P2P  
~/.zen/tmp/swarm/*/x_perplexica.sh # Perplexica via IPFS P2P
~/.zen/tmp/swarm/*/x_orpheus.sh    # Orpheus via IPFS P2P (déjà implémenté)
```

#### **Avantages de l'IPFS P2P**

1. **Décentralisation Complète**
   - Plus de dépendance à `scorpio.copylaradio.com`
   - Chaque node du swarm peut héberger les services
   - Redondance et résilience améliorées

2. **Load Balancing Automatique**
   - Découverte dynamique des nodes disponibles
   - Rotation automatique entre les nodes
   - Équilibrage de charge distribué

3. **Sécurité Renforcée**
   - Connexions chiffrées end-to-end via IPFS
   - Pas d'exposition de ports SSH
   - Authentification par clés IPFS

#### **Migration des Services**

##### **Ollama P2P (Port 11434)**
```bash
# ollama.me.sh - Version future
establish_ipfs_p2p() {
    local ollama_script="$1"
    local node_id=$(basename $(dirname "$ollama_script"))
    
    # Vérifier si connexion existe déjà
    if ipfs p2p ls | grep "/x/ollama-$node_id" >/dev/null; then
        return 0
    fi
    
    # Établir connexion P2P
    bash "$ollama_script"  # Port 11434 via IPFS
}
```

##### **ComfyUI P2P (Port 8188)**
```bash
# comfyui.me.sh - Version future
establish_ipfs_p2p() {
    local comfyui_script="$1"
    local node_id=$(basename $(dirname "$comfyui_script"))
    
    # Vérifier si connexion existe déjà
    if ipfs p2p ls | grep "/x/comfyui-$node_id" >/dev/null; then
        return 0
    fi
    
    # Établir connexion P2P
    bash "$comfyui_script"  # Port 8188 via IPFS
}
```

##### **Perplexica P2P (Port 3001)**
```bash
# perplexica.me.sh - Version future
establish_ipfs_p2p() {
    local perplexica_script="$1"
    local node_id=$(basename $(dirname "$perplexica_script"))
    
    # Vérifier si connexion existe déjà
    if ipfs p2p ls | grep "/x/perplexica-$node_id" >/dev/null; then
        return 0
    fi
    
    # Établir connexion P2P
    bash "$perplexica_script"  # Port 3001 via IPFS
}
```

#### **Découverte des Nodes Swarm via DRAGON_p2p_ssh.sh**

Le script `DRAGON_p2p_ssh.sh` est le **cœur du système de découverte** des services disponibles dans le swarm. Il alimente automatiquement les indicateurs de ports et fonctions offertes par chaque node :

```bash
# DRAGON_p2p_ssh.sh - Découverte automatique des services
# Chaque node exécute ce script pour publier ses services disponibles

# 1. DÉTECTION DES SERVICES LOCAUX
if [[ ! -z $(pgrep ollama) ]]; then
    # Node offre Ollama - crée x_ollama.sh
    ipfs p2p listen /x/ollama-${IPFSNODEID} /ip4/127.0.0.1/tcp/11434
fi

if [[ ! -z $(systemctl status comfyui.service | grep "active (running)") ]]; then
    # Node offre ComfyUI - crée x_comfyui.sh
    ipfs p2p listen /x/comfyui-${IPFSNODEID} /ip4/127.0.0.1/tcp/8188
fi

if [[ ! -z $(docker ps | grep orpheus) ]]; then
    # Node offre Orpheus - crée x_orpheus.sh
    ipfs p2p listen /x/orpheus-${IPFSNODEID} /ip4/127.0.0.1/tcp/5005
fi

if [[ ! -z $(docker ps | grep perplexica) ]]; then
    # Node offre Perplexica - crée x_perplexica.sh
    ipfs p2p listen /x/perplexica-${IPFSNODEID} /ip4/127.0.0.1/tcp/3001
fi
```

#### **Architecture de Découverte**

```bash
# Structure des fichiers de découverte
~/.zen/tmp/${IPFSNODEID}/
├── x_ollama.sh      # Script de connexion Ollama P2P
├── x_comfyui.sh    # Script de connexion ComfyUI P2P
├── x_orpheus.sh    # Script de connexion Orpheus P2P
├── x_perplexica.sh # Script de connexion Perplexica P2P
├── x_ssh.sh        # Script de connexion SSH P2P
└── x_strfry.sh     # Script de connexion Strfry P2P
```

#### **Fonction de Découverte des Nodes Swarm**

```bash
# Fonction commune pour tous les services
discover_swarm_nodes() {
    local service_name="$1"  # ollama, comfyui, perplexica, orpheus
    
    echo "Découverte des nodes $service_name dans le swarm..."
    
    # Vérifier node local
    if [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_$service_name.sh ]]; then
        echo "Node local $service_name trouvé: $IPFSNODEID"
    fi
    
    # Découvrir nodes swarm via DRAGON_p2p_ssh.sh
    for service_script in ~/.zen/tmp/swarm/*/x_$service_name.sh; do
        if [[ -f "$service_script" ]]; then
            local node_id=$(basename $(dirname "$service_script"))
            echo "Node swarm $service_name trouvé: $node_id"
        fi
    done
}
```

#### **Mécanisme de Publication des Services**

```bash
# DRAGON_p2p_ssh.sh - Publication automatique
# Chaque node publie ses services disponibles via IPFS P2P

# 1. DÉTECTION AUTOMATIQUE
# Le script détecte quels services sont actifs localement

# 2. CRÉATION DES SCRIPTS DE CONNEXION
# Pour chaque service détecté, création d'un script x_*.sh

# 3. PUBLICATION IPFS P2P
# Chaque service est publié sur un canal P2P dédié :
# /x/ollama-${IPFSNODEID}
# /x/comfyui-${IPFSNODEID}
# /x/orpheus-${IPFSNODEID}
# /x/perplexica-${IPFSNODEID}

# 4. DÉCOUVERTE PAR LES AUTRES NODES
# Les autres nodes peuvent découvrir ces services via :
# ipfs cat /ipns/${IPFSNODEID}/x_*.sh
```

#### **Load Balancing IPFS P2P**

```bash
# Fonction de sélection aléatoire des nodes
get_shuffled_nodes() {
    local service_name="$1"
    local nodes=()
    
    # Collecter tous les scripts disponibles
    for service_script in ~/.zen/tmp/swarm/*/x_$service_name.sh; do
        if [[ -f "$service_script" ]]; then
            nodes+=("$service_script")
        fi
    done
    
    # Mélanger aléatoirement
    printf '%s\n' "${nodes[@]}" | sort -R
}
```

#### **Gestion des Connexions P2P**

```bash
# Fonction commune pour fermer les connexions P2P
close_p2p_connections() {
    local service_name="$1"
    local closed=0
    
    # Fermer toutes les connexions du service
    for conn in $(ipfs p2p ls | grep "/x/$service_name-" | awk '{print $1}'); do
        echo "Fermeture connexion P2P: $conn"
        if ipfs p2p close -p "$conn"; then
            closed=$((closed + 1))
        fi
    done
    
    echo "Fermé $closed connexions $service_name"
}
```

#### **Migration Progressive**

##### **Phase 1: Dual Mode (Actuel)**
- SSH tunnels pour compatibilité
- IPFS P2P pour Orpheus (déjà implémenté)
- Tests en parallèle

##### **Phase 2: Migration Complète**
- Tous services via IPFS P2P
- Suppression des tunnels SSH
- Load balancing automatique

##### **Phase 3: Optimisation**
- Cache des connexions P2P
- Monitoring des performances
- Auto-scaling des nodes

#### **Configuration Production ẐEN[0]**

```bash
# Variables d'environnement pour IPFS P2P
IPFS_P2P_ENABLED=true
SWARM_DISCOVERY_ENABLED=true
LOAD_BALANCING_ENABLED=true

# Ports P2P (même ports locaux, mais via IPFS)
OLLAMA_P2P_PORT=11434
COMFYUI_P2P_PORT=8188
PERPLEXICA_P2P_PORT=3001
ORPHEUS_P2P_PORT=5005
```

#### **Avantages de la Migration**

1. **Résilience** - Plus de point de défaillance unique
2. **Scalabilité** - Ajout automatique de nodes
3. **Sécurité** - Chiffrement end-to-end IPFS
4. **Performance** - Connexions directes P2P
5. **Décentralisation** - Architecture vraiment distribuée

Cette migration vers IPFS P2P transformera UPlanet en une plateforme IA véritablement décentralisée et résiliente.

### 9. Rôle Central de DRAGON_p2p_ssh.sh

#### **Système de Découverte Automatique**

`DRAGON_p2p_ssh.sh` est le **système nerveux central** du swarm UPlanet. Il fonctionne comme un **service registry distribué** qui :

1. **Détecte automatiquement** les services disponibles sur chaque node
2. **Publie les services** via IPFS P2P sur des canaux dédiés
3. **Génère les scripts de connexion** pour les autres nodes
4. **Maintient la découverte** en temps réel du swarm

#### **Détection des Services par Node**

```bash
# DRAGON_p2p_ssh.sh - Détection automatique des services

# OLLAMA (Port 11434)
if [[ ! -z $(pgrep ollama) ]]; then
    echo "Node ${IPFSNODEID} offre Ollama"
    ipfs p2p listen /x/ollama-${IPFSNODEID} /ip4/127.0.0.1/tcp/11434
    # Crée ~/.zen/tmp/${IPFSNODEID}/x_ollama.sh
fi

# COMFYUI (Port 8188)
if [[ ! -z $(systemctl status comfyui.service | grep "active (running)") ]]; then
    echo "Node ${IPFSNODEID} offre ComfyUI"
    ipfs p2p listen /x/comfyui-${IPFSNODEID} /ip4/127.0.0.1/tcp/8188
    # Crée ~/.zen/tmp/${IPFSNODEID}/x_comfyui.sh
fi

# ORPHEUS (Port 5005)
if [[ ! -z $(docker ps | grep orpheus) ]]; then
    echo "Node ${IPFSNODEID} offre Orpheus TTS"
    ipfs p2p listen /x/orpheus-${IPFSNODEID} /ip4/127.0.0.1/tcp/5005
    # Crée ~/.zen/tmp/${IPFSNODEID}/x_orpheus.sh
fi

# PERPLEXICA (Port 3001)
if [[ ! -z $(docker ps | grep perplexica) ]]; then
    echo "Node ${IPFSNODEID} offre Perplexica"
    ipfs p2p listen /x/perplexica-${IPFSNODEID} /ip4/127.0.0.1/tcp/3001
    # Crée ~/.zen/tmp/${IPFSNODEID}/x_perplexica.sh
fi
```

#### **Génération des Scripts de Connexion**

Chaque service détecté génère un script de connexion P2P :

```bash
# Exemple : x_ollama.sh généré automatiquement
#!/bin/bash
if [[ ! $(ipfs p2p ls | grep x/ollama-${IPFSNODEID}) ]]; then
    ipfs --timeout=10s ping -n 4 /p2p/${IPFSNODEID}
    [[ $? == 0 ]] \
        && ipfs p2p forward /x/ollama-${IPFSNODEID} /ip4/127.0.0.1/tcp/11434 /p2p/${IPFSNODEID} \
        && echo "OLLAMA PORT FOR ${IPFSNODEID}" \
        && export OLLAMA_API_BASE="http://127.0.0.1:11434" \
        || echo "CONTACT IPFSNODEID FAILED - ERROR -"
else
    echo "Tunnel /x/ollama 11434 already active..."
fi
```

#### **Architecture de Découverte Distribuée**

```bash
# Structure du système de découverte
~/.zen/tmp/
├── ${IPFSNODEID}/                    # Node local
│   ├── x_ollama.sh                  # Script connexion Ollama
│   ├── x_comfyui.sh                 # Script connexion ComfyUI
│   ├── x_orpheus.sh                 # Script connexion Orpheus
│   ├── x_perplexica.sh              # Script connexion Perplexica
│   ├── x_ssh.sh                     # Script connexion SSH
│   └── x_strfry.sh                  # Script connexion Strfry
└── swarm/                           # Nodes découverts
    ├── node1/
    │   ├── x_ollama.sh              # Node1 offre Ollama
    │   └── x_comfyui.sh             # Node1 offre ComfyUI
    ├── node2/
    │   ├── x_orpheus.sh             # Node2 offre Orpheus
    │   └── x_perplexica.sh         # Node2 offre Perplexica
    └── node3/
        └── x_ollama.sh              # Node3 offre Ollama
```

#### **Avantages du Système DRAGON**

1. **Découverte Automatique**
   - Pas de configuration manuelle des services
   - Détection en temps réel des services disponibles
   - Mise à jour automatique du registry

2. **Load Balancing Intelligent**
   - Sélection automatique du meilleur node disponible
   - Rotation entre les nodes pour équilibrer la charge
   - Fallback automatique en cas de défaillance

3. **Résilience Distribuée**
   - Aucun point de défaillance unique
   - Services redondants sur plusieurs nodes
   - Récupération automatique des connexions

4. **Sécurité P2P**
   - Connexions chiffrées end-to-end via IPFS
   - Authentification par clés IPFS
   - Pas d'exposition de ports publics

#### **Intégration avec UPlanet IA**

```bash
# UPlanet_IA_Responder.sh - Utilisation du système DRAGON
# Au lieu de tunnels SSH, utilisation des scripts x_*.sh

# Ollama via IPFS P2P
if ! $MY_PATH/ollama.me.sh; then
    # ollama.me.sh utilise maintenant les scripts x_ollama.sh
    # Découverte automatique via DRAGON_p2p_ssh.sh
fi

# ComfyUI via IPFS P2P
if [[ "${TAGS[image]}" == true ]]; then
    $MY_PATH/comfyui.me.sh
    # comfyui.me.sh utilise les scripts x_comfyui.sh
fi
```

Ce système transforme UPlanet en une **plateforme IA véritablement décentralisée** où chaque node peut offrir ses services au swarm, et où la découverte et la connexion se font automatiquement via IPFS P2P.

### 8. Intégration avec UPlanet

#### **Déclenchement des Vérifications (Version Future)**
```bash
# Dans UPlanet_IA_Responder.sh - Version IPFS P2P
if ! $MY_PATH/ollama.me.sh; then
    echo "Error: Failed to maintain Ollama P2P connection" >&2
    exit 1
fi

# Vérifications spécialisées selon tags (toutes via IPFS P2P)
if [[ "${TAGS[search]}" == true ]]; then
    $MY_PATH/perplexica.me.sh  # Via IPFS P2P
fi

if [[ "${TAGS[image]}" == true ]]; then
    $MY_PATH/comfyui.me.sh     # Via IPFS P2P
fi
```

Cette architecture future garantit une décentralisation complète des services IA via IPFS P2P, éliminant toute dépendance aux serveurs centralisés.
