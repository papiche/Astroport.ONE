# UPlanet/Astroport.ONE – Backend Décentralisé pour Applications Modernes

## Introduction

**UPlanet** (Astroport.ONE) est une plateforme backend décentralisée, open-source, conçue pour remplacer les services cloud traditionnels (AWS, Google Cloud, Azure). Elle s’appuie sur NOSTR pour l’authentification, IPFS pour le stockage distribué, et la monnaie libre Ğ1 pour la preuve d’humanité et la monétisation. Chaque nœud est une « ♥️box » validée par la toile de confiance Ğ1.

---

## Migration depuis AWS/Azure vers UPlanet/Astroport.ONE

### Table de correspondance des services

| AWS/Azure            | UPlanet/Astroport.ONE         | Avantage principal                |
|----------------------|-------------------------------|-----------------------------------|
| S3                   | IPFS/uDRIVE                   | Stockage décentralisé, pas de lock-in |
| Cognito/Firebase     | NOSTR Card (NIP-42)           | Auth sans serveur, souveraineté   |
| Lambda/Functions     | ASTROBOT (scripts, triggers)  | Programmable, open-source         |
| DynamoDB/CosmosDB    | NOSTR events + IPFS           | Indexation flexible, géolocalisée |
| IAM                  | Contrôle par clé NOSTR/IPNS   | Permissions natives, sans tiers   |
| Billing              | Ẑen stablecoin                | Coût prévisible, sans surprise    |
| CloudFormation/ARM   | Déploiement scripté (bash, Ansible, Docker) | Simplicité, portabilité |
| CloudWatch/Monitor   | Endpoints API `/health`, logs, Prometheus | Supervision locale, open-source |

---

### Exemples de migration

**Stockage de fichiers**
```js
// AWS S3
s3.upload({ Bucket: 'mybucket', Key: 'file.jpg', Body: file });

// UPlanet
const formData = new FormData();
formData.append('file', file);
formData.append('npub', userNpub);
await fetch('/api/upload', { method: 'POST', body: formData });
```

**Authentification**
```js
// AWS Cognito
Auth.signIn(username, password);

// UPlanet NOSTR
const authEvent = { kind: 22242, ... };
const signedEvent = NostrTools.finishEvent(authEvent, privateKey);
await fetch('/api/test-nostr', { method: 'POST', body: 'npub=' + publicKey });
```

**Fonctions serverless**
```bash
# AWS Lambda
# (handler JS ou Python)

# UPlanet ASTROBOT
./Astroport.ONE/IA/UPlanet_IA_Responder.sh
```

**Base de données (DynamoDB/CosmosDB → NOSTR/IPFS)**
- Les données structurées (JSON, documents, objets) sont stockées comme événements NOSTR (kind: 1, 30023, etc.) ou fichiers sur IPFS.
- Pour migrer, exporter vos données (CSV, JSON), puis publier via l’API ou en tant qu’événements NOSTR.

_Exemple : Migration d’un document JSON_
```js
// DynamoDB → UPlanet
const data = { ... };
const event = {
  kind: 1,
  created_at: Math.floor(Date.now() / 1000),
  tags: [['application', 'myapp']],
  content: JSON.stringify(data)
};
const signedEvent = NostrTools.finishEvent(event, privateKey);
relay.publish(signedEvent);
```

**CI/CD (GitHub Actions, Azure DevOps → Déploiement UPlanet)**
- Utilisez des scripts bash, Ansible, ou Docker Compose pour déployer vos nœuds UPlanet.
- Exemple de pipeline :
```yaml
# .github/workflows/deploy-uplanet.yml
name: Deploy UPlanet Node
on:
  push:
    branches: [ main ]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: sudo apt-get update && sudo apt-get install -y ipfs python3-pip
      - name: Deploy Astroport.ONE
        run: |
          git clone https://github.com/papiche/Astroport.ONE.git
          cd Astroport.ONE
          ./install.sh
      - name: Run tests
        run: |
          cd Astroport.ONE
          ./test_memory_access_control.sh
```
- Pour la production, privilégiez l’automatisation via Ansible, Terraform, ou des scripts personnalisés.

---

### Guide étape par étape pour migrer

1. **Déployer un nœud UPlanet (♥️box)**
   - Suivre la documentation officielle pour installer Astroport.ONE sur un serveur, VPS ou cloud (Docker, bash, Ansible).
2. **Créer les NOSTR Cards pour vos utilisateurs**
   - Utiliser `make_NOSTRCARD.sh` pour chaque utilisateur (migration des identités).
3. **Migrer les fichiers**
   - Exporter les fichiers S3/Azure Blob, puis uploader via `/api/upload` ou en ligne de commande IPFS.
