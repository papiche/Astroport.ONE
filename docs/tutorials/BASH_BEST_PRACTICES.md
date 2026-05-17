# Guide des Bonnes Pratiques Bash — Astroport.ONE / UPlanet ẐEN

> Version 1.0 — Mars 2026
> Applicable à tous les scripts Bash du projet Astroport.ONE.

---

## Sommaire

1. [Sécurité — Ne jamais exposer les secrets](#1-sécurité--ne-jamais-exposer-les-secrets)
2. [Sécurité — Jamais d'`eval` sur des données externes](#2-sécurité--jamais-deval-sur-des-données-externes)
3. [Stabilité — Valeurs par défaut avant `bc`](#3-stabilité--valeurs-par-défaut-avant-bc)
4. [Stabilité — Limiter le parallélisme IPFS](#4-stabilité--limiter-le-parallélisme-ipfs)
5. [Robustesse — `set -eo pipefail` (avec précautions)](#5-robustesse--set--eo-pipefail-avec-précautions)
6. [Architecture — `MY_PATH` moderne](#6-architecture--my_path-moderne)
7. [Template de script standard](#7-template-de-script-standard)
8. [Checklist avant commit](#8-checklist-avant-commit)

---

## 1. Sécurité — Ne jamais exposer les secrets

### Le problème

Sous Linux, les arguments de ligne de commande sont visibles par tous les utilisateurs via
`ps aux` ou `/proc/<pid>/cmdline`. Appeler `keygen` avec `SALT` et `PEPPER` en arguments
expose ces secrets à n'importe quel utilisateur du système pendant la durée d'exécution :

```bash
# ❌ DANGEREUX — visible dans ps aux
${MY_PATH}/../tools/keygen -t nostr "${SALT}" "${PEPPER}" -s
${MY_PATH}/../tools/keygen -t ipfs -o /tmp/key.pem "$SALT" "$PEPPER"
```

### La solution : fichier credentials temporaire en RAM

Le binaire [`keygen`](../tools/keygen) supporte l'option `-i FILE` qui lit un fichier texte
au **format `credentials`** : simplement `username` sur la ligne 1, `password` sur la ligne 2.

```bash
# ✅ CORRECT — SALT/PEPPER jamais exposés dans ps aux
_CRED=$(mktemp -p /dev/shm 2>/dev/null || mktemp)  # /dev/shm = RAM, pas de SD
chmod 600 "$_CRED"
trap "rm -f '$_CRED'" EXIT INT TERM                  # nettoyage automatique
printf '%s\n%s\n' "$SALT" "$PEPPER" > "$_CRED"

# Utiliser -i au lieu de passer les secrets en arguments
NPRIV=$(${MY_PATH}/../tools/keygen -t nostr -s -i "$_CRED")
NPUB=$(${MY_PATH}/../tools/keygen  -t nostr    -i "$_CRED")
${MY_PATH}/../tools/keygen -t ipfs -o /tmp/key.pem -i "$_CRED"
```

### Règles

| Règle | Détail |
|-------|--------|
| Toujours utiliser `/dev/shm` si disponible | tmpfs en RAM, aucune écriture disque |
| `chmod 600` immédiatement après `mktemp` | Personne d'autre ne peut lire le fichier |
| `trap "rm -f ..." EXIT INT TERM` | Nettoyage garanti même en cas d'interruption |
| `printf '%s\n%s\n'` plutôt que `echo` | Comportement prévisible avec caractères spéciaux |
| Créer **un seul** fichier credentials par script | Le réutiliser pour tous les appels `keygen` du même SALT/PEPPER |

### Cas particulier : mot de passe composite

Quand le mot de passe est composite (ex: `"$PEPPER $IPFSNODEID"`), créer un fichier
séparé et le supprimer immédiatement après :

```bash
_CRED_FEED=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
chmod 600 "$_CRED_FEED"
printf '%s\n%s\n' "$SALT" "$PEPPER $IPFSNODEID" > "$_CRED_FEED"
${MY_PATH}/../tools/keygen -t ipfs -o /tmp/feed.key -i "$_CRED_FEED"
rm -f "$_CRED_FEED"  # supprimer immédiatement (pas besoin de trap ici)
```

---

## 2. Sécurité — Jamais d'`eval` sur des données externes

### Le problème

`eval` exécute une chaîne de caractères comme du code Bash. Si cette chaîne provient de
données externes (fichiers NOSTR, réseau, entrées utilisateur), un attaquant peut injecter
du code arbitraire :

```bash
# ❌ DANGEREUX — faille d'injection de code
NOSTR_DATA=$(./search_for_this_email_in_nostr.sh "${mail}" | tail -n 1)
eval "$NOSTR_DATA"   # Si NOSTR_DATA = 'HEX=abc; rm -rf ~' → désastre
```

### La solution : extraction `grep -oP` par champ

Extraire chaque variable **individuellement** avec un pattern `grep -oP` précis :

```bash
# ✅ CORRECT — aucun code arbitraire ne peut s'exécuter
NOSTR_LINE=$(./search_for_this_email_in_nostr.sh "${mail}" 2>/dev/null | tail -n 1)
if [[ -n "$NOSTR_LINE" && "$NOSTR_LINE" == export\ * ]]; then
    HEX=$(echo       "$NOSTR_LINE" | grep -oP '(?<=\bHEX=)[^ ]+')
    NPUB=$(echo      "$NOSTR_LINE" | grep -oP '(?<=\bNPUB=)[^ ]+')
    RELAY=$(echo     "$NOSTR_LINE" | grep -oP '(?<=\bRELAY=)[^ ]+')
    G1PUBNOSTR=$(echo "$NOSTR_LINE"| grep -oP '(?<=\bG1PUBNOSTR=)[^ ]+')
fi
```

Si la source renvoie du **JSON** (ex: `search_for_this_email_in_nostr.sh --all`), utiliser `jq` :

```bash
# ✅ CORRECT pour JSON
NOSTR_JSON=$(./search_for_this_email_in_nostr.sh "${mail}" 2>/dev/null)
if echo "$NOSTR_JSON" | jq -e '.hex' >/dev/null 2>&1; then
    HEX=$(echo "$NOSTR_JSON"  | jq -r '.hex      // ""')
    NPUB=$(echo "$NOSTR_JSON" | jq -r '.npub     // ""')
    RELAY=$(echo "$NOSTR_JSON"| jq -r '.relay    // ""')
fi
```

### Règle absolue

> **Ne jamais utiliser `eval` sur des données qui pourraient provenir d'un tiers.**
> Cela inclut : fichiers NOSTR, réponses de nœuds RPC, entrées utilisateur, variables d'environnement non contrôlées.

---

## 3. Stabilité — Valeurs par défaut avant `bc`

### Le problème

`bc` plante avec une **syntax error** si une variable est vide, `null`, ou contient du texte :

```bash
# ❌ RISQUE — si COINS="" ou COINS="null", bc plante silencieusement
if [[ $(echo "$COINS > $Gpaf + $Npaf" | bc -l) -eq 1 ]]; then ...
```

Résultat : la condition échoue de façon imprévisible, les paiements sont silencieusement ignorés.

### La solution : déclarer les défauts en bloc

```bash
# ✅ CORRECT — juste avant tout appel bc avec ces variables
COINS=${COINS:-0}
[[ "$COINS" == "null" ]] && COINS=0
Gpaf=${Gpaf:-0}
Npaf=${Npaf:-0}
TVA_AMOUNT=${TVA_AMOUNT:-0}

if [[ $(echo "$COINS > $Gpaf + $Npaf" | bc -l) -eq 1 ]]; then ...
```

### Règles

| Contexte | Pattern recommandé |
|----------|-------------------|
| Variable simple | `VAR=${VAR:-0}` |
| Variable pouvant valoir `"null"` (retour jq) | `[[ "$VAR" == "null" ]] && VAR=0` |
| Variable calculée par `bc` qui alimente un autre `bc` | Appliquer `${:-0}` sur chaque intermédiaire |
| Option `bc -l` avec `2>/dev/null \|\| echo 0` | Fallback explicite en cas d'erreur bc |

### Attention aux scripts critiques

Les scripts suivants manipulent de l'argent réel (Ğ1) — toute variable vide peut causer
une perte de fonds ou un double paiement :

- [`RUNTIME/NOSTRCARD.refresh.sh`](../RUNTIME/NOSTRCARD.refresh.sh) — paiements MULTIPASS
- [`RUNTIME/PLAYER.refresh.sh`](../RUNTIME/PLAYER.refresh.sh) — paiements ZENCard
- [`RUNTIME/ZEN.ECONOMY.sh`](../RUNTIME/ZEN.ECONOMY.sh) — rétribution NODE/CAPTAIN
- [`RUNTIME/ZEN.COOPERATIVE.3x1-3.sh`](../RUNTIME/ZEN.COOPERATIVE.3x1-3.sh) — allocation coopérative

---

## 4. Stabilité — Limiter le parallélisme IPFS

### Le problème

Lancer `ipfs name publish &` en arrière-plan pour 200 utilisateurs simultanément
provoque un **OOM kill** sur Raspberry Pi (IPFS consomme ~150 Mo de RAM par processus) :

```bash
# ❌ DANGEREUX en batch — 200 processus ipfs simultanés = OOM
for email in "${emails[@]}"; do
    ipfs name publish --key "${key}" "/ipfs/${cid}" 2>&1 >/dev/null &
done
```

### La solution : rate-limiting par `pgrep`

```bash
# ✅ CORRECT — limite à MAX_IPFS_PUBLISH processus simultanés (défaut: 3)
_max_pub=${MAX_IPFS_PUBLISH:-3}
while [[ $(pgrep -c -f "ipfs name publish" 2>/dev/null || echo 0) -ge $_max_pub ]]; do
    sleep 2
done
ipfs name publish --key "${key}" "/ipfs/${cid}" 2>&1 >/dev/null &
```

La variable `MAX_IPFS_PUBLISH` est configurable dans `.env` selon les capacités de la machine :
- Raspberry Pi 4 (4 Go) : `MAX_IPFS_PUBLISH=2`
- Serveur standard (16 Go+) : `MAX_IPFS_PUBLISH=8`

---

## 5. Robustesse — `set -eo pipefail` (avec précautions)

### Avantages

```bash
set -eo pipefail
```

- `set -e` : arrête le script si une commande échoue (évite les cascades d'erreurs)
- `set -o pipefail` : attrape les erreurs dans les pipes (`cmd1 | cmd2`)

### Précautions indispensables avant d'activer

Avec `set -e`, toute commande retournant un code non-zéro arrête le script. Ceci inclut :
- `grep` qui ne trouve rien (exit 1)
- `jq` sur une clé absente
- `[[ ... ]]` conditions intentionnellement fausses

**Avant d'activer `set -e`, auditer toutes les lignes et ajouter `|| true` où nécessaire :**

```bash
# Avant (avec set -e, stoppe le script si grep ne trouve rien)
grep "pattern" fichier

# Après (correct)
grep "pattern" fichier || true

# Pour jq sur champ optionnel
VAL=$(jq -r '.optional_field // empty' file.json 2>/dev/null) || VAL=""
```

### Scripts où `set -eo pipefail` est recommandé (après audit)

- [`tools/PAYforSURE.sh`](../tools/PAYforSURE.sh) — script de paiement critique
- [`RUNTIME/ZEN.ECONOMY.sh`](../RUNTIME/ZEN.ECONOMY.sh) — économie hebdomadaire
- [`RUNTIME/ZEN.COOPERATIVE.3x1-3.sh`](../RUNTIME/ZEN.COOPERATIVE.3x1-3.sh) — allocation coopérative

---

## 6. Architecture — `MY_PATH` moderne

### Ancienne syntaxe (179 scripts, fonctionne mais vieillissante)

```bash
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
```

### Nouvelle syntaxe recommandée (résistante aux symlinks, POSIX-compatible)

```bash
MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

**Différence clé** : `${BASH_SOURCE[0]}` retourne le chemin du fichier **sourcé**,
alors que `$0` retourne le nom du processus appelant (peut différer si le script est
`source`d depuis un autre script).

### Migration

Pour migrer l'ensemble du projet (à faire progressivement, avec tests) :

```bash
# Remplacer les 2 lignes backtick par la syntaxe moderne
find Astroport.ONE -name "*.sh" -exec sed -i \
  's|MY_PATH="`dirname \\"$0\\"*`"|MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" \&\& pwd)"|g' {} \;
```

> ⚠️ Effectuer cette migration **progressivement** avec tests d'intégration,
> pas en une seule opération globale.

---

## 7. Template de script standard

Voici le template recommandé pour tout nouveau script critique :

```bash
#!/bin/bash
################################################################################
# Script: mon_script.sh
# Description: Ce que fait ce script
# Usage: ./mon_script.sh ARG1 ARG2
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################
# Résolution de chemin robuste (symlink-safe)
MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${MY_PATH}/../tools/my.sh"

################################################################################
# Nettoyage automatique des fichiers temporaires
_TMPFILES=()
cleanup() {
    [[ ${#_TMPFILES[@]} -gt 0 ]] && rm -f "${_TMPFILES[@]}"
}
trap cleanup EXIT INT TERM

################################################################################
# Validation des arguments
[[ -z "$1" ]] && echo "Usage: $(basename "$0") ARG1 ARG2" && exit 1

ARG1="$1"
ARG2="$2"

################################################################################
# Créer des secrets en RAM si nécessaire (ex: SALT/PEPPER pour keygen)
# _CRED=$(mktemp -p /dev/shm 2>/dev/null || mktemp)
# chmod 600 "$_CRED"
# _TMPFILES+=("$_CRED")
# printf '%s\n%s\n' "$SALT" "$PEPPER" > "$_CRED"

################################################################################
# Valeurs par défaut pour les calculs numériques (bc)
VAR_NUMERIQUE=${VAR_NUMERIQUE:-0}
[[ "$VAR_NUMERIQUE" == "null" ]] && VAR_NUMERIQUE=0

################################################################################
# Logique principale
echo "Starting ${0##*/}..."
```

---

## 8. Checklist avant commit

Avant de commiter un script Bash qui manipule des secrets ou des paiements :

- [ ] **Secrets** : Les `SALT`, `PEPPER`, `NSEC` ne sont **jamais** passés en arguments CLI à `keygen`
- [ ] **eval** : Aucun `eval` sur des données externes (NOSTR, réseau, utilisateur)
- [ ] **bc** : Toutes les variables utilisées dans `bc` ont une valeur par défaut `${:-0}`
- [ ] **IPFS** : Les appels `ipfs name publish &` en boucle sont protégés par un rate-limiter `pgrep`
- [ ] **Fichiers temp** : Tout `mktemp` est suivi d'un `trap "rm -f ..."` ou d'une suppression explicite
- [ ] **MY_PATH** : Les nouveaux scripts utilisent `${BASH_SOURCE[0]}` (pas `$0`)
- [ ] **Permissions** : Les fichiers de clés sont protégés `chmod 600` après création

---

## Références

- [keygen interface](../tools/keygen.readme.md) — Documentation du binaire de génération de clés
- [PAYforSURE.sh](../tools/PAYforSURE.sh) — Exemple de bonne pratique pour les paiements (secrets via fichier)
- [G1check.sh](../tools/G1check.sh) — Exemple de validation de valeur numérique avant `bc`
- [DRAGONS_and_TUNNELS.md](DRAGONS_and_TUNNELS.md) — Architecture de l'écosystème Astroport.ONE
