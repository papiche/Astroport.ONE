# Gestion des Connexions et Vérifications des Services IA - UPlanet

## Architecture de Gestion des Connexions

Le système UPlanet IA utilise une architecture de gestion des connexions en plusieurs niveaux pour s'assurer que tous les services IA sont disponibles avant de traiter les requêtes.

### 1. Services IA Gérés

#### **Ollama (Port 11434)**
- **Script**: `ollama.me.sh`
- **Vérification**: `netstat -tulnp | grep 11434`
- **Test API**: `curl http://localhost:11434/api/tags`
- **Tunnel SSH**: `scorpio.copylaradio.com` (IPv4:2122, IPv6:22)
- **Fallback**: IPFS P2P swarm discovery
- **Usage**: Réponses IA conversationnelles, analyse d'images

#### **ComfyUI (Port 8188)**
- **Script**: `comfyui.me.sh`
- **Vérification**: `netstat -tulnp | grep 8188`
- **Test API**: `curl http://localhost:8188/system_stats`
- **Tunnel SSH**: `scorpio.copylaradio.com` (IPv4:2122, IPv6:22)
- **Fallback**: IPFS P2P swarm discovery
- **Usage**: Génération d'images, vidéos, musique

#### **Perplexica (Port 3001)**
- **Script**: `perplexica.me.sh`
- **Vérification**: `netstat -tulnp | grep 3001`
- **Test API**: `curl http://localhost:3001/api/providers`
- **Tunnel SSH**: `scorpio.copylaradio.com` (IPv4:2122, IPv6:22)
- **Fallback**: IPFS P2P swarm discovery
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
│   └── ollama.me.sh (mode auto-connect)
│       ├── Check port 11434 + test API
│       ├── Si OK → Connexion active, continuer
│       ├── Sinon → Tentative SSH (IPv6 puis IPv4)
│       ├── Si SSH échoue → Fallback IPFS P2P swarm
│       └── Exit si tous échecs
│
├── 2. Vérifications Spécialisées (selon tags)
│   ├── #search → perplexica.me.sh
│   │   ├── Check port 3001 + test API /api/providers
│   │   ├── Si OK → Connexion active
│   │   ├── Sinon → Tentative SSH (IPv6 puis IPv4)
│   │   └── Si SSH échoue → Fallback IPFS P2P swarm
│   │
│   ├── #image/#video/#music → comfyui.me.sh
│   │   ├── Check port 8188 + test API /system_stats
│   │   ├── Si OK → Connexion active
│   │   ├── Sinon → Tentative SSH (IPv6 puis IPv4)
│   │   └── Si SSH échoue → Fallback IPFS P2P swarm
│   │
│   └── #pierre/#amelie → generate_speech.sh → orpheus.me.sh
│       ├── Check Docker + port 5005 + test API /docs
│       ├── Si OK → Connexion locale active
│       └── Sinon → Fallback IPFS P2P swarm (pas de SSH)
│
└── 3. Traitement de la Requête
    ├── Si toutes connexions OK → Exécution
    └── Si échec → Message d'erreur