4. **Migrer la base de données**
   - Exporter vos données (CSV, JSON, etc.), puis publier sur IPFS ou en tant qu’événements NOSTR (voir exemples ci-dessus).
   - Pour les données relationnelles, repenser le modèle : chaque objet devient un événement ou un fichier.
5. **Adapter l’authentification**
   - Remplacer les appels Cognito/Firebase par l’auth NOSTR (NIP-42).
   - Générer et distribuer les NOSTR Cards à vos utilisateurs.
6. **Automatiser les traitements (backend)**
   - Convertir vos Lambda/Functions en scripts ou bots ASTROBOT (bash, python, etc.).
   - Déclencher des actions via événements NOSTR ou planification (cron).
7. **Mettre en place CI/CD**
   - Intégrer le déploiement de vos scripts, bots et configurations dans vos pipelines CI/CD (GitHub Actions, GitLab CI, etc.).
   - Tester l’intégration avec `/api/test-nostr`, `/health`, `/rate-limit-status`.
8. **Superviser et monitorer**
   - Utiliser les endpoints `/health`, `/rate-limit-status`, et surveiller les logs pour la supervision.
   - Intégrer Prometheus, Grafana ou d’autres outils open-source si besoin.

---

### FAQ Migration

- **Puis-je migrer mes utilisateurs existants ?**  
  Oui, il suffit de générer une NOSTR Card pour chaque utilisateur et de leur communiquer leur nouvelle identité.
- **Comment gérer les permissions ?**  
  Les accès sont contrôlés par la possession de la clé NOSTR/IPNS. Vous pouvez gérer des ACLs via des tags ou des scripts personnalisés.
- **Comment migrer une base de données relationnelle ?**  
  Exportez vos tables (CSV, JSON), puis publiez chaque ligne comme événement NOSTR ou fichier IPFS. Pour les relations, utilisez des tags ou des liens dans les contenus.
- **Comment superviser mon nœud ?**  
  Utilisez les endpoints `/health` et `/rate-limit-status` de l’API, et surveillez les logs. Intégrez Prometheus/Grafana pour des métriques avancées.
- **Comment gérer le CI/CD ?**  
  Utilisez vos outils habituels (GitHub Actions, GitLab CI, etc.) pour déployer scripts, bots et configurations. Privilégiez l’infrastructure as code (Ansible, Terraform).
- **Quelles sont les limites de stockage ?**  
  Dépend de la capacité de votre nœud et du réseau IPFS. Vous pouvez ajouter de l’espace disque à tout moment.
- **Comment migrer mes buckets S3 ou Azure Blob ?**  
  Utilisez `aws s3 sync` ou `azcopy` pour exporter, puis `ipfs add` ou `/api/upload` pour importer dans UPlanet.
- **Comment migrer mes triggers Lambda/Functions ?**  
  Reprenez la logique dans des scripts bash/python, et déclenchez-les via cron, événements NOSTR, ou webhooks.

---

## Génération de Comptes et de Clés

Contrairement aux plateformes classiques où les utilisateurs créent des clés aléatoires, les comptes UPlanet sont générés et émis par le relai via des scripts dédiés :

- `make_NOSTRCARD.sh` : Génère une NOSTR Card complète pour un utilisateur, incluant :
  - Paire de clés NOSTR (privée/publique)
  - Portefeuille Ğ1 (preuve d’humanité)
  - Espace de stockage IPFS personnel et coffre IPNS
  - QR codes d’accès sécurisés
- `NOSTRCARD.refresh.sh` : Maintient et met à jour les NOSTR Cards, gère les paiements et synchronise les données utilisateur.

**Les clés ne sont pas aléatoires :** Elles sont générées de façon déterministe et enregistrées par le relai, garantissant une identité unique, récupérable, et liée à l’email et la géolocalisation de l’utilisateur.

---

## Authentification et Accès API

Tous les endpoints de l’API requièrent une authentification via une NOSTR Card valide. Seuls les comptes créés par les scripts du relai (`make_NOSTRCARD.sh`, `NOSTRCARD.refresh.sh`) sont autorisés.

**L’authentification repose sur NOSTR (NIP-42) :**
- L’utilisateur signe un événement d’authentification avec sa clé privée NOSTR.
- Le backend vérifie l’événement et accorde l’accès à l’espace de stockage et aux services décentralisés de l’utilisateur.

**Principaux endpoints API :**

| Endpoint           | Méthode | Description                   | Authentification |
|--------------------|---------|-------------------------------|------------------|
| `/api/upload`      | POST    | Upload vers uDRIVE            | NOSTR Card       |
| `/api/delete`      | POST    | Suppression de fichier        | NOSTR Card       |
| `/api/test-nostr`  | POST    | Test d’authentification       | NOSTR Card       |
| `/`                | GET     | Statut, découverte territoire | Publique         |

