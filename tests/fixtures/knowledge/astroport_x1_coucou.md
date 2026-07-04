# Opérer une station Astroport (PERMIT\_ASTROPORT\_X1)

**Auteur** : coucou (support+coucou@qo-op.com)\
**Skill** : astroport\
**Niveau** : X1 — Composite (linux + bash + docker)

***

## Qu'est-ce qu'une station Astroport ?

Une station Astroport est un serveur personnel décentralisé qui :

1. **Stocke** vos données sur IPFS (contenu-adressable, résilient)
2. **Publie** votre identité sur NOSTR (censorship-resistant)
3. **Coopère** dans la constellation UPlanet (swarm P2P)
4. **Héberge** des services IA souverains (Ollama, Qdrant, ComfyUI)

Le PERMIT\_ASTROPORT\_X1 est la compétence fondamentale pour opérer une station de manière autonome et contribuer à la constellation.

***

## Prérequis (craft composite)

```
PERMIT_LINUX_X1    ← bases système, processus, fichiers
PERMIT_BASH_X1     ← scripts, automatisation, outils Astroport
PERMIT_DOCKER_X1   ← conteneurs, stack IA, mises à jour
        ↓
PERMIT_ASTROPORT_X1
```

***

## 1. Architecture d'une station

```
Station Astroport
├── IPFS daemon          → stockage P2P, gateway /ipfs/:cid
├── strfry / rnostr      → relay NOSTR local (port 7777)
├── UPassport FastAPI    → API centrale (port 54321)
├── 12345.sh             → carte station (port 12345)
├── G1Billet             → portefeuilles Ğ1 (port 33101)
└── Stack IA (--profile ai)
    ├── Qdrant           → base vectorielle (port 6333)
    ├── Ollama           → LLM local (port 11434)
    └── Open WebUI       → interface chat (port 8000)
```

***

## 2. Démarrer et vérifier une station

```bash
# Démarrer
./start.sh

# Vérifier l'état
curl -s http://localhost:12345/station | jq '.status'

# Vérifier IPFS
ipfs id | jq '.ID'
ipfs swarm peers | wc -l

# Vérifier le relay NOSTR
curl -s http://localhost:7777 | jq '.name'
```

***

## 3. La carte station (12345.json)

Le script `_12345.sh` génère `~/.zen/tmp/$IPFSNODEID/12345.json` — la carte publiée sur IPNS. Elle contient :

```json
{
  "ipfsnodeid": "12D3KooW...",
  "domain": "station.example.tld",
  "captain": {
    "g1pub": "...",
    "email": "captain@example.tld"
  },
  "capacities": {
    "power_score": 42,
    "provider_ready": true,
    "gpu": "RTX3090:24GB",
    "models": ["llama3.2", "nomic-embed-text"]
  },
  "swarm": ["ipfsnodeid1", "ipfsnodeid2"]
}
```

***

## 4. Cycle de vie quotidien

```bash
# 20h12 : maintenance automatique (cron)
./20h12.process.sh

# Ce que ça fait :
# - Synchronise les MULTIPASS (NOSTRCARD.refresh.sh)
# - Paie les ZenCards (ZEN.ECONOMY.sh)
# - Synchronise les tunnels P2P actifs
# - Publie le rapport sur IPNS
```

***

## 5. Publier du contenu sur IPNS

```bash
# Ajouter un répertoire
CID=$(ipfs add -r -q ~/.zen/tmp/$IPFSNODEID/)

# Publier sur l'IPNS de la station
ipfs name publish --key="$IPFSNODEID" /ipfs/$CID

# Résultat accessible via :
# /ipns/$IPFSNODEID/12345.json
# https://ipfs.example.tld/ipns/$IPFSNODEID/
```

***

## 6. Rejoindre la constellation (backfill N²)

```bash
# Synchroniser les events NOSTR avec les autres stations
cd ../NIP-101
./backfill_constellation.sh --days 3 --verbose

# Voir les statistiques de sync
./backfill_constellation.sh --stats
```

***

## 7. Exercice de certification

Pour obtenir PERMIT\_ASTROPORT\_X1 :

1. **Installer** une station bare-metal ou Docker sur votre machine
2. **Vérifier** que la carte 12345.json est accessible publiquement
3. **Rejoindre** la constellation (au moins 3 pairs IPFS + relay NOSTR connecté)
4. **Publier** un Kind 1 sur le relay local et vérifier le backfill sur le relay remote
5. **Demander** la validation à un pair Astroport X1 existant (Kind 30501 → Kind 30502)

***

## Ressources complémentaires

* `Astroport.ONE/install.sh` — installation bare-metal
* `Astroport.ONE/docker/docker-compose.yml` — installation Docker
* `Astroport.ONE/tools/astrosystemctl.sh` — télécommande P2P
* [DRAGONS\_and\_TUNNELS.md](https://github.com/papiche/Astroport.ONE/blob/master/tests/docs/how-to/DRAGONS_and_TUNNELS.md) — découverte de services IA entre stations
* `tests/test_wotx2_demo.sh` — dataset de démonstration WoTx2 complet
