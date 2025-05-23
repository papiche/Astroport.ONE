# keygen

Un outil polyvalent pour la génération et la conversion de clés cryptographiques.

## Description

`keygen` est un outil en ligne de commande qui permet de générer et convertir des clés cryptographiques pour différentes applications. Il peut dériver des clés ED25519 à partir de :
- Clés GPG
- Identifiants Duniter (nom d'utilisateur/mot de passe)
- Phrases mnémoniques (DUBP)
- Clés existantes dans différents formats

## Installation

```bash
# Assurez-vous d'avoir les dépendances Python nécessaires
pip install -r requirements.txt

# Rendez le script exécutable
chmod +x keygen
```

## Utilisation

```bash
./keygen [options] [username] [password]
```

### Options principales

| Option | Description |
|--------|-------------|
| `-t, --type TYPE` | Format de sortie (base58, base64, b58mh, b64mh, duniter, ipfs, jwk, bitcoin, ssh, monero, pgp, nostr) |
| `-f, --format FORMAT` | Format de fichier de sortie (ewif, jwk, nacl, pb2, pem, pubsec, seed, wif) |
| `-i, --input FILE` | Lire une clé ED25519 depuis un fichier |
| `-o, --output FILE` | Écrire la clé ED25519 dans un fichier |
| `-g, --gpg` | Utiliser une clé GPG correspondant au nom d'utilisateur |
| `-m, --mnemonic` | Utiliser le nom d'utilisateur comme phrase mnémonique DUBP |

### Options supplémentaires

| Option | Description |
|--------|-------------|
| `-d, --debug` | Afficher les informations de débogage (ATTENTION: inclut la clé secrète) |
| `-k, --keys` | Afficher les clés publique et secrète |
| `-p, --prefix` | Préfixer le texte de sortie avec le type de clé |
| `-q, --quiet` | N'afficher que les erreurs |
| `-s, --secret` | N'afficher que la clé secrète |
| `-v, --verbose` | Afficher plus d'informations |
| `--version` | Afficher la version et quitter |

## Formats de sortie

### Formats texte
- `base58`: Clés encodées en Base58
- `base64`: Clés encodées en Base64
- `b58mh`: Clés encodées en Base58 multihash (pour IPFS)
- `b64mh`: Clés encodées en Base64 multihash (pour IPFS)
- `duniter`: Encodage Base58 pour les portefeuilles Duniter
- `ipfs`: Clés multihash pour IPFS
- `jwk`: Format JSON Web Key
- `bitcoin`: Clé privée Bitcoin et adresse publique
- `monero`: Clés privées Monero et adresse publique
- `nostr`: Clés Nostr au format npub et nsec
- `ssh`: Clés privées et publiques OpenSSH
- `pgp`: Clés privées et publiques PGP au format ASCII armuré

### Formats de fichier
- `ewif`: Fichier WIF chiffré (Duniter)
- `dewif`: Fichier WIF doublement chiffré (Duniter)
- `jwk`: Fichier JSON Web Key
- `nacl`: Fichier de clé privée NaCl
- `pb2`: Protocole Buffer version 2 pour IPFS
- `pem`: Clé privée PEM encodée PKCS#8
- `pubsec`: Fichier PubSec (Duniter)
- `seed`: Fichier seed (représentation hexadécimale)
- `wif`: Fichier WIF (Duniter)

## Exemples

### Générer un portefeuille Duniter
```bash
./keygen -t duniter mon_utilisateur mon_mot_de_passe
```

### Générer une clé IPFS
```bash
./keygen -t ipfs -o ipfs_key mon_utilisateur mon_mot_de_passe
```

### Générer des clés SSH
```bash
./keygen -t ssh -o ~/.ssh/id_ed25519 "ma phrase mnémonique"
```

### Générer des clés PGP
```bash
./keygen -t pgp -o mes_cles_pgp mon_utilisateur mon_mot_de_passe
```

### Générer des clés Bitcoin
```bash
./keygen -t bitcoin mon_utilisateur mon_mot_de_passe
```

### Générer des clés Monero
```bash
./keygen -t monero mon_utilisateur mon_mot_de_passe
```

### Générer des clés Nostr
```bash
./keygen -t nostr mon_utilisateur mon_mot_de_passe
```

## Configuration

Le fichier de configuration se trouve dans `~/.config/keygen/keygen.conf` (ou `$XDG_CONFIG_HOME/keygen/keygen.conf`). Il permet de configurer les paramètres scrypt pour la dérivation des clés :

```ini
[scrypt]
n = 4096
r = 16
p = 1
sl = 32
```

## Considérations de sécurité

- **Clés secrètes** : Manipulez les clés secrètes avec précaution. Évitez de les afficher dans la console.
- **Permissions des fichiers** : Assurez-vous que les fichiers de clés ont les permissions appropriées (ex: `chmod 600`).
- **Phrases de passe** : Utilisez des phrases de passe fortes et uniques.
- **Clés GPG** : Protégez vos clés GPG avec une phrase de passe forte.
- **Débogage** : Évitez l'option `--debug` en production.
- **Sauvegarde** : Sauvegardez vos fichiers de clés et phrases de passe de manière sécurisée.
- **Entropie du seed** : Assurez-vous d'avoir une entropie suffisante dans le seed en utilisant un nom d'utilisateur et un mot de passe forts.

## Codes de sortie

- `0` : Succès
- `1` : Avertissement
- `2` : Erreur

## Avertissement

Cet outil est fourni tel quel, sans garantie. Utilisez-le à vos propres risques. Les développeurs ne sont pas responsables des pertes ou dommages résultant de l'utilisation de cet outil.