**Exemple : Upload de fichier avec authentification NOSTR**

```js
async function uploadFile(file, npub) {
    const formData = new FormData();
    formData.append('npub', npub);
    formData.append('file', file);
    const response = await fetch('/api/upload', { method: 'POST', body: formData });
    return await response.json();
}
```

---

## Stockage Décentralisé et Géolocalisation

- **Stockage sur IPFS :** Chaque utilisateur dispose d’un coffre IPNS personnel, accessible via sa NOSTR Card.
- **Indexation géolocalisée :** Les données sont organisées par grille UMAP/SECTOR/REGION/ZONE (de 0,01° à 10°), permettant des requêtes et applications basées sur la localisation.
- **Aucun serveur central :** Toutes les données sont distribuées, résistantes à la censure, et détenues par l’utilisateur.

**Exemple API : Découverte de territoire**

```http
GET /?lat=48.85&lon=2.35&deg=0.01
```

Retourne les 4 UMAPs les plus proches, les joueurs et comptes NOSTR à proximité.

---

## Intégration Frontend

**Utilisation de la NOSTR Card dans le navigateur :**

- Utiliser la librairie NostrTools (hébergée sur IPFS) :

```html
<script src="https://ipfs.copylaradio.com/ipfs/QmXEmaPRUaGcvhuyeG99mHHNyP43nn8GtNeuDok8jdpG4a/nostr.bundle.js"></script>
```

- Générer et utiliser les clés (pour test/démo ; en production, utiliser les clés émises par le relai) :

```js
const privateKey = NostrTools.generatePrivateKey();
const publicKey = NostrTools.getPublicKey(privateKey);

const authEvent = {
  kind: 22242,
  created_at: Math.floor(Date.now() / 1000),
  tags: [
    ['relay', 'ws://127.0.0.1:7777'],
    ['challenge', 'astroport-auth-' + Date.now()]
  ],
  content: 'Authentification pour Astroport.ONE UPassport API'
};
const signedEvent = NostrTools.finishEvent(authEvent, privateKey);
```

- Authentifier et uploader des fichiers comme montré ci-dessus.

---

## Backend Programmable (ASTROBOT)

Les nœuds UPlanet peuvent exécuter des bots programmables (ASTROBOT) pour automatiser des tâches, traiter des données, et déclencher des actions selon les événements NOSTR, la géolocalisation ou des règles définies par l’utilisateur.

---

## Monétisation et Zen Card

- **Ẑen Card :** Chaque utilisateur dispose d’un portefeuille pour le stablecoin Ẑen, émis par la « banque centrale » UPlanet.
- **Paiements intégrés :** Payer l’hébergement, des fonctionnalités ou des abonnements directement depuis le portefeuille décentralisé.
- **Récompenses et gamification :** Les applications peuvent récompenser les utilisateurs en Ẑen pour leur participation ou leurs succès.

---

## UPlanet vs AWS/Google Cloud

| Fonctionnalité           | AWS/Google Cloud         | UPlanet (Astroport.ONE)      |
|-------------------------|-------------------------|------------------------------|
| Coût                    | Élevé, à l’usage        | Faible, forfait Ẑen          |
| Verrouillage            | Propriétaire            | 100% Open Source             |
| Localisation des données| Serveurs US/EU          | Hébergé chez vous/vos pairs  |
| Authentification        | Centralisée (Cognito)   | Décentralisée (NOSTR Card)   |
| Stockage                | S3, propriétaire        | IPFS, propriété utilisateur  |
| Backend programmable    | Lambda, propriétaire    | ASTROBOT, open-source        |
| Paiements               | Carte, fiat             | Stablecoin Ẑen, intégré      |

---

## Pour démarrer

1. **Créer une NOSTR Card**  
   Utiliser les scripts fournis sur votre nœud :
   ```bash
   ./Astroport.ONE/tools/make_NOSTRCARD.sh user@example.com
   ```
   Cela génère la paire de clés NOSTR, le portefeuille Ğ1 et l’espace IPFS.

2. **S’authentifier auprès de l’API**  
   Utiliser la NOSTR Card pour signer les événements d’authentification et interagir avec les endpoints API.

3. **Développer votre application**  
   Intégrer la librairie NostrTools côté frontend, et utiliser l’API pour stocker, récupérer et gérer les données.

---

## Contact & Support

- Documentation : https://astroport-1.gitbook.io/astroport.one/
- Email : support@qo-op.com
- Communauté : https://copylaradio.com

---

**UPlanet/Astroport.ONE : Backend décentralisé, programmable et centré utilisateur pour la nouvelle génération d’applications.**

---

**Prêt à migrer ?**  
Contactez-nous pour un diagnostic gratuit et rejoignez le web décentralisé ! 