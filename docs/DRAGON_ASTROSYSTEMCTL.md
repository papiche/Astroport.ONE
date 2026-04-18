<!-- SPDX-License-Identifier: AGPL-3.0 -->
# 🐉 DRAGON & astrosystemctl — Guide pratique

> Comprendre ce que ta station publie, partage et consomme dans la constellation Astroport.

---

## Le DRAGON en deux mots

À chaque démarrage quotidien (~20h12), le script **`DRAGON_p2p_ssh.sh`** :

1. **Détecte** les services actifs sur ta machine (Ollama, ComfyUI, Qdrant…)
2. **Ouvre** des canaux IPFS P2P pour les rendre accessibles aux autres stations
3. **Génère** des scripts `x_service.sh` que les autres stations peuvent exécuter pour se connecter
4. **Publie** l'ensemble dans ta balise IPNS (`/ipns/$IPFSNODEID`)

Les autres stations de la constellation font pareil → chacune peut utiliser les services de ses pairs **sans ouvrir de ports**, uniquement via le swarm IPFS.

```
Ta station                          Constellation
──────────────────────────         ──────────────────────────
  ollama:11434 ──► DRAGON ──►      /x/ollama-TONID  ──► scorpio, alienware…
  comfyui:8188 ──► DRAGON ──►      /x/comfyui-TONID ──► …
  strfry:7777  ──► DRAGON ──►      /x/strfry-TONID  ──► …  (relay NOSTR)
```

---

## `astrosystemctl` — La télécommande

```bash
astrosystemctl --help        # Aide complète
astrosystemctl list          # Ce que tu AS localement
astrosystemctl status        # Ce que tu PUBLIES et CONSOMMES en ce moment
astrosystemctl list-remote   # Ce que la constellation OFFRE
```

---

## 1. Ce que tu as installé — `list` et `local`

```bash
astrosystemctl list
```
Affiche le **Power-Score** de ta station et l'état de chaque service.

| Score | Profil | Rôle automatique |
|-------|--------|-----------------|
| 0–10  | 🌿 Light   | Consommateur (RPi, petit serveur) |
| 11–40 | ⚡ Standard | Peut héberger de petits modèles |
| 41+   | 🔥 Brain    | Fournisseur GPU pour la constellation |

```bash
astrosystemctl local               # Tableau de bord services IA détaillé
astrosystemctl local start ollama  # Démarrer Ollama localement
astrosystemctl local stop  ollama  # Arrêter
astrosystemctl local install       # Installer la stack IA complète (docker)
astrosystemctl local install dify  # Installer un service spécifique
```

---

## 2. Ce que tu partages — `status` et `local hide/share`

```bash
astrosystemctl status
```

Affiche trois sections :

- **SERVICES PUBLIÉS AU SWARM** — canaux `ipfs p2p listen` actifs sur ta machine
- **SERVICES DISTANTS CONSOMMÉS** — tunnels vers d'autres stations ouverts depuis toi
- **TUNNELS PERSISTANTS** — ceux que le watchdog 20h12 relance automatiquement

### Rendre un service privé (ne pas le partager)

```bash
astrosystemctl local hide ollama         # Ollama non visible du swarm
astrosystemctl local hide qdrant         # Qdrant privé (données sensibles)
astrosystemctl local priv                # Voir la liste des services privés
```

### Remettre en partage

```bash
astrosystemctl local share ollama        # Ollama de nouveau partagé
```

> Ces commandes modifient `DRAGON_PRIVATE_SERVICES` dans `~/.zen/Astroport.ONE/.env`.
> Le changement est pris en compte au prochain cycle DRAGON (~20h12) ou manuellement :
> ```bash
> ~/.zen/Astroport.ONE/RUNTIME/DRAGON_p2p_ssh.sh
> ```

---

## 3. Ce que tu consommes — `list-remote` et `connect`

```bash
astrosystemctl list-remote             # Catalogue des Brain-Nodes disponibles
astrosystemctl list-remote ollama      # Filtrer par service
```

Exemple de sortie :
```
=== SERVICES SWARM (P2P) ===

  SERVICE            NODE (fin)               POWER        MODÈLES/CAPITAINE      LATENCE
  ─────────────────────────────────────────────────────────────────────────────────────────
  ollama             ...WAvWxP8nKqM5rT        52 🔥 Brain  llama3.2,mistral       8ms
  comfyui            ...WAvWxP8nKqM5rT        52 🔥 Brain  alienware              12ms
  ollama             ...ikSHoDD581Jz9L        38 ⚡ Std    phi3                   45ms
```

### Se connecter à un service distant

```bash
astrosystemctl connect ollama              # Meilleur nœud automatique
astrosystemctl connect ollama@12D3KooW…   # Nœud précis
```

Le tunnel IPFS est ouvert et le service devient accessible sur `http://127.0.0.1:11434`.

---

## 4. Rendre une connexion permanente — `enable` / `disable`

```bash
astrosystemctl enable ollama               # Watchdog actif → tunnel relancé à chaque 20h12
astrosystemctl enable comfyui@12D3KooW…   # Épingler un nœud précis

astrosystemctl disable ollama              # Retirer du watchdog
```

Les tunnels persistants sont stockés dans `~/.zen/tunnels/enabled/`.
Le watchdog de `20h12.process.sh` les vérifie et les relance s'ils sont tombés.

```bash
# Vérifier l'état des tunnels persistants
astrosystemctl status
```

---

## 5. Récapitulatif des flux

```
INSTALLER            PARTAGER             CONSOMMER
─────────────        ─────────────        ─────────────
local install  →     (automatique si      list-remote
local start          actif)               connect
                     local hide/share     enable (persistant)
```

---

## Dépannage rapide

| Symptôme | Commande de diagnostic |
|----------|------------------------|
| Service non visible dans `list-remote` | `astrosystemctl status` → DRAGON actif ? |
| Tunnel `OFF` dans `tunnel.sh` | `ipfs p2p ls` — `ipfs --timeout=15s ping /p2p/NODEID` |
| Service absent de `local list` | `heartbox_analysis.sh update` puis réessayer |
| Ollama local ignoré, tunnel ouvert quand même | `_is_native_process` : vérifier `lsof -Pi :11434` |
| Tunnel persistant non relancé | `cat ~/.zen/tmp/tunnel.log` |

---

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| `RUNTIME/DRAGON_p2p_ssh.sh` | Publie les services, génère `x_*.sh`, met à jour `authorized_keys` |
| `tools/astrosystemctl.sh` | CLI de gestion (symlink `~/.local/bin/astrosystemctl`) |
| `~/.zen/tunnels/enabled/` | Tunnels persistants (watchdog 20h12) |
| `~/.zen/Astroport.ONE/.env` | Config : `DRAGON_PRIVATE_SERVICES`, `SWARM_REMOTE_HOST` |
| `~/.zen/tmp/$IPFSNODEID/x_*.sh` | Scripts tunnel générés par DRAGON |
| `~/.zen/tmp/swarm/*/x_*.sh` | Scripts tunnel des autres stations |

> Documentation complète : [DRAGONS_and_TUNNELS.md](DRAGONS_and_TUNNELS.md)
