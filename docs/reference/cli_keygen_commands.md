# CLI keygen — Référence des commandes

`keygen` est le générateur de clés **déterministe** d'Astroport.ONE. À partir d'un email et d'un mot de passe, il dérive de façon reproductible les clés Ğ1, IPFS, et NOSTR.

Binaire : `~/.zen/Astroport.ONE/tools/keygen`

***

## Syntaxe générale

```
keygen [OPTIONS] -t TYPE "email" "motdepasse"
```

***

## Types de clés (`-t`)

| Type           | Description              | Format de sortie         |
| -------------- | ------------------------ | ------------------------ |
| `duniter`      | Clé publique Ğ1 (Base58) | `G1pub...`               |
| `ipfs`         | Clé IPFS PeerID          | `12D3Koo...` ou `Qm...`  |
| `nostr`        | Clé publique NOSTR (hex) | `npub...` / hex 64 chars |
| `nostr_secret` | Clé privée NOSTR         | `nsec...`                |

***

## Exemples

```bash
# Clé publique Ğ1
keygen -t duniter "alice@exemple.fr" "monmotdepasse"
# → 4YLU4XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# PeerID IPFS
keygen -t ipfs "alice@exemple.fr" "monmotdepasse"
# → 12D3KooWXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Clé publique NOSTR (npub)
keygen -t nostr "alice@exemple.fr" "monmotdepasse"
# → npub1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Clé privée NOSTR (nsec) — à garder secrète
keygen -t nostr_secret "alice@exemple.fr" "monmotdepasse"
# → nsec1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

***

## Propriétés importantes

* **Déterministe** : les mêmes inputs produisent toujours les mêmes clés
* **Pas de fichier de clé** : la clé n'est jamais stockée — elle est recalculée à chaque fois
* **Algorithme** : dérivation PBKDF2 sur la courbe Ed25519 (compatible Duniter v2s et NOSTR)
* **Sécurité** : la force de la clé dépend de la complexité du mot de passe

***

## Utilisation dans les scripts

```bash
# Pattern standard dans les scripts Astroport
source ~/.zen/Astroport.ONE/tools/my.sh

# Récupérer la G1pub d'un email
G1PUB=$(keygen -t duniter "$EMAIL" "$PASSWD")

# Récupérer la clé NOSTR d'un email
NOSTRPUB=$(keygen -t nostr "$EMAIL" "$PASSWD")
```

***

## Voir aussi

* [tools/my.sh](https://github.com/papiche/Astroport.ONE/blob/master/tools/my.sh) — variables d'env (CAPTAING1PUB, IPFSNODEID, etc.)
* [explanation/DID\_IMPLEMENTATION.md](../explanation/DID_IMPLEMENTATION.md) — comment les clés forment le DID
* [tutorials/install\_baremetal.md](../tutorials/install_baremetal.md) — première installation
