# Bash pour stations Astroport

**Auteur** : coucou (support+coucou@qo-op.com)\
**Skill** : bash\
**Niveau** : X1 — Fondamentaux

***

## Pourquoi Bash sur une station Astroport ?

Astroport.ONE est entièrement écrit en Bash. Comprendre Bash, c'est comprendre comment la station vit : comment elle démarre, publie sur IPFS, signe des événements NOSTR, et coopère dans la constellation.

***

## 1. Le pattern de base de tout script Astroport

Chaque script Astroport commence par ce bloc d'initialisation :

```bash
MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"
. "${MY_PATH}/tools/my.sh"   # charge l'environnement
```

`tools/my.sh` fournit les variables fondamentales :

* `$IPFSNODEID` — identifiant IPFS du nœud
* `$CAPTAING1PUB` — clé publique G1 du capitaine
* `$CAPTAINEMAIL` — email du capitaine
* `$myRELAY` — relay NOSTR de la constellation

***

## 2. Écrire dans un fichier JSON

La station publie son état dans `~/.zen/tmp/$IPFSNODEID/12345.json`. Pour mettre à jour un champ :

```bash
# Lire
val=$(jq -r '.capacities.power_score' ~/.zen/tmp/$IPFSNODEID/12345.json)

# Modifier avec jq
jq --arg v "42" '.capacities.power_score = ($v | tonumber)' \
    ~/.zen/tmp/$IPFSNODEID/12345.json > /tmp/12345_new.json \
    && mv /tmp/12345_new.json ~/.zen/tmp/$IPFSNODEID/12345.json
```

***

## 3. Publier sur IPFS

```bash
# Ajouter un fichier
CID=$(ipfs add -q /tmp/mon_fichier.txt)
echo "Publié : /ipfs/$CID"

# Publier le répertoire de la station sur IPNS
ipfs name publish --key="$IPFSNODEID" /ipfs/$CID
```

***

## 4. Signer un événement NOSTR depuis Bash

```bash
# Via nostr_node_intercom.py
python3 tools/nostr_node_intercom.py publish \
    --nsec "$CAPTAINNSEC" \
    --kind 1 \
    --content "Ma station est en ligne" \
    --relays "$myRELAY"
```

***

## 5. Boucles et conditions robustes

```bash
# Toujours utiliser [[ ]] et guillemets
if [[ -f "$fichier" ]] && [[ -s "$fichier" ]]; then
    echo "Fichier non vide : $fichier"
fi

# Lire ligne par ligne
while IFS= read -r ligne; do
    echo "→ $ligne"
done < "$fichier"

# Tableau de fichiers
mapfile -t fichiers < <(find ~/.zen/game/players -name "*.json")
for f in "${fichiers[@]}"; do
    echo "$f"
done
```

***

## 6. Exercice pratique

Créer un script qui vérifie que IPFS est actif et publie un message NOSTR :

```bash
#!/bin/bash
MY_PATH="$(cd "$(dirname "$0")" && pwd)"
. "${MY_PATH}/../tools/my.sh"

# Vérifier IPFS
if ! ipfs swarm peers &>/dev/null; then
    echo "IPFS non connecté" >&2
    exit 1
fi

# Compter les pairs
PEERS=$(ipfs swarm peers | wc -l)

# Publier
python3 "${MY_PATH}/../tools/nostr_node_intercom.py" publish \
    --nsec "$CAPTAINNSEC" \
    --kind 1 \
    --content "Station OK — $PEERS pairs IPFS" \
    --relays "$myRELAY"

echo "✓ Publié sur $myRELAY"
```

***

## Ressources complémentaires

* `Astroport.ONE/tools/my.sh` — bibliothèque centrale
* `Astroport.ONE/12345.sh` — API station (lire avant d'écrire)
* [BASH\_BEST\_PRACTICES.md](https://github.com/papiche/Astroport.ONE/blob/master/tests/docs/tutorials/BASH_BEST_PRACTICES.md) — sécurité et robustesse
