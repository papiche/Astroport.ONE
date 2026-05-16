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
~/.zen/Astroport.ONE/IA/UPlanet_IA_Responder.sh
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
<script src="https://ipfs.copylaradio.com/ipns/copylaradio.com/nostr.bundle.js"></script>
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

## MineLife WoTx2 — Crafting Décentralisé de Compétences

MineLife est le protocole de certification décentralisée de compétences d’UPlanet. Inspiré de Minecraft, il permet à toute communauté de créer ses propres "recettes" de compétences et de les valider collectivement, sans autorité centrale.

### Kinds NOSTR utilisés

| Kind | Rôle | Signataire |
|------|------|------------|
| `30500` | Définition de permit (recette de craft) | Tout utilisateur |
| `30501` | Demande d’apprentissage (aspiration X1) | Apprenti |
| `30502` | Adoubement par un pair X1+ (Règle B) | Pair certifié |
| `30503` | Certificat de compétence | Oracle / joueur / auto |
| `30504` | Ressource de formation (vidéo, PDF, article) | Tout contributeur |
| `7` | Réaction de validation (3× = Règle A) | Pair certifié |
| `4` | DM chiffré BRO (NIP-04) — assistance IA | Joueur → NODE |

### Modes de validation

```
Mode Oracle   → ORACLE.refresh.sh émet Kind 30503 (signé UPLANETNAME_G1)
Mode P2P      → Règle A : 3× Kind 7  OU  Règle B : 1× Kind 30502 (pair X1+)
Mode Folkso   → Auto-proclamation + tag t + level (TrocZen offline)
```

### Profil MULTIPASS (Kind 0) — champ home_station

```json
{
  "content": "{ \"home_station\": \"IPFSNODEID:NODE_HEX_64\", \"g1pub\": \"...\" }",
  "tags": [["i", "home_station:IPFSNODEID:NODE_HEX_64", ""]]
}
```

Le champ `home_station` est la source authoritative pour l’adresse BRO (Kind 4 DM).

### Exemple : Permit composite

```json
{
  "kind": 30500,
  "tags": [
    ["d", "PERMIT_DEVOPS_X1"],
    ["t", "permit"], ["t", "composite"],
    ["requires", "linux", "1"],
    ["requires", "docker", "1"],
    ["r", "/ipfs/Qm.../formation-devops.pdf", "document"]
  ],
  "content": "{\"name\":\"DevOps Station\",\"icon\":\"⚙️\"}"
}
```

### BRO — Assistant IA via Kind 4

```js
// Envoyer une commande BRO
const bro = { kind: 4, tags: [["p", NODE_HEX_64]], content: NIP04.encrypt("Aide BRO #badge linux") };
```

Commandes : question libre (RAG Ollama), `#badge <skill>` (ComfyUI → IPFS), `#rec <skill>`, `#mem <note>`.

Fichiers clés : `UPlanet/earth/minelife.html`, `Astroport.ONE/IA/bro_dm_daemon.sh`, `Astroport.ONE/RUNTIME/ORACLE.refresh.sh`.

---

## NIP-42 Roaming — Authentification Inter-Stations

Le protocole NIP-42 Roaming permet à un utilisateur MULTIPASS de s’authentifier sur n’importe quelle station de la constellation, même si son compte est hébergé sur une autre.

### Flux en 9 étapes (roaming.html)

1. **Détection de l’extension** : window.nostr.getPublicKey() (NIP-07)
2. **Challenge NIP-42** : GET `/api/nip42/challenge` → challenge unique
3. **Signature kind 22242** : `{ tags: [["relay", relayUrl], ["challenge", ch]] }`
4. **Vérification locale** : check_authorization via relay strfry local (kind 0)
5. **Vérification swarm** : lookup dans les stations voisines (`~/.zen/tmp/swarm/`)
6. **Vérification amisOfAmis** : N² — amis des amis de la station courante
7. **Récupération profil** : Kind 0 MULTIPASS avec `home_station`
8. **Connexion uDrive** : accès au stockage IPFS personnel (upload `/api/upload`)
9. **Réponse finale** : autorisation accordée / refusée avec raison

