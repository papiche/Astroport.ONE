# 📝 Système de Documents Collaboratifs - UMAP Commons

## Vue d'ensemble

Le système de Documents Collaboratifs permet aux citoyens d'une UMAP de co-rédiger, valider et maintenir des documents partagés définissant le "commun" de leur territoire. 

**Processus de validation :**
1. Les utilisateurs publient leurs propositions (signées avec leur clé personnelle)
2. La communauté vote via des likes (kind 7)
3. Les documents populaires (suffisamment likés) sont **republiés par l'UMAP** pour officialiser la décision collective

## 🎯 Objectifs

### Mission Principale
**Faciliter la gouvernance participative territoriale** en permettant :
- La définition collective des règles du commun
- La rédaction collaborative de projets
- La prise de décision par vote
- La gestion partagée des ressources
- Le suivi des Obligations Réelles Environnementales (ORE)

### Cas d'Usage

| Type | Icône | Description | Exemple |
|------|-------|-------------|---------|
| **Commun** | 🤝 | Règles et ressources partagées | Charte du quartier |
| **Projet** | 🎯 | Projet collectif | Création jardin partagé |
| **Décision** | 🗳️ | Proposition à voter | Choix du nom de la place |
| **Jardin** | 🌱 | Plan de jardin (ORE) | Calendrier de plantation |
| **Ressource** | 📦 | Inventaire de ressources | Outils partagés |

## 📱 Interface Utilisateur : `collaborative-editor.html`

### Emplacement
```
UPlanet/earth/collaborative-editor.html
```

### Accès
```
https://[IPFS_GATEWAY]/ipns/copylaradio.com/collaborative-editor.html?lat=43.60&lon=1.44
https://[IPFS_GATEWAY]/ipns/copylaradio.com/collaborative-editor.html?lat=43.60&lon=1.44&doc=<event_id>
```

### Fonctionnalités

| Section | Fonction | Description |
|---------|----------|-------------|
| **Header** | Connexion Nostr | Authentification via extension (nos2x, Alby) |
| **Éditeur** | Rédaction Markdown | Éditeur WYSIWYG Milkdown |
| **Sidebar** | Workflow | Guide des étapes de publication |
| **Sidebar** | Propositions | Liste des documents en attente de vote |
| **Sidebar** | Historique | Versions précédentes |
| **Modales** | Charger/Proposer | Gestion des documents |

### Éditeur Milkdown

L'éditeur utilise [Milkdown](https://milkdown.dev/), un éditeur Markdown modulaire basé sur ProseMirror :

**Fonctionnalités supportées :**
- Titres (H1, H2, H3)
- **Gras**, *italique*, ~~barré~~
- Listes à puces et numérotées
- Listes de tâches (- [ ] / - [x])
- Citations (blockquote)
- Code inline et blocs de code
- Tableaux
- Liens et images
- Historique (undo/redo)

## 🔄 Workflow Collaboratif

### Étapes du Processus

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    WORKFLOW DE CO-ÉDITION UMAP                              │
└─────────────────────────────────────────────────────────────────────────────┘

  1. CONNEXION                    2. RÉDACTION                   3. PROPOSITION
  ─────────────────              ─────────────────              ─────────────────
  • Extension Nostr              • Éditeur Milkdown             • Résumé des modifs
  • Identification               • Templates par type           • Choix du quorum
  • Clé publique                 • Sauvegarde auto              • Politique de fork
        │                              │                              │
        └──────────────────────────────┴──────────────────────────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │  Publication    │
                              │  kind 30023     │
                              │  (Article)      │
                              └────────┬────────┘
                                       │
                                       ▼
  4. VALIDATION                   5. RÉSULTAT
  ─────────────────              ─────────────────
  • ✅ Approuver                 • Quorum atteint → MERGE
  • ❌ Rejeter                   • Rejet → FORK disponible
  • 🔀 Demander fork             • Document mis à jour
