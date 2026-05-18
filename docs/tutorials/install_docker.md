# Installer Astroport.ONE avec Docker

**Public :** utilisateur souhaitant tester ou déployer sans modifier son système Linux.
**Résultat :** stack Astroport complète dans des conteneurs, accessible depuis le navigateur.

**Durée estimée :** 10–20 minutes.

---

## Prérequis

- Docker Engine 24+ et Docker Compose v2
- Linux 64-bit (ou Mac/Windows avec Docker Desktop)
- Ports libres : 80, 443, 81, 12345, 54321, 7777, 8080

```bash
# Vérifier Docker
docker --version && docker compose version
```

---

## Étapes

### 1. Cloner le dépôt

```bash
git clone https://github.com/papiche/Astroport.ONE.git
cd Astroport.ONE/docker/
```

### 2. Choisir un profil et démarrer

| Profil | Commande | Ce qu'il lance |
|--------|----------|----------------|
| Standard | `docker compose up -d` | Astroport + NPM (Nginx Proxy Manager) |
| + Cloud | `docker compose --profile cloud up -d` | + NextCloud AIO (128 Go/utilisateur) |
| + IA | `docker compose --profile ai up -d` | + Ollama, Open WebUI, Qdrant, Vane |
| Tout | `docker compose --profile full up -d` | cloud + ai + Watchtower |

```bash
# Exemple : profil standard
docker compose up -d

# Suivre les logs
docker compose logs -f astroport
```

### 3. Configurer le domaine (optionnel)

```bash
# Avec un domaine public
ASTRO_DOMAIN=mondomaine.fr docker compose up -d
```

Sans domaine, la station tourne sur `localhost` avec des certificats auto-signés.

### 4. Vérifier le démarrage

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Attendez que le conteneur `astroport` soit `healthy` (1–2 minutes).

---

## Résultat attendu

| URL | Service |
|-----|---------|
| `http://localhost:12345` | Carte de station Astroport |
| `http://localhost:54321` | UPassport API |
| `ws://localhost:7777` | Relay NOSTR strfry |
| `http://localhost:81` | Nginx Proxy Manager (admin SSL) |
| `http://localhost:8443` | NextCloud AIO setup (profil cloud) |
| `http://localhost:8000` | Open WebUI / #BRO (profil ai) |

---

## Variantes avancées

### Webtop (bureau dans le navigateur)

```bash
docker compose -f docker-compose.webtop.yml up -d
# → http://localhost:3000  (Ubuntu XFCE + KasmVNC)
```

### GPU NVIDIA (profil ai)

```bash
docker compose -f docker-compose.yml -f docker-compose.gpu.yml --profile ai up -d
```

### VirtualBox / Vagrant

```bash
vagrant up               # VM Ubuntu 22.04 complète
vagrant ssh              # Connexion
```

---

## Étapes suivantes

- [Architecture complète](../explanation/architecture_overview.md)
- [Gérer les services P2P](../how-to/ASTROSYSTEMCTL.md)
- [Rejoindre la constellation ẐEN](../explanation/ROLES.md)
