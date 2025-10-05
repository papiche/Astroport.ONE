# Guide d'utilisation de keygen pour convertir des clés SSH/PGP en portefeuille Ğ1

## Vue d'ensemble

Le script `keygen` permet de convertir vos clés SSH ou PGP existantes en portefeuille Ğ1 (Duniter). Il génère des clés ED25519 compatibles avec le réseau Ğ1.

## 🎯 Format .dunikey : Le pivot central

Le format `.dunikey` est notre **pivot central** qui permet d'attribuer un portefeuille Ğ1 à n'importe quelle clé crypto habituelle. C'est le format de référence qui permet de :

- Convertir vers d'autres formats (IPFS, Nostr, Bitcoin, etc.)
- Maintenir la compatibilité avec Duniter v1
- Utiliser le système salt/pepper comme dans Duniter v1

## 🔑 Génération de la seed à partir de Salt/Pepper (comme Duniter v1)

### Méthode NaCl avec Salt/Pepper
```bash
# Générer une seed à partir de salt et pepper (comme Duniter v1)
python3 tools/keygen -t duniter -o ~/.zen/mon_portefeuille.dunikey "salt" "pepper"

# Exemple concret
python3 tools/keygen -t duniter -o ~/.zen/coucou.dunikey "coucou" "coucou"
```

## Méthodes de conversion

### 1. Conversion depuis une clé GPG existante

Si vous avez déjà une clé GPG dans votre trousseau :

```bash
# Utiliser votre clé GPG existante
python3 tools/keygen -g -t duniter votre_nom_utilisateur_gpg

# Sauvegarder dans un fichier .dunikey (format pivot)
python3 tools/keygen -g -t duniter -o ~/.zen/mon_portefeuille.dunikey votre_nom_utilisateur_gpg
```

### 2. Conversion depuis une clé SSH existante

Si vous avez une clé SSH privée :

```bash
# Créer un fichier avec votre clé SSH privée
echo "-----BEGIN OPENSSH PRIVATE KEY-----" > ma_cle_ssh
echo "votre_clé_privée_ssh_ici" >> ma_cle_ssh
echo "-----END OPENSSH PRIVATE KEY-----" >> ma_cle_ssh

# Convertir en portefeuille Ğ1 (.dunikey)
python3 tools/keygen -i ma_cle_ssh -t duniter -o ~/.zen/mon_portefeuille.dunikey
```

### 3. Création d'un nouveau portefeuille Ğ1

Pour créer un nouveau portefeuille à partir d'un nom d'utilisateur et mot de passe :

```bash
# Créer un portefeuille Ğ1 standard (.dunikey)
python3 tools/keygen -t duniter -o ~/.zen/mon_portefeuille.dunikey mon_nom_utilisateur mon_mot_de_passe

# Avec format EWIF (encrypted)
python3 tools/keygen -t duniter -f ewif -o ~/.zen/mon_portefeuille.ewif mon_nom_utilisateur mon_mot_de_passe
```

## 🔄 Conversion depuis le format .dunikey (pivot)

Une fois que vous avez votre fichier `.dunikey`, vous pouvez le convertir vers n'importe quel autre format :

### Conversion vers IPFS
```bash
# Depuis un fichier .dunikey existant
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t ipfs

# Sauvegarder les clés IPFS
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t ipfs -o ~/.zen/ipfs_keys
```

### Conversion vers Nostr
```bash
# Depuis un fichier .dunikey existant
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t nostr

# Sauvegarder la clé Nostr
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t nostr -o ~/.zen/nostr_key
```

### Conversion vers SSH
```bash
# Depuis un fichier .dunikey existant
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t ssh -o ~/.zen/ssh_key
```

### Conversion vers Bitcoin
```bash
# Depuis un fichier .dunikey existant
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t bitcoin
```

### Conversion vers Monero
```bash
# Depuis un fichier .dunikey existant
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t monero
```

## 📋 Formats de sortie disponibles

### Formats de portefeuille Ğ1 (pivot)
- **`.dunikey`** : Format pivot central (recommandé)
- `pubsec` : Format standard Duniter
- `ewif` : Format encrypté
- `wif` : Format WIF standard
- `seed` : Format seed hexadécimal

### Formats de clés (depuis .dunikey)
- `base58` : Clé en Base58 (par défaut)
- `base64` : Clé en Base64
- `ssh` : Clé SSH ED25519
- `pgp` : Clé PGP
- `nostr` : Clé Nostr
- `bitcoin` : Adresse Bitcoin
- `monero` : Adresse Monero
- `ipfs` : Clés IPFS (PeerID + PrivKEY)

## Exemples pratiques

### Exemple 1 : Conversion d'une clé GPG en portefeuille Ğ1

```bash
# 1. Lister vos clés GPG pour trouver l'ID
gpg --list-secret-keys

# 2. Convertir en portefeuille Ğ1
python3 tools/keygen -g -t duniter -o ~/.zen/portefeuille_gpg.pubsec votre_email@example.com

# 3. Vérifier le résultat
cat ~/.zen/portefeuille_gpg.pubsec
```