```

### Système de Gouvernance

| Mode | Description | Quorum |
|------|-------------|--------|
| **Majorité** | Plus d'approbations que de rejets | Configurable (défaut: 2) |
| **Unanimité** | Tous les éditeurs doivent approuver | Tous |
| **Owner-only** | Seul le propriétaire peut modifier | 1 |

### Politique de Fork

| Politique | Description |
|-----------|-------------|
| **allowed** | Fork autorisé à tout moment |
| **restricted** | Fork uniquement si proposition rejetée |
| **forbidden** | Aucun fork autorisé |

## 📊 Structure des Événements Nostr

### Kind 30023 - Document Collaboratif

```json
{
  "kind": 30023,
  "pubkey": "<UMAP_PUBKEY>",
  "content": "# Définition du Commun\n\n## Objectif\n...",
  "tags": [
    ["d", "doc-43.60-1.44-1704931200"],
    ["title", "Charte du Quartier"],
    ["t", "collaborative"],
    ["t", "UPlanet"],
    ["t", "commons"],
    ["g", "43.60,1.44"],
    ["author", "<original_author_pubkey>"],
    ["version", "1"],
    ["quorum", "2"],
    ["governance", "majority"],
    ["fork-policy", "allowed"],
    ["content-hash", "sha256:..."],
    ["change-summary", "Création initiale"],
    ["published_at", "1704931200"]
  ]
}
```

**Tags obligatoires :**

| Tag | Description | Exemple |
|-----|-------------|---------|
| `d` | Identifiant unique (NIP-33) | `doc-43.60-1.44-1704931200` |
| `title` | Titre du document | `Charte du Quartier` |
| `t` | Hashtags | `collaborative`, `UPlanet`, `commons` |
| `g` | Géolocalisation | `43.60,1.44` |
| `author` | Pubkey de l'auteur original | `hex_pubkey` |
| `version` | Numéro de version | `1`, `2`, `3`... |

**Tags de gouvernance :**

| Tag | Description | Valeurs |
|-----|-------------|---------|
| `quorum` | Nombre de votes requis | `1`, `2`, `3`, `unanimous` |
| `governance` | Mode de gouvernance | `majority`, `unanimous`, `owner-only` |
| `fork-policy` | Politique de fork | `allowed`, `restricted`, `forbidden` |

**Tags de versioning :**

| Tag | Description |
|-----|-------------|
| `previous-version` | ID de l'événement précédent |
| `content-hash` | Hash SHA-256 du contenu |
| `change-summary` | Description des modifications |

### Kind 7 - Vote (Réaction)

```json
{
  "kind": 7,
  "pubkey": "<voter_pubkey>",
  "content": "✅",
  "tags": [
    ["e", "<document_event_id>"],
    ["vote", "approve"],
    ["t", "collaborative-vote"],
    ["t", "UPlanet"]
  ]
}
```

**Types de votes :**

| Vote | Emoji | Tag vote |
|------|-------|----------|
| Approuver | ✅ ou + ou 👍 | `approve` |
| Rejeter | ❌ ou - ou 👎 | `reject` |
| Fork | 🔀 | `fork` |

## 🔗 Intégration avec l'Écosystème

### Lien depuis umap_index.html

Le template `umap_index.html` inclut :

1. **Bouton dans le header** :
```html
<a href="_MYIPFS_/ipns/copylaradio.com/collaborative-editor.html?lat=_LAT_&lon=_LON_" 
   class="btn btn-primary">
    📝 Commons Editor
</a>
```

2. **Section Commons Documents** dans la sidebar :
```html
<div class="card">
    <div class="card-header">
        <span>📄</span> Commons Documents
        <span class="card-badge">_DOCSCOUNT_</span>
    </div>
    <div class="card-content">
        _COMMONSDOCS_
    </div>
</div>
```

### Agrégation par NOSTR.UMAP.refresh.sh

Le script `NOSTR.UMAP.refresh.sh` agrège automatiquement les documents collaboratifs :

```bash
# Query collaborative documents from local strfry relay
collab_docs=$(./strfry scan "{
    \"kinds\": [30023],
    \"limit\": 20
}" | jq -c 'select(.tags | map(select(.[0] == "t" and .[1] == "collaborative")) | length > 0)')
```

**Données extraites :**
- Titre du document
- Version
- Type (commons, project, decision, garden, resource)
- Nombre de likes
- Date de création

**Placeholders générés :**
- `_DOCSCOUNT_` : Nombre de documents
- `_COMMONSDOCS_` : HTML des documents pour la sidebar

### Lien avec PlantNet/ORE

Le type `garden` intègre le système ORE (Obligations Réelles Environnementales) :

```
Observation PlantNet (kind 1)
         ↓
