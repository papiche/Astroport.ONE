# Commandes du Capitaine — `~/.local/bin`

Astroport.ONE installe ses outils comme des **liens symboliques** dans `~/.local/bin/` — pas d'alias `.bashrc`, pas de modification du PATH au-delà du bloc `ASTROPORT`. Chaque lien est un outil autonome, exécutable directement depuis n'importe quel terminal.

---

## Inventaire des symlinks installés

Créés par `install/install_system.sh` lors de l'installation bare-metal, et vérifiés/réparés chaque nuit par `20h12.process.sh`.

| Commande | Cible | Rôle |
|----------|-------|------|
| `station-info` | `admin/system/station-info.sh` | Affiche les portefeuilles coopératifs ZEN.ECONOMY et l'état de la station |
| `astrosystemctl` | `admin/system/astrosystemctl.sh` | CLI P2P cloud : list, connect, enable, disable, status |
| `codebase_index.sh` | `admin/ia_db/codebase_index.sh` | Indexe le code source dans Qdrant (nomic-embed-text) |
| `knowledge_index.sh` | `admin/ia_db/knowledge_index.sh` | Indexe les connaissances (.md, .pdf, NOSTR) dans Qdrant |
| `heartbox_analysis.sh` | `admin/monitor/heartbox_analysis.sh` | Analyse hardware (CPU/RAM/GPU/Power-Score), génère `heartbox_analysis.json` |
| `captain` | `captain.sh` | CLI de gestion de la station (raccourci `command.sh`) |
| `tunnel.sh` | `tunnel.sh` | Gestion des tunnels IPFS P2P persistants |
| `cpcode` | `cpcode` | Publication code → IPFS (commit helper) |
| `cpscript` | `cpscript` | Déploiement script → IPFS |
| `natools` | `tools/natools.py` | Opérations crypto NaCl (chiffrement, signature) |
| `keygen` | `tools/keygen` | Générateur de clés déterministe (G1, IPFS, NOSTR) |
| `gcli` | `$(which gcli)` | CLI Duniter v2s (transactions Ğ1) |

---

## Audit automatique — `~/.zen/.astro`

À chaque passage du cron 20h12, `20h12.process.sh` :

1. **Inventorie** tous les symlinks de `~/.local/bin/`
2. **Détecte** les liens cassés (cible absente)
3. **Répare** automatiquement si le script est retrouvé dans `admin/` ou `tools/`
4. **Journalise** dans `~/.zen/.astro`

```
=== ~/.local/bin SYMLINK AUDIT — 2026-05-20 20:12 ===
  OK      station-info -> /home/fred/.zen/Astroport.ONE/admin/system/station-info.sh
  OK      astrosystemctl -> ...
  BROKEN  knowledge_index.sh -> .../tools/knowledge_index.sh   ← ancienne cible
  FIXED   knowledge_index.sh -> .../admin/ia_db/knowledge_index.sh
  TOTAL: 12 OK, 1 broken (1 auto-réparés)
==========================================================
```

Le fichier `~/.zen/.astro` est un **journal permanent** des outils présents sur la station — il révèle les fonctionnalités activées par le Capitaine (IA, indexation, tunnels, etc.).

```bash
# Consulter l'inventaire du Capitaine
cat ~/.zen/.astro

# Vérifier manuellement les liens cassés
for f in ~/.local/bin/*; do [ -L "$f" ] && [ ! -e "$f" ] && echo "BROKEN: $f"; done
```

---

## Ajouter un outil (convention)

Pour qu'un nouveau script soit accessible comme commande :

```bash
# Dans install/install_system.sh — ajouter une ligne :
ln -f -s ${ASTRO}/admin/system/mon-outil.sh ~/.local/bin/mon-outil
```

Le script devient alors disponible comme commande `mon-outil` dans tout terminal où `~/.local/bin` est dans le PATH (ajouté par le bloc ASTROPORT dans `.bashrc`).

---

## Voir aussi

- [ASTROSYSTEMCTL.md](ASTROSYSTEMCTL.md) — utilisation de `astrosystemctl`
- [KNOWLEDGE_EMBEDDINGS.md](KNOWLEDGE_EMBEDDINGS.md) — utilisation de `knowledge_index.sh`
- [CODEBASE_EMBEDDINGS.md](CODEBASE_EMBEDDINGS.md) — utilisation de `codebase_index.sh`
- [POWER_MONITORING.md](POWER_MONITORING.md) — utilisation de `heartbox_analysis.sh`
