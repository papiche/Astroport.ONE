<!-- SPDX-License-Identifier: AGPL-3.0 -->
# 🐉 DRAGON & astrosystemctl — Guide pratique

> **Astroport.ONE** est une infrastructure décentralisée, souveraine et organique.
> Des nœuds égaux — ta **Station** — qui s'organisent sans chef d'orchestre, via IPFS + NOSTR.
> Voir : [astroport.one](http://astroport.one) (Pas besoin de SSL... on est passé à IPFS ! Accessible en local http://127.0.0.1:8080/ipns/astroport.one sur tous les Astroport de ta UPlanet)

---

## Philosophie : le Swarm of Equals

Chaque station est souveraine. Elle publie ce qu'elle a, consomme ce dont elle a besoin,
sans hiérarchie, sans cloud central. Les services circulent entre pairs via des **tunnels IPFS P2P**.

```
Ta station                          Constellation
──────────────────────────         ──────────────────────────
  ollama:11434 ──► DRAGON ──►      /x/ollama-TONID  ──► scorpio, alienware…
  comfyui:8188 ──► DRAGON ──►      /x/comfyui-TONID ──► …
  strfry:7777  ──► DRAGON ──►      /x/strfry-TONID  ──► …  (relay NOSTR)
```

**DRAGON_p2p_ssh.sh** fait ce travail chaque nuit (~20h12) : il détecte les services actifs,
ouvre des canaux IPFS P2P et génère des scripts `x_service.sh` utilisables par tes pairs.

**`astrosystemctl`** est la télécommande de tout ça — depuis le terminal.

---

## Niveaux de station (Power-Score)

Le **Power-Score** = `GPU_VRAM_GB × 4 + CPU_cœurs × 2 + RAM_GB × 0.5`

| Score | Profil | Ce que tu fais dans le swarm |
|-------|--------|------------------------------|
| 0–10  | 🌿 Light   | RPi, petit serveur — tu consommes les services des Brain-Nodes |
| 11–40 | ⚡ Standard | PC bureautique — tu héberges de petits modèles, tu partages |
| 41+   | 🔥 Brain    | GPU dédié — tu fournis de la puissance à la constellation |

Ton score est calculé par `tools/heartbox_analysis.sh` et publié dans ton `12345.json`.

---

## Démarrage rapide

```bash
# ← COMMENCER ICI : recommandations selon ton matériel
astrosystemctl local check

# Voir ta station et ses services
astrosystemctl list

# Voir ce que la constellation offre
astrosystemctl list-remote

# Se connecter à un service distant (ex: Ollama sur un Brain-Node)
astrosystemctl connect ollama

# Tableau de bord complet (services IA locaux + outils)
astrosystemctl local
```

---

## 1. Le conseiller — `local check`

```bash
astrosystemctl local check              # Analyse matériel + recommandations complètes
astrosystemctl local check webtop       # Vérifier un module spécifique
```

Exemple de sortie (laptop ⚡ Standard) :
```
=== RECOMMANDATIONS POUR CETTE STATION ===

  Power-Score : 18 ⚡ Std
  Ressources  : CPU 8 cœurs · RAM 16 Go · Disque libre 45 Go · Docker ✅

  MODULE                 PORT     STATUT         CONSEIL                COMMANDE
  ──────────────────────────────────────────────────────────────────────────────────
  icecast                8111     ⬜ non installé  ✅ OK                 local install icecast
  dify                   8010     ⬜ non installé  ✅ OK                 local install dify
  ollama                 11434    ⬜ non installé  ⚡ OK (CPU, petits)   local install ollama
  open-webui             8000     ⬜ non installé  ✅ OK                 local install open-webui
  qdrant                 6333     ⬜ non installé  ✅ OK                 local install qdrant
  comfyui                8188     ⬜ non installé  ❌ GPU requis (≥41)   (ou: connect comfyui)
  webtop-http            3000     ⬜ non installé  ✅ OK                 local install webtop
  youtube-antibot        -        ⬜ non installé  ✅ OK                 local install youtube-antibot
```

Le `check` croise ton **Power-Score** + tes ressources (RAM, disque, Docker) avec les prérequis de chaque module. Si le service est disponible dans le swarm, il l'indique aussi.

---

## 2. Ce que tu as installé — `list` et `local`

### `astrosystemctl list`

Affiche le Power-Score et l'état des services de ta station.

### `astrosystemctl local`

Tableau de bord détaillé en deux sections :

**Services IA** (avec connecteur `.me.sh` dans `IA/`) :

| Colonne | Signification |
|---------|---------------|
| SERVICE | Nom du service |
| PORT    | Port local |
| ÉTAT    | ✅ LOCAL · 🔗 P2P · 🔒 SSH · ❌ OFF |
| SOURCE  | local / p2p_tunnel / ssh_tunnel |
| PARTAGE | 🌐 Partagé au swarm · 🔒 Privé |
| ACTION  | start · stop · install |

**Outils système** (modules sans port P2P, gestion locale uniquement) :

Affiche les modules définis dans `IA/modules.list` dont le port est `-` : youtube-antibot,
powerjoular, prometheus, zelkova, leann…

```bash
astrosystemctl local                      # Vue d'ensemble
astrosystemctl local start ollama         # Démarrer Ollama
astrosystemctl local stop  ollama         # Arrêter
astrosystemctl local start open-webui     # Démarrer Open WebUI
```

---

## 3. Installer des services — `local install`

### Stack IA complète

```bash
astrosystemctl local install              # Installe Dify + Open WebUI + MiroFish + Qdrant…
```

### Service ou module individuel

```bash
astrosystemctl local install ollama          # Ollama (groupe gpu-ai)
astrosystemctl local install dify            # Dify AI Workflow (groupe ai-company)
astrosystemctl local install qdrant          # Qdrant VectorDB (groupe ai-company)
astrosystemctl local install comfyui         # ComfyUI (groupe gpu-ai, nécessite 🔥 Brain)
astrosystemctl local install youtube-antibot # Deno + EJS + bgutil (contournement anti-bot YouTube)
astrosystemctl local install powerjoular     # Monitoring consommation électrique
astrosystemctl local install prometheus      # Métriques Prometheus
astrosystemctl local install zelkova         # Wallet ẐEN Flutter PWA
astrosystemctl local install leann           # RAG NextCloud (LeAnn)
```

`astrosystemctl` résout automatiquement le script d'installation via **`IA/modules.list`**.

### Désinstaller

```bash
astrosystemctl local uninstall ollama             # Arrêt + suppression container
astrosystemctl local uninstall dify --purge       # + suppression des volumes/données
```

---

## 4. Le registre des modules — `IA/modules.list`

`IA/modules.list` est la **source unique de vérité** pour tous les modules Astroport.

```
# Format : name|port|check|install_group|label
icecast|8111|auto|icecast|Icecast Live Broadcasting
dify|8010|docker:dify-api|ai-company|Dify AI Workflow
ollama|11434|pgrep:ollama|gpu-ai|Ollama LLM API
youtube-antibot|-|-|youtube-antibot|YouTube Anti-Bot Deno+EJS+bgutil
powerjoular|-|-|powerjoular|Power Consumption Monitor
```

**Champs :**

| Champ | Valeurs possibles | Effet |
|-------|-------------------|-------|
| `port` | numéro · `-` | `-` = pas de tunnel P2P (outil local) |
| `check` | `auto` · `pgrep:CMD` · `docker:NOM` · `dockerimg:IMAGE` · `systemctl:SVC` · `-` | Condition de publication dans le swarm |
| `install_group` | nom → `install/install_<group>.sh` | Script d'installation associé |

**DRAGON** et **astrosystemctl** lisent tous les deux ce fichier.

### Ajouter un nouveau service

Une seule ligne à écrire :

```
# Exemple : MaStack sur le port 9000, vérifiée via docker
mastack|9000|docker:mastack-api|mastack|Ma Stack Custom
```

Puis (optionnel) créer `install/install_mastack.sh`. DRAGON la publiera au prochain cycle.

---

## 5. Ce que tu partages — `status` et `local hide/share`

```bash
astrosystemctl status
```

Affiche trois sections :

- **SERVICES PUBLIÉS AU SWARM** — canaux `ipfs p2p listen` actifs sur ta machine
- **SERVICES DISTANTS CONSOMMÉS** — tunnels vers d'autres stations
- **TUNNELS PERSISTANTS** — ceux que le watchdog 20h12 relance automatiquement

### Rendre un service privé

```bash
astrosystemctl local hide ollama         # Ollama non visible du swarm
astrosystemctl local hide qdrant         # Qdrant privé (données sensibles)
astrosystemctl local priv                # Voir les services privés actuels
```

### Remettre en partage

```bash
astrosystemctl local share ollama        # Ollama de nouveau partagé
```

> Ces commandes modifient `DRAGON_PRIVATE_SERVICES` dans `~/.zen/Astroport.ONE/.env`.
> Prise en compte au prochain cycle DRAGON ou manuellement :
> ```bash
> ~/.zen/Astroport.ONE/RUNTIME/DRAGON_p2p_ssh.sh
> ```

---

## 6. Ce que tu consommes — `list-remote` et `connect`

```bash
astrosystemctl list-remote             # Catalogue des Brain-Nodes disponibles
astrosystemctl list-remote ollama      # Filtrer par service
```

Exemple de sortie :
```
=== SERVICES DISPONIBLES DANS L'ESSAIM (SWARM) ===

  TYPE       SERVICE           NODE (fin)            POWER        CAPITAINE      LATENCE
  ─────────────────────────────────────────────────────────────────────────────────────
  🧠 IA      ollama (llama3,…) ...WAvWxP8nKqM5rT     🔥 Brain     alienware      8ms
  🧠 IA      comfyui           ...WAvWxP8nKqM5rT     🔥 Brain     alienware      12ms
  🧠 IA      ollama (phi3)     ...ikSHoDD581Jz9L     ⚡ Std       scorpio        45ms
  🎵 Audio   icecast           ...XZp4mNqK7rT2jB     🌿 Light     studio-rpi     82ms
```

### Se connecter

```bash
astrosystemctl connect ollama              # Meilleur nœud automatique (Power-Score max)
astrosystemctl connect ollama@12D3KooW…   # Nœud précis
astrosystemctl connect comfyui             # Tunnel vers le Brain-Node le plus rapide
```

Le tunnel IPFS est ouvert → service accessible sur `http://127.0.0.1:PORT`.

---

## 7. Rendre une connexion permanente — `enable` / `disable`

```bash
astrosystemctl enable ollama               # Watchdog actif → tunnel relancé chaque 20h12
astrosystemctl enable comfyui@12D3KooW…   # Épingler un nœud précis

astrosystemctl disable ollama              # Retirer du watchdog
```

Tunnels persistants : `~/.zen/tunnels/enabled/`
Le watchdog de `20h12.process.sh` les vérifie et relance automatiquement.

---

## 8. Vue d'ensemble des flux

```
INSTALLER                PARTAGER               CONSOMMER
─────────────────        ─────────────────      ─────────────────────
local install            (automatique si        list-remote
local start              actif dans             connect
                         modules.list)          enable (persistant)
                         local hide/share
```

---

## Dépannage rapide

| Symptôme | Commande de diagnostic |
|----------|------------------------|
| Service non visible dans `list-remote` | `astrosystemctl status` → DRAGON actif ? |
| Tunnel `OFF` dans `tunnel.sh` | `ipfs p2p ls` · `ipfs --timeout=15s ping /p2p/NODEID` |
| Service absent de `local list` | `heartbox_analysis.sh update` puis réessayer |
| Ollama local ignoré, tunnel ouvert quand même | `lsof -Pi :11434` |
| Tunnel persistant non relancé | `cat ~/.zen/tmp/tunnel.log` |
| Nouveau module non publié | Vérifier `IA/modules.list` · relancer `DRAGON_p2p_ssh.sh` |
| `local install mamodule` — script introuvable | Créer `install/install_<group>.sh` |

---

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| `IA/modules.list` | **Registre unique** des modules (services P2P + outils système) |
| `RUNTIME/DRAGON_p2p_ssh.sh` | Publie les services, génère `x_*.sh`, met à jour `authorized_keys` |
| `tools/astrosystemctl.sh` | CLI de gestion (symlink `~/.local/bin/astrosystemctl`) |
| `IA/*.me.sh` | Connecteurs de service (local → SSH → P2P fallback) |
| `install/install_<group>.sh` | Scripts d'installation par groupe de modules |
| `~/.zen/tunnels/enabled/` | Tunnels persistants (watchdog 20h12) |
| `~/.zen/Astroport.ONE/.env` | Config : `DRAGON_PRIVATE_SERVICES`, `SWARM_REMOTE_HOST` |
| `~/.zen/tmp/$IPFSNODEID/x_*.sh` | Scripts tunnel générés par DRAGON pour cette station |
| `~/.zen/tmp/swarm/*/x_*.sh` | Scripts tunnel des autres stations de la constellation |

---

## Niveaux de connaissance & progression

```
Niveau 0 — Utilisateur         astrosystemctl connect ollama
                                → utilise le swarm sans rien configurer

Niveau 1 — Opérateur           astrosystemctl local install dify
                                → installe et partage des services

Niveau 2 — Contributeur        IA/modules.list ← ajouter une ligne
                                install/install_monmodule.sh ← créer le script
                                → intègre un nouveau service dans l'écosystème

Niveau 3 — Architecte          DRAGON_p2p_ssh.sh · heartbox_analysis.sh
                                → comprend et étend la mécanique du swarm

Niveau 4 — Constellation       NOSTR + IPFS + G1 + ZEN
                                → participe à l'économie coopérative
                                → https://astroport.one
```

> Documentation complémentaire : [DRAGONS_and_TUNNELS.md](DRAGONS_and_TUNNELS.md)