Bot IA génère contrat (kind 30023 + #contract)
         ↓
Utilisateur crée Plan de Jardin (kind 30023 + #garden)
         ↓
Communauté valide (kind 7 likes)
         ↓
UMAP agrège et calcule score ORE
```

## 🔐 Publication UMAP (Documents Populaires)

### Principe

Les documents collaboratifs suivent un processus de validation démocratique :
1. **Les utilisateurs publient** leurs propositions (signées avec leur propre clé)
2. **La communauté vote** via des likes (kind 7)
3. **L'UMAP republie** automatiquement les documents les plus populaires

Quand un document atteint un seuil de likes suffisant, `NOSTR.UMAP.refresh.sh` le republie avec la clé de l'UMAP, officialisant ainsi la décision collective.

### Workflow de Publication UMAP

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VALIDATION ET PUBLICATION UMAP                            │
└─────────────────────────────────────────────────────────────────────────────┘

  Utilisateur publie                 Communauté vote              UMAP officialise
  ─────────────────                 ─────────────────            ─────────────────
  kind 30023                        kind 7 (likes)               kind 30023
  signé par USER                    ✅ +1, 👍, ❤️                signé par UMAP
        │                                 │                            │
        └─────────────────────────────────┴────────────────────────────┘
                                          │
                                          ▼
                              ┌─────────────────────┐
                              │ NOSTR.UMAP.refresh  │
                              │ compte les likes    │
                              │ seuil atteint ?     │
                              └──────────┬──────────┘
                                         │
                          ┌──────────────┴──────────────┐
                          ▼                             ▼
                    likes < seuil                 likes ≥ seuil
                    (reste proposal)              (UMAP publie)
```

### Seuils de Validation

| Niveau | Seuil | Description |
|--------|-------|-------------|
| **UMAP** | ≥ 3 likes | Document adopté par l'UMAP locale |
| **SECTOR** | ≥ 6 likes | Propagé au niveau secteur (0.1°) |
| **REGION** | ≥ 12 likes | Propagé au niveau région (1°) |

### Script de Publication : `nostr_send_note.py`

La publication officielle par l'UMAP utilise `nostr_send_note.py` avec le keyfile de l'UMAP :

```bash
# Le keyfile UMAP est généré lors de la création de l'UMAP
UMAP_KEYFILE="~/.zen/game/nostr/UMAP_${LAT}_${LON}/.secret.nostr"

# Publication du document officiel
python3 nostr_send_note.py \
    --keyfile "$UMAP_KEYFILE" \
    --kind 30023 \
    --content "$DOCUMENT_CONTENT" \
    --tags '[
        ["d", "commons-43.60-1.44-charte"],
        ["title", "Charte du Quartier"],
        ["t", "collaborative"],
        ["t", "commons"],
        ["t", "UPlanet"],
        ["g", "43.60,1.44"],
        ["original-author", "npub1..."],
        ["original-event", "event_id_original"],
        ["likes", "7"],
        ["adopted-at", "1704931200"]
    ]'
```

### Génération de la clé UMAP

La clé UMAP est générée de manière déterministe à partir des coordonnées :

```bash
# Génération initiale (fait une seule fois par NOSTR.UMAP.refresh.sh)
UMAP_SALT="${UPLANETNAME}${LAT}"
UMAP_PEPPER="${UPLANETNAME}${LON}"

UMAP_NSEC=$(keygen -t nostr "$UMAP_SALT" "$UMAP_PEPPER" -s)
UMAP_NPUB=$(keygen -t nostr "$UMAP_SALT" "$UMAP_PEPPER")

# Création du keyfile
echo "NSEC=${UMAP_NSEC}; NPUB=${UMAP_NPUB};" > ~/.zen/game/nostr/UMAP_${LAT}_${LON}/.secret.nostr
```

### Tags Spéciaux pour Documents Adoptés

Quand l'UMAP republie un document, elle ajoute des tags spéciaux :

| Tag | Description | Exemple |
|-----|-------------|---------|
| `original-author` | Pubkey de l'auteur initial | `npub1abc...` |
| `original-event` | ID de l'événement original | `event_id` |
| `likes` | Nombre de likes au moment de l'adoption | `7` |
| `adopted-at` | Timestamp de l'adoption | `1704931200` |

## 📅 Cycle de Vie des Documents

### 1. Création

```
Utilisateur connecté
    │
    ├─ Choisit type de document
    ├─ Rédige avec template
    ├─ Configure gouvernance
    │
    └─→ Publication kind 30023
        • Signé par utilisateur (ou UMAP si serveur)
        • Tag author = utilisateur
        • Version = 1
```

### 2. Proposition de Modification

```
Autre utilisateur
    │
    ├─ Charge document existant
    ├─ Modifie contenu
    ├─ Décrit les changements
    │
    └─→ Publication kind 30023 (nouvelle version)
        • Tag previous-version = ancien ID
        • Version = N+1
        • Tag change-summary = description
```

### 3. Validation par Vote

```
Communauté
    │
    ├─ Voit propositions dans sidebar
    ├─ Vote (approve/reject/fork)
    │
    └─→ Publication kind 7
        • content = ✅/❌/🔀
        • Tag vote = approve/reject/fork
        • Tag e = document_id
```

### 4. Résolution

```
Système vérifie quorum
    │
    ├─ Si approuvé → Document devient version officielle
    ├─ Si rejeté → Fork possible
    │
    └─→ Notification aux éditeurs
```

### 5. Agrégation UMAP

```
NOSTR.UMAP.refresh.sh (cron)
    │
    ├─ Scan documents collaboratifs
    ├─ Compte likes par document
    ├─ Génère HTML pour index.html
    │
    └─→ Mise à jour umap_index.html
        • _DOCSCOUNT_
        • _COMMONSDOCS_
```

## 🔄 Comparaison avec Autres Systèmes

### Documents Collaboratifs vs Journaux N²

| Aspect | Documents Collaboratifs | Journaux N² |
|--------|------------------------|-------------|
| **Kind** | 30023 | 30023 |
| **Auteur** | UMAP (collectif) | MULTIPASS (individuel) |
| **Contenu** | Rédigé par humains | Généré par IA |
| **Validation** | Vote communautaire | Automatique |
| **Fréquence** | À la demande | Daily/Weekly/Monthly/Yearly |
| **Réseau** | Géographique (UMAP) | Social (N²) |

### Documents Collaboratifs vs PlantNet

| Aspect | Documents Collaboratifs | PlantNet |
|--------|------------------------|----------|
| **Objectif** | Gouvernance | Inventaire biodiversité |
| **Type contenu** | Texte Markdown | Photos + identification |
| **Validation** | Vote quorum | Likes + 28 jours |
| **Kind réponse** | N/A | Bot IA génère kind 1 + 30023 |

## 🏗️ Architecture Technique

### Fichiers Principaux

```
UPlanet/
├── earth/
│   └── collaborative-editor.html  # Interface utilisateur

Astroport.ONE/
├── templates/NOSTR/
│   └── umap_index.html           # Template avec section Commons
├── tools/
│   ├── nostr_send_note.py        # Publication Nostr (utilisé par UMAP)
│   └── keygen                    # Génération clés UMAP
├── RUNTIME/
│   └── NOSTR.UMAP.refresh.sh     # Agrégation et publication UMAP
└── docs/
    └── COLLABORATIVE_COMMONS_SYSTEM.md  # Cette documentation
```

### Dépendances

| Composant | Technologie | Rôle |
|-----------|-------------|------|
| **Éditeur** | Milkdown | Édition Markdown WYSIWYG |
| **Nostr Client** | nostr.bundle.js | Protocole de publication (côté client) |
| **Nostr Server** | nostr_send_note.py | Publication UMAP (côté serveur) |
| **Common** | common.js | Fonctions partagées UPlanet |
| **Relay** | strfry | Stockage local des événements |
| **Keygen** | keygen | Génération clés UMAP déterministes |

### Événements Nostr Utilisés

| Kind | Nom | Usage |
|------|-----|-------|
| **30023** | Long-form Content | Documents collaboratifs |
| **7** | Reaction | Votes (✅❌🔀) |
| **1** | Short Text Note | Notifications |

## 🎮 Règles d'Utilisation

### Pour les Auteurs

1. **Connectez-vous** avec une extension Nostr
2. **Choisissez le type** de document approprié
3. **Rédigez clairement** avec les templates fournis
4. **Décrivez vos modifications** lors des propositions
5. **Configurez le quorum** selon l'importance du document

### Pour les Validateurs

1. **Examinez les propositions** dans la sidebar
2. **Comparez avec la version précédente** si modification
3. **Votez ✅** si la proposition améliore le document
4. **Votez ❌** si la proposition pose problème
5. **Demandez un 🔀 fork** si vous voulez une version alternative

### Bonnes Pratiques

- **Un document = Un sujet** : Évitez les documents trop généraux
- **Versionning explicite** : Décrivez chaque modification
- **Quorum adapté** : Plus le document est important, plus le quorum doit être élevé
- **Fork raisonné** : Ne forkez que si vraiment nécessaire

## 🔗 Liens Utiles

- **Interface** : `UPlanet/earth/collaborative-editor.html`
- **Template UMAP** : `Astroport.ONE/templates/NOSTR/umap_index.html`
- **Script refresh** : `Astroport.ONE/RUNTIME/NOSTR.UMAP.refresh.sh`
- **Publication Nostr** : `Astroport.ONE/tools/nostr_send_note.py`
- **Système PlantNet** : `Astroport.ONE/docs/PLANTNET_SYSTEM.md`
- **Journaux N²** : `Astroport.ONE/docs/JOURNAUX_N2_NOSTRCARD.md`
- **Système ORE** : `Astroport.ONE/docs/ORE_SYSTEM.md`

---

*Documentation générée pour le projet UPlanet - Gouvernance Territoriale Décentralisée*
