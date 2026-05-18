# Docker pour stations Astroport

**Auteur** : toto (support+toto@qo-op.com)  
**Skill** : docker  
**Niveau** : X1 — Fondamentaux  

---

## Pourquoi Docker sur une station Astroport ?

La stack complète d'Astroport tourne dans Docker : Qdrant (vectoriel), Ollama (IA),
Open WebUI (chat), Mirofish (opinions), rnostr (relay NOSTR), Nextcloud.
Comprendre Docker, c'est maîtriser la mise à l'échelle et la mise à jour de la station.

---

## 1. La stack Astroport Docker

```bash
# Démarrer le core (astroport + nginx proxy manager)
docker compose up -d

# Démarrer la stack IA (+ Qdrant + Ollama + Open WebUI)
docker compose --profile ai up -d

# Démarrer tout
docker compose --profile full up -d

# Avec GPU NVIDIA
docker compose -f docker-compose.yml -f docker-compose.gpu.yml \
    --profile ai up -d
```

---

## 2. Réseau dragon-net

Tous les services Astroport partagent le réseau bridge `dragon-net`.
Les services se joignent **par nom de conteneur** (pas par IP) :

```bash
# Depuis un conteneur, accéder à Qdrant
curl http://astroport-qdrant:6333/healthz

# Accéder à Ollama
curl http://astroport-ollama:11434/api/tags

# Depuis l'hôte, utiliser 127.0.0.1 (port binding)
curl http://127.0.0.1:6333/healthz
```

---

## 3. Profils et variables d'environnement

La configuration est dans `~/.zen/ai-company/.env` (généré par `install-ai-company.docker.sh`) :

```bash
# Voir les variables en place
cat ~/.zen/ai-company/.env

# Contenu type :
QDRANT_API_KEY=60e05bd1b195...   # sha256(UPLANETNAME)
WEBUI_SECRET_KEY=abc123...
MIROFISH_MODEL=gemma3:12b
```

Passer l'env-file à docker compose :
```bash
docker compose \
    --env-file ~/.zen/ai-company/.env \
    --profile ai up -d
```

---

## 4. Volumes et données persistantes

```bash
# Lister les volumes
docker volume ls | grep astroport

# Inspecter le volume Qdrant
docker volume inspect docker_qdrant_storage

# Sauvegarde manuelle d'un volume
docker run --rm \
    -v docker_qdrant_storage:/data \
    -v /tmp:/backup \
    alpine tar czf /backup/qdrant_backup.tar.gz /data
```

---

## 5. Mise à jour des conteneurs (Watchtower)

Astroport utilise Watchtower pour les mises à jour automatiques des images
marquées `com.centurylinklabs.watchtower.enable=true` :

```bash
# Démarrer avec auto-update
docker compose --profile updates up -d

# Forcer une mise à jour manuelle
docker compose pull && docker compose up -d

# Voir les logs Watchtower
docker logs astroport-watchtower --tail 20
```

---

## 6. Diagnostics courants

```bash
# Voir tous les conteneurs Astroport
docker ps --filter "name=astroport"

# Logs d'un service
docker logs astroport-qdrant --tail 50 -f

# Ressources consommées
docker stats --no-stream

# Entrer dans un conteneur
docker exec -it astroport bash

# Vérifier la santé
docker inspect astroport-qdrant --format '{{.State.Health.Status}}'
```

---

## 7. Exercice — Vérifier la stack complète

```bash
#!/bin/bash
# check_stack.sh — Vérification rapide de la stack Astroport

SERVICES=("astroport" "astroport-qdrant" "astroport-ollama")

for svc in "${SERVICES[@]}"; do
    if docker inspect "$svc" --format '{{.State.Running}}' 2>/dev/null | grep -q true; then
        echo "✓ $svc"
    else
        echo "✗ $svc — non démarré"
    fi
done

# Tester les endpoints
curl -sf http://127.0.0.1:6333/healthz && echo "✓ Qdrant OK"
curl -sf http://localhost:11434/api/tags && echo "✓ Ollama OK"
curl -sf http://localhost:12345/station  && echo "✓ Astroport OK"
```

---

## Ressources complémentaires

- `Astroport.ONE/docker/docker-compose.yml` — compose principal
- `Astroport.ONE/docker/docker-compose.gpu.yml` — overlay GPU NVIDIA
- `Astroport.ONE/install/install-ai-company.docker.sh` — génération des secrets IA
- [ASTROSYSTEMCTL.md](../../docs/how-to/ASTROSYSTEMCTL.md) — télécommande P2P des services
