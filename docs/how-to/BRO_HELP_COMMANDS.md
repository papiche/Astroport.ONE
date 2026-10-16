# BRO — Commandes disponibles en DM NOSTR

## Aide, help, commandes

Pour voir les commandes disponibles, envoie : `help`, `aide`, `commandes BRO`, ou `quelles sont les commandes`

BRO répond automatiquement à toute question libre en cherchant dans sa base de connaissance (Qdrant + Ollama).

---

## Commandes texte DM

| Commande | Rôle |
|----------|------|
| `<question libre>` | Réponse IA — le contexte personnel pertinent est retrouvé automatiquement (recherche sémantique Qdrant), rien à sélectionner |

### Mémoire personnelle

Une seule mémoire par MULTIPASS (simplification 2026-10 : plus de "slots" numérotés à retenir soi-même — BRO retrouve ce qui est pertinent à la question posée).

| Commande | Rôle |
|----------|------|
| `#rec <texte>` | Mémoriser |
| `#rec <texte> #bro <question>` | Mémoriser ET interroger l'IA dans le même message |
| `#mem` | Voir vos mémoires récentes |
| `#reset` | Effacer votre mémoire |

### Compétences partagées

| Commande | Rôle |
|----------|------|
| `#rec:<skill> <note>` | Contribuer à la mémoire partagée du skill |
| `#mem:<skill>` | Lire la mémoire partagée du skill |
| `#mem:` | Lister tous les skills mémorisés sur ce nœud |
| `#craft <url>` | Décomposer un tutoriel en recette MineLife (WoTx²) |

Exemples :
- `#rec:devops Je maîtrise nginx et TLS`
- `#mem:devops`
- `#craft https://instructables.com/...`

### Données publiques (data.gouv.fr)

| Commande | Rôle |
|----------|------|
| `#opendata <requête>` | Rechercher des jeux de données publics sur data.gouv.fr |

Exemple : `#opendata prix immobilier Paris`

*Nécessite que la station ait installé le venv MCP isolé (`install/install_mcp_venv.sh`, appelé automatiquement par `install.sh`) — sinon la commande n'apparaît pas dans `#help`.*

### Badges et IA

| Commande | Rôle |
|----------|------|
| `#badge <skill>` | Générer une image de badge skill (ComfyUI) |
| `comfyui_job` | Génération d'image IA avancée |

---

## Niveaux d'accès

Simplification 2026-10-14 (décision capitaine) : **BRO est accessible à tous les MULTIPASS hébergés sur la station, sans palier économique** — l'usage reste de toute façon monétisé en ẐEN sur le MULTIPASS de l'appelant (kind 7). Le niveau réel (0-5, `bro_user_level.py`) ne sert plus qu'à :

| Niveau | Rôle |
|--------|------|
| 0 | Expéditeur totalement inconnu de la constellation (aucun MULTIPASS nulle part) — ignoré, anti-abus |
| 1 à 4 | Toutes les commandes ci-dessus, sans distinction |
| 5 (Capitaine) | `#mod:<skill>` / `#rm:<skill>` (modération a posteriori de la mémoire partagée), `#arbor` — rôle administratif unique de la station, jamais un palier payant |

---

## Commandes émises par les applications

Ces commandes arrivent automatiquement depuis les apps UPlanet (pas en tapant du texte) :

| Type | Source | Rôle |
|------|--------|------|
| `udrive` | Application UPlanet | Upload de fichier vers uDRIVE IPFS |
| `vocals` | Application UPlanet | Synthèse vocale / publication audio |
| `webcam` | Application UPlanet | Publication flux webcam |
| `zen_like` | Kind 7 NOSTR | Paiement ẐEN via réaction |
| `love` | cabine-33 / atomic.html | Rencontre ATOM4LOVE (matching phi2x) |