### Script côté serveur

```bash
# NIP-101/relay.writePolicy.plugin/filter/22242.sh
# check_authorization $NPUB $RELAY_URL
# Retourne 0 (autorisé) ou 1 (refusé)
# Sources de vérification : local → swarm → amisOfAmis
```

### Filtre NIP-101 par kind

Le plugin `writePolicy` de strfry filtre les événements NOSTR par kind :

| Script | Kind(s) | Règle |
|--------|---------|-------|
| `0.sh` | 0 (profil) | Seuls les MULTIPASS de la station autorisés |
| `1.sh` | 1 (note) | Membres N² uniquement |
| `7.sh` | 7 (réaction) | Membres N² uniquement |
| `21.sh` / `22.sh` | 21/22 (NIP-71 vidéo) | Porteurs MULTIPASS |
| `1984.sh` | 1984 (signalement) | Filtrage anti-spam |
| `9735.sh` | 9735 (zap) | Vérification ZenCard |
| `30023.sh` | 30023 (article NIP-23) | Membres N² |
| `30500.sh` | 30500–30504 (WoTx2) | MULTIPASS station |

```bash
# Installation
cd NIP-101
./install.sh           # strfry + write-policy plugin
./setup.sh             # génère strfry.conf adapté au hardware
./start_strfry-relay.sh
```

---

## Système de Feedback — AGPL-3.0 & feedback.js

Toutes les applications UPlanet sont publiées sous **AGPL-3.0**. En choisissant cette licence, les développeurs s'engagent envers leurs utilisateurs : chacun peut les contacter et obtenir le code source. `feedback.js` concrétise cet engagement.

`UPlanet/earth/feedback.js` fournit un système de retour utilisateur intégré à toutes les pages :

- **Capture console** : intercepte `console.log/warn/error` → `sessionStorage`
- **Badge AGPL** : auto-injecte le lien de licence + bouton "Signaler un bug"
- **Rapport NOSTR-signé** : soumet le rapport via `POST /api/feedback` (signature NIP-07)
- **Relay déduit** : l’URL du relay est dérivée de l’URL de la page (`u.domain` → `relay.domain`)
- **Persistance NOSTR** : réutilise la session NOSTR existante (window.nostr / NostrState)

```js
// Intégration minimale
<script src="/earth/feedback.js"></script>
// → badge AGPL + bouton feedback injectés automatiquement

// Ouverture manuelle
window.openFeedbackPage();  // snapshot logs → feedback.html dans nouvel onglet
```

La page `feedback.html` affiche les logs capturés depuis la page source, propose un formulaire de description, et signe le rapport NOSTR avant envoi.

---

## astrosystemctl — CLI P2P Cloud

`tools/astrosystemctl.sh` est le CLI de gestion des services P2P de la constellation :

```bash
astrosystemctl list             # Services locaux disponibles
astrosystemctl list-remote      # Brain-Nodes distants (power_score ≥ 41)
astrosystemctl connect <svc>    # Crée un tunnel IPFS P2P vers un service distant
astrosystemctl enable <svc>     # Rend le tunnel persistant (watchdog 20h12)
astrosystemctl disable <svc>    # Supprime le tunnel persistant
astrosystemctl status           # État des tunnels actifs
```

### Power-Score — GPS de Calcul

```
Power-Score = GPU_VRAM_GB × 4 + CPU_cores × 2 + RAM_GB × 0.5
```

| Score | Tier | Profil | Rôle |
|-------|------|--------|------|
| 0–10 | 🌿 Light | Raspberry Pi Zero/3 | Consommateur uniquement |
| 11–40 | ⚡ Standard | PC bureautique | Petits modèles locaux |
| 41+ | 🔥 Brain | GPU dédié | Fournisseur swarm |

Le Power-Score est publié dans `12345.json` (`capacities.power_score`) et utilisé par `astrosystemctl list-remote` pour identifier les Brain-Nodes disponibles dans `~/.zen/tmp/swarm/*/12345.json`.

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
   ~/.zen/Astroport.ONE/tools/make_NOSTRCARD.sh user@example.com
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