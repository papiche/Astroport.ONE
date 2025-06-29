# Guide de Démarrage Rapide UPlanet

> **Démarrez en 5 minutes avec le développement UPlanet**

## Prérequis

- **Python 3.8+** : [python.org](https://python.org)
- **Git** : [git-scm.com](https://git-scm.com)
- **Node.js 16+** : [nodejs.org](https://nodejs.org) (optionnel)

## Installation Express

### 1. Cloner le projet

```bash
git clone https://github.com/papiche/papiche.github.io.git
cd papiche.github.io
```

### 2. Installer les dépendances

```bash
# Installer MkDocs et extensions
pip install -r requirements.txt

# Installer les dépendances supplémentaires
pip install mkdocs-git-revision-date-localized-plugin
```

### 3. Lancer le serveur de développement

```bash
mkdocs serve
```

Votre site sera disponible sur : http://127.0.0.1:8000

## Créer votre premier service #BRO

### 1. Créer la structure

```bash
mkdir mon-service-bro
cd mon-service-bro

# Créer la structure de base
mkdir -p {api,Documents,Images,Music,Videos}
```

### 2. Créer le manifeste

```json
{
  "name": "MonServiceBRO",
  "version": "1.0.0",
  "description": "Mon premier service UPlanet",
  "tags": ["#BRO", "#storage", "#documents"],
  "api": "/api/monservice",
  "author": "Votre Nom",
  "license": "AGPL-3.0",
  "endpoints": {
    "upload": "/api/upload",
    "download": "/api/download",
    "search": "/api/search"
  }
}
```

### 3. Créer l'API

```bash
#!/bin/bash
# api/monservice.sh

case "$1" in
    "upload")
        echo "Upload: $2"
        ;;
    "download")
        echo "Download: $2"
        ;;
    "search")
        echo "Search: $2"
        ;;
    *)
        echo "Usage: $0 {upload|download|search} <file>"
        ;;
esac
```

### 4. Tester localement

```bash
# Tester l'API
./api/monservice.sh upload test.txt

# Générer la structure IPFS
./generate_ipfs_structure.sh .
```

## Intégration avec uSPOT

### 1. Connexion à l'API uSPOT

```javascript
// Connexion à l'API locale
const uspotUrl = 'http://127.0.0.1:54321';

// Authentification NOSTR
async function authenticate(npub) {
    const response = await fetch(`${uspotUrl}/api/test-nostr`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `npub=${npub}`
    });
    return response.json();
}
```

### 2. Utiliser l'IA locale

```javascript
// Envoyer un message à l'IA
async function sendAIMessage(message, lat, lon) {
    const response = await fetch(`${uspotUrl}/astrobot_chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            user_pubkey: 'your_hex_key',
            message: message,
            latitude: lat,
            longitude: lon,
            application: 'MonServiceBRO'
        })
    });
    return response.json();
}

// Exemple d'utilisation
sendAIMessage("#BRO #search UPlanet", 48.8566, 2.3522);
```

## Publication

### 1. Construire le site

```bash
mkdocs build
```

### 2. Déployer sur GitHub Pages

```bash
# Ajouter les changements
git add .
git commit -m "Ajout de la documentation développeur"

# Pousser vers GitHub
git push origin main
```

Le site sera automatiquement mis à jour sur https://papiche.github.io/

## Commandes utiles

### Développement

```bash
# Serveur de développement
mkdocs serve

# Construire le site
mkdocs build

# Nettoyer le build
mkdocs build --clean
```

### Déploiement

```bash
# Déployer sur GitHub Pages
mkdocs gh-deploy

# Déployer avec message personnalisé
mkdocs gh-deploy --message "Mise à jour de la documentation"
```

### Maintenance

```bash
# Vérifier la configuration
mkdocs build --strict

# Valider les liens
mkdocs build --strict --verbose
```

## Ressources utiles

- **[Guide complet du développeur](index.md)** : Documentation détaillée
- **[Référence API](api-reference.md)** : Toutes les APIs disponibles
- **[Site officiel](https://papiche.github.io/)** : Wiki UPlanet
- **[GitHub](https://github.com/papiche/papiche.github.io)** : Code source

## Support

- **Issues** : [GitHub Issues](https://github.com/papiche/papiche.github.io/issues)
- **Discussions** : [GitHub Discussions](https://github.com/papiche/papiche.github.io/discussions)
- **Documentation** : [Wiki UPlanet](https://papiche.github.io/)

---

*Dernière mise à jour : Janvier 2024* 