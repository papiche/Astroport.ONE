<!-- SPDX-License-Identifier: AGPL-3.0 -->
# RUNTIME — Vue d'ensemble des scripts de cycle de vie

Les scripts `RUNTIME/` sont les moteurs de fond d'Astroport.ONE. Ils sont lancés par `20h12.process.sh` (cron quotidien) ou par `_12345.sh` (démon permanent). Ils ne doivent jamais être lancés manuellement sauf pour debug.

---

## Orchestrateurs

### `20h12.process.sh` — Cron quotidien (~20h12)

Timeline d'exécution :

| Étape | Durée | Action |
|-------|-------|--------|
| 0–5 min | Nettoyage | Purge tmp, rotation logs |
| 5–10 min | Mise à jour | `git pull` repos |
| 10–15 min | DRAGON OFF | Fermeture tunnels IPFS P2P sortants |
| 15–20 min | IPFS restart | Redémarrage daemon IPFS |
| 20–30 min | DRAGON ON | `DRAGON_p2p_ssh.sh` — publication services |
| 30–40 min | Refresh | `PLAYER.refresh.sh`, `NOSTRCARD.refresh.sh` |
| 40–50 min | Économie | `ZEN.ECONOMY.sh` — paiements hebdomadaires |
| 50–60 min | Watchdog | Tunnels persistants `~/.zen/tunnels/enabled/` |
| 60–65 min | Publication | `ipfs name publish` → IPNS balise station |

### `_12345.sh` — Démon swarm permanent

- Publie `~/.zen/tmp/$IPFSNODEID/12345.json` toutes les 5 min
- Télécharge les `12345.json` des pairs toutes les heures
- Publie sur IPNS toutes les 4h
- Watchdog du daemon `bro_dm_daemon.sh` (DMs NOSTR NIP-44) toutes les 300s

---

## Scripts par domaine

### Identités MULTIPASS — `NOSTRCARD.refresh.sh`

**Rôle :** Synchronise les cartes NOSTR (MULTIPASS), vérifie les cycles de paiement, rafraîchit les données IPNS.

**Cycle de paiement :** Toutes les 7 jours. Chaque carte a une heure aléatoire stockée dans `.refresh_time` — évite la simultanéité sur les grosses constellations.

**Log :** `~/.zen/tmp/MULTIPASS.refresh.log`

**Comportements clés :**
- Validation NIP-23 (kind 30023) avant publication
- Distribution des bénéfices coopératifs
- Ne lance plus le daemon DM (délégué à `_12345.sh`)

---

### ZenCards joueurs — `PLAYER.refresh.sh`

**Rôle :** Rafraîchit les données des joueurs (ZenCard, wallet G1, TiddlyWiki).

**Entrée :** `$1` = email joueur (optionnel). Sans argument = traite tous les joueurs locaux.

**Dispatch parallèle :** Si `ASTRO_PARALLEL_REFRESH > 1`, lance N instances en parallèle via `xargs -P`.

**Lock :** `/tmp/player_refresh.lock` — protège contre les exécutions concurrentes (cron + manuel).

**Délégations :**
- TiddlyWiki → `TW.refresh.sh`
- Logique U.SOCIETY (loyers) → incluse directement

**Dépendances :** `tools/clyuseryomail.sh`, `tools/my.sh`

---

### TiddlyWiki — `TW.refresh.sh`

**Rôle :** Publication et synchronisation des TiddlyWiki joueurs sur IPFS.

**Appelé par :** `PLAYER.refresh.sh` pour chaque joueur.

---

### Économie coopérative — `ZEN.ECONOMY.sh`

**Rôle :** Moteur économique coopératif. Paiements entre UPlanet / NODE / Captain / joueurs.

**Fréquence :** Hebdomadaire. Marqueur : `~/.zen/game/.weekly_payment.done`.

**Règle 3×1/3 :** CAPTAIN_DEDICATED collecte les loyers usagers. Si revenus < coûts → bascule en mode BÉNÉVOLAT (Love Ledger). Aucun prélèvement sur CASH/ASSETS/R&D.

**Love Ledger :** `~/.zen/game/love_ledger.json` — comptabilise les semaines de bénévolat.

**Log :** `~/.zen/tmp/coucou/zen_economy.txt`

**Doc économique :** [`docs/explanation/ZEN.ECONOMY.v3.md`](../explanation/ZEN.ECONOMY.v3.md)

---

### Nouveaux joueurs — `VISA.new.sh`

**Rôle :** Création d'un nouveau joueur (ZenCard G1 wallet qui conserve l'historique OPEX).

**Appelé par :** `UPassport` API à l'onboarding ou manuellement.

---

### Monitoring G1 — `G1PalPay.sh`

**Rôle :** Surveille les transactions G1 entrants sur les adresses de la station. Déclenche les actions correspondantes (paiements ZEN, activations) -- lié au compte U.SOCIETY / TW / ZEN Card

---

### Infrastructure P2P — `DRAGON_p2p_ssh.sh`

**Rôle :** Détecte les services actifs, ouvre les canaux IPFS P2P (`ipfs p2p listen`), génère les scripts `x_SERVICE.sh` pour les pairs.

**Doc détaillée :** [`docs/how-to/DRAGONS_and_TUNNELS.md`](../how-to/DRAGONS_and_TUNNELS.md)

---

## Fichiers de sortie partagés

| Fichier | Écrit par | Lu par |
|---------|-----------|--------|
| `~/.zen/tmp/$IPFSNODEID/12345.json` | `_12345.sh` | astrosystemctl, pairs swarm |
| `~/.zen/tmp/$IPFSNODEID/heartbox_analysis.json` | `heartbox_analysis.sh` | astrosystemctl, DRAGON |
| `~/.zen/tmp/$IPFSNODEID/x_*.sh` | `DRAGON_p2p_ssh.sh` | pairs swarm, tunnel.sh |
| `~/.zen/game/love_ledger.json` | `ZEN.ECONOMY.sh` | rapports coopératifs |
| `~/.zen/tmp/MULTIPASS.refresh.log` | `NOSTRCARD.refresh.sh` | debug admin |
| `~/.zen/tmp/coucou/zen_economy.txt` | `ZEN.ECONOMY.sh` | debug admin |

---

## Ajouter un script RUNTIME

1. Créer `RUNTIME/MON_SCRIPT.sh` avec le header standard :
   ```bash
   MY_PATH="`dirname \"$0\"`"; MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
   . "$MY_PATH/../tools/my.sh"
   ```
2. L'ajouter dans `20h12.process.sh` à l'étape appropriée
3. Documenter ici dans ce fichier