### Exemple 2 : Création d'un portefeuille Ğ1 avec mnémonique

```bash
# Utiliser une phrase mnémonique
python3 tools/keygen -m -t duniter -o ~/.zen/portefeuille_mnemonic.pubsec "phrase mnemonic de douze mots"
```

### Exemple 3 : Génération de multiples formats

```bash
# Générer plusieurs formats à la fois
python3 tools/keygen -t duniter -o ~/.zen/portefeuille.pubsec mon_nom mon_mot_de_passe
python3 tools/keygen -t ssh -o ~/.zen/cle_ssh mon_nom mon_mot_de_passe
python3 tools/keygen -t pgp -o ~/.zen/cle_pgp mon_nom mon_mot_de_passe
python3 tools/keygen -t nostr -o ~/.zen/cle_nostr mon_nom mon_mot_de_passe
```

### Exemple 4 : Conversion depuis un fichier de clé existant

```bash
# Si vous avez un fichier de clé dans un format spécifique
python3 tools/keygen -i mon_fichier_cle.jwk -t duniter -o ~/.zen/portefeuille.pubsec
```

## Options avancées

### Mode debug (pour le développement)
```bash
python3 tools/keygen -d -t duniter mon_nom mon_mot_de_passe
```

### Mode silencieux (seulement les erreurs)
```bash
python3 tools/keygen -q -t duniter -o ~/.zen/portefeuille.pubsec mon_nom mon_mot_de_passe
```

### Afficher seulement la clé publique
```bash
python3 tools/keygen -t duniter -k mon_nom mon_mot_de_passe
```

### Afficher seulement la clé privée
```bash
python3 tools/keygen -t duniter -s mon_nom mon_mot_de_passe
```

## Structure des fichiers générés

### Format PubSec (recommandé pour Ğ1)
```
Type: PubSec
Public: 2gNxsJHyGZDsK7e9rbZSjvY4krma36t9gLq2AfaKTaEs
Secret: 5J7X8Y9Z...
```

### Format EWIF (encrypté)
```
Type: EWIF
Version: 1
...
```

## Intégration avec le réseau Ğ1

Une fois votre portefeuille généré :

1. **Copiez le fichier dans le répertoire Duniter** :
   ```bash
   cp ~/.zen/portefeuille.pubsec ~/.config/duniter/
   ```

2. **Utilisez avec Silkaj** :
   ```bash
   silkaj --wallet ~/.zen/portefeuille.pubsec
   ```

3. **Vérifiez votre solde** :
   ```bash
   silkaj --wallet ~/.zen/portefeuille.pubsec balance
   ```

## Sécurité

- **Ne partagez jamais votre clé privée**
- **Sauvegardez vos fichiers de portefeuille en lieu sûr**
- **Utilisez des mots de passe forts pour les formats encryptés**
- **Testez d'abord sur le réseau de test**

## Dépannage

### Erreur "No GPG key found"
```bash
# Vérifiez que votre clé GPG existe
gpg --list-secret-keys
```

### Erreur de format de fichier
```bash
# Vérifiez le format avec l'option debug
python3 tools/keygen -d -i votre_fichier_cle
```

### Problème de permissions
```bash
# Assurez-vous que les fichiers ont les bonnes permissions
chmod 600 ~/.zen/portefeuille.dunikey
```

## 🧪 Script de test complet

Un script de test complet est disponible pour tester toutes les conversions :

```bash
# Exécuter le script de test complet
./test_keygen_complet.sh
```

Ce script :
- Génère un fichier `.dunikey` à partir de `salt=coucou pepper=coucou`
- Convertit vers tous les formats disponibles
- Vérifie la cohérence des conversions
- Affiche un résumé complet

## 🔄 Workflow complet recommandé

### 1. Création du fichier pivot
```bash
# Créer le fichier .dunikey (pivot central)
python3 tools/keygen -t duniter -o ~/.zen/mon_portefeuille.dunikey "salt" "pepper"
```

### 2. Conversions vers d'autres formats
```bash
# Clé SSH
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t ssh -o ~/.zen/ssh_key

# Clé Nostr
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t nostr -o ~/.zen/nostr_key

# Clés IPFS
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t ipfs -o ~/.zen/ipfs_keys

# Adresse Bitcoin
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t bitcoin

# Adresse Monero
python3 tools/keygen -i ~/.zen/mon_portefeuille.dunikey -t monero
```

### 3. Utilisation avec le réseau Ğ1
```bash
# Copier le fichier .dunikey dans le répertoire Duniter
cp ~/.zen/mon_portefeuille.dunikey ~/.config/duniter/

# Utiliser avec Silkaj
silkaj --wallet ~/.zen/mon_portefeuille.dunikey balance
```

## 📝 Résumé des avantages du format .dunikey

- **Pivot central** : Un seul fichier pour toutes les conversions
- **Compatibilité Duniter v1** : Utilise le système salt/pepper
- **Sécurité** : Format standard et éprouvé
- **Flexibilité** : Conversion vers n'importe quel format crypto
- **Réversibilité** : Possibilité de revenir au format .dunikey