```

#### **Ordre de Priorité des Connexions (Tous Services)**

Chaque script `*.me.sh` suit cet ordre de priorité lors de l'auto-connexion :

1. **Vérification connexion existante**
   - Port ouvert + API répond → Utilisation directe
   
2. **Service local** (si disponible)
   - Processus/service actif localement → Connexion locale
   
3. **Tunnel SSH** (sauf Orpheus)
   - Tentative IPv6 en premier (port 22)
   - Fallback IPv4 si IPv6 indisponible (port 2122)
   - Connexion vers `scorpio.copylaradio.com`
   
4. **IPFS P2P Swarm** (tous services)
   - Découverte automatique des nodes disponibles
   - Sélection du premier node disponible
   - Support sélection manuelle (numéro, ID, aléatoire)

**Note spéciale :** Orpheus TTS n'utilise **pas** de tunnel SSH, uniquement LOCAL et IPFS P2P.

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

#### **Établissement de Tunnel SSH (IPv6/IPv4)**
```bash
establish_ssh_tunnel() {
    local protocol="${1:-auto}"  # auto, ipv6, ipv4
    
    # Essai IPv6 en premier (plus rapide si disponible)
    if [[ "$protocol" == "auto" || "$protocol" == "ipv6" ]]; then
        if check_ipv6_available; then
            ssh -fN -L 127.0.0.1:$LOCAL_PORT:127.0.0.1:$REMOTE_PORT \
                -6 $USER@$HOST -p $SSH_PORT_IPV6
            return $?
        fi
    fi
    
    # Fallback IPv4
    if [[ "$protocol" == "auto" || "$protocol" == "ipv4" ]]; then
        ssh -fN -L 127.0.0.1:$LOCAL_PORT:127.0.0.1:$REMOTE_PORT \
            -4 $USER@$HOST -p $SSH_PORT_IPV4
        return $?
    fi
}
```

#### **Connexion IPFS P2P (Tous Services)**
```bash
connect_via_swarm() {
    local service_name="$1"  # ollama, comfyui, perplexica, orpheus
    local target="${2:-}"    # auto, <numéro>, <node_id>
    
    # Collecte des nodes disponibles
    local nodes=()
    for script in ~/.zen/tmp/swarm/*/x_${service_name}.sh; do
        [[ -f "$script" ]] && nodes+=("$script")
    done
    
    # Ajout du node local si disponible
    if [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${service_name}.sh ]]; then
        nodes+=("$HOME/.zen/tmp/$IPFSNODEID/x_${service_name}.sh")
    fi
    
    # Sélection du node (auto, numéro, ID, ou premier disponible)
    local selected_script=""
    case "$target" in
        "auto"|"random")
            selected_script=$(printf '%s\n' "${nodes[@]}" | sort -R | head -1)
            ;;
        [0-9]*)
            local idx=$((target - 1))
            selected_script="${nodes[$idx]}"
            ;;
        *)
            # Recherche par ID partiel
            for script in "${nodes[@]}"; do
                local node_id=$(basename $(dirname "$script"))
                [[ "$node_id" == *"$target"* ]] && selected_script="$script" && break
            done
            ;;
    esac
    
    # Établissement de la connexion P2P
    [[ -n "$selected_script" ]] && bash "$selected_script"
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
- Support dual-stack IPv6/IPv4 avec fallback automatique
- Détection automatique de la meilleure méthode (IPv6 prioritaire)
- Load balancing sur les nodes swarm (tous services)
- Sélection de nodes P2P par numéro, ID ou aléatoire
- Fichiers de statut pour suivi des connexions

### 6. Configuration des Services

#### **Variables d'Environnement**
```bash
# Ollama
OLLAMA_PORT=11434
REMOTE_HOST="scorpio.copylaradio.com"
REMOTE_PORT_IPV4=2122  # Port pour accès IPv4 NAT
REMOTE_PORT_IPV6=22     # Port pour accès IPv6 direct

# ComfyUI
COMFYUI_PORT=8188
COMFYUI_URL="http://127.0.0.1:8188"
REMOTE_HOST="scorpio.copylaradio.com"
REMOTE_PORT_IPV4=2122
REMOTE_PORT_IPV6=22

# Perplexica
PERPLEXICA_PORT=3001
REMOTE_HOST="scorpio.copylaradio.com"
REMOTE_PORT_IPV4=2122
REMOTE_PORT_IPV6=22

# Orpheus (pas de SSH)
ORPHEUS_PORT=5005
# Orpheus utilise uniquement LOCAL et IPFS P2P
```

#### **Scripts de Maintenance**
- `ollama.me.sh OFF` - Fermer tunnel Ollama
- `comfyui.me.sh OFF` - Fermer tunnel ComfyUI
- `perplexica.me.sh OFF` - Fermer tunnel Perplexica
- `orpheus.me.sh OFF` - Fermer connexions IPFS P2P

#### **Commandes Avancées Disponibles**

Tous les scripts `*.me.sh` supportent des commandes avancées :

- **`STATUS`** - Affiche le statut de connexion actuel (LOCAL/SSH/P2P)
- **`SCAN`** - Détecte toutes les connexions disponibles (LOCAL, SSH, P2P)
- **`LOCAL`** - Force la connexion via service local uniquement
- **`SSH`** - Force la connexion via tunnel SSH (auto IPv6/IPv4)
- **`SSH6`** - Force la connexion via tunnel SSH IPv6 uniquement
- **`SSH4`** - Force la connexion via tunnel SSH IPv4 uniquement
- **`P2P`** - Connecte via IPFS P2P (affiche les nodes si multiples)
- **`P2P <n>`** - Connecte au node P2P numéro n (1, 2, 3...)
- **`P2P <id>`** - Connecte au node P2P par ID (correspondance partielle)
- **`P2P auto`** - Sélection aléatoire d'un node P2P
- **`MODELS`** - Liste les modèles disponibles (Ollama uniquement)
- **`TEST`** - Teste la connexion API actuelle
- **`HELP`** - Affiche l'aide complète

**Exemples :**
```bash
ollama.me.sh STATUS      # Voir le statut actuel
ollama.me.sh SCAN        # Scanner toutes les options
ollama.me.sh P2P 1       # Connecter au node P2P #1
comfyui.me.sh SSH6       # Forcer connexion SSH IPv6
perplexica.me.sh P2P auto # Sélection aléatoire P2P
```

#### **Fichiers de Statut de Connexion**

Chaque script sauvegarde le statut de connexion dans :
```
~/.zen/tmp/{service}_connection.status
```

**Contenu du fichier :**
```bash
CONNECTION_TYPE=SSH_IPv6|SSH_IPv4|P2P|LOCAL
CONNECTION_DETAILS=scorpio.copylaradio.com:22|node_id|Local service
CONNECTION_TIME=2026-01-24T10:30:45+00:00
CONNECTION_PORT=11434|8188|3001|5005
```

Ces fichiers permettent de :
- Suivre l'historique des connexions
- Identifier rapidement le type de connexion active
- Détecter les problèmes de connexion
- Optimiser la sélection de méthode de connexion

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

**Note**: Le script existe dans `RUNTIME/DRAGON_p2p_ssh.sh`. La version actuelle gère principalement le **SSH over IPFS P2P** (canal `/x/ssh-*`, clés `y_ssh.pub`/`z_ssh.pub`). La détection automatique de tous les services (Ollama, ComfyUI, Orpheus, Perplexica) et la génération des `x_ollama.sh`, `x_comfyui.sh`, etc. correspondent à l’**architecture cible** décrite ci‑dessous.

#### **Système de Découverte Automatique (cible)**

`DRAGON_p2p_ssh.sh` est conçu comme le **système nerveux central** du swarm UPlanet. Il fonctionne comme un **service registry distribué** qui :

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

#### **Déclenchement des Vérifications (Implémenté)**
```bash
# Dans UPlanet_IA_Responder.sh - au démarrage (après source my.sh)
# Vérification Ollama OBLIGATOIRE au démarrage
if ! $MY_PATH/ollama.me.sh; then
    echo "Error: Failed to maintain Ollama connection" >&2
    exit 1
fi

# Vérifications spécialisées selon tags détectés (dans le bloc des commandes)
# #search → perplexica.me.sh (puis comfyui.me.sh pour l'illustration)
# #image / #video / #music → comfyui.me.sh
# #pierre / #amelie → generate_speech.sh (qui appelle orpheus.me.sh en interne)
if [[ "${TAGS[search]}" == true ]]; then
    $MY_PATH/perplexica.me.sh  # Auto: LOCAL → SSH → P2P
fi

if [[ "${TAGS[image]}" == true || "${TAGS[video]}" == true || "${TAGS[music]}" == true ]]; then
    $MY_PATH/comfyui.me.sh     # Auto: LOCAL → SSH → P2P
fi

if [[ "${TAGS[pierre]}" == true || "${TAGS[amelie]}" == true ]]; then
    # generate_speech.sh appelle orpheus.me.sh en interne
    $MY_PATH/generate_speech.sh "$text" "$voice"  # Auto: LOCAL → P2P (pas SSH)
fi
```

#### **Architecture Actuelle (Dual Mode)**

L'architecture actuelle supporte **deux modes de connexion** :

1. **Mode SSH** (compatibilité)
   - Tunnels SSH IPv6/IPv4 vers `scorpio.copylaradio.com`
   - Utilisé si disponible et si P2P non configuré
   - Fallback automatique vers P2P si SSH échoue

2. **Mode IPFS P2P** (décentralisé)
   - Découverte automatique via `DRAGON_p2p_ssh.sh`
   - Connexions directes entre nodes du swarm
   - Load balancing automatique
   - Utilisé en priorité si nodes disponibles

**Avantages du Dual Mode :**
- Résilience : Si SSH échoue, P2P prend le relais
- Flexibilité : Support des deux architectures
- Migration progressive : Transition douce vers P2P complet
- Compatibilité : Fonctionne même sans nodes P2P disponibles

Cette architecture garantit une disponibilité maximale des services IA avec décentralisation progressive via IPFS P2P.
