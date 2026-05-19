# 🌱 PLANTNET_SYSTEM - Inventaire Participatif UPlanet

Le système PlantNet de UPlanet est un jeu collaboratif d'inventaire territorial qui permet aux citoyens de photographier et cataloguer les éléments de leur environnement, créant ainsi un "cadastre vivant" de la biodiversité et des ressources locales.

## 🎯 Objectifs du Jeu

### Mission Principale
**Assurer l'autonomie alimentaire collective** en :
- Inventoriant la biodiversité locale (plantes, insectes, animaux)
- Cataloguant les équipements partagés (outils, infrastructures)
- Identifiant les lieux d'intérêt (jardins, points d'eau)
- Coordonnant la chaîne de transformation de valeur

### Chaîne de Valeur Partagée

```
🌱 Graine     →    🌿 Plantation    →    💧 Entretien    →    🍅 Récolte    →    🥫 Conserve
   │                │                     │                    │                  │
   └─ Sélection     └─ Semis &            └─ Arrosage &        └─ Cueillette      └─ Stockage &
      & échange        repiquage            soins                optimale            partage
```

Chaque participant peut se spécialiser sur une étape. Le calendrier lunaire synchronise les efforts pour que les récoltes des uns deviennent les semences des autres.

## 📱 Interface Utilisateur : `plantnet.html`

### Emplacement
```
UPlanet/earth/plantnet.html
```

### Fonctionnalités

| Onglet | Fonction | Description |
|--------|----------|-------------|
| 🗺️ **Atlas** | Vue d'ensemble | Carte interactive des éléments inventoriés, statistiques, progression ORE |
| 📸 **Inventaire** | Galerie | Photos et contrats de maintenance générés |
| 📷 **Contribuer** | Participation | Upload de photos géolocalisées, sélection du type d'élément |
| 💚 **Autonomie** | Calendrier | Calendrier lunaire, styles de production, export iCal |

### Types d'Inventaire Supportés

| Type | Icône | Couleur | Reconnaissance |
|------|-------|---------|----------------|
| `plant` | 🌱 | Vert `#22c55e` | PlantNet API (espèces, famille, wiki) |
| `insect` | 🐛 | Orange `#f59e0b` | IA générique |
| `animal` | 🦊 | Rose `#ec4899` | IA générique |
| `object` | 🔧 | Indigo `#6366f1` | IA générique (équipements) |
| `place` | 🏠 | Teal `#14b8a6` | IA générique (lieux) |
| `person` | 👤 | Violet `#8b5cf6` | IA générique (personnes clés) |

## 🔄 Workflow Complet

### 1. Publication par l'Utilisateur

L'utilisateur prend une photo et la publie via `plantnet.html` :

```javascript
// Événement Nostr Kind 1
{
  kind: 1,
  content: "🌱 Inventaire UPlanet\n📍 Position: 43.60, 1.44\n📸 Photo: https://ipfs.../image.jpg\n#plant #UPlanet #BRO #inventory",
  tags: [
    ["t", "plant"],
    ["t", "UPlanet"],
    ["t", "BRO"],
    ["t", "inventory"],
    ["t", "plantnet"],  // Pour les plantes uniquement
    ["g", "43.60,1.44"],
    ["imeta", "url https://ipfs.../image.jpg", "m image/jpeg"]
  ]
}
```

**Tags requis :**
- `#BRO` : Active la réponse du bot IA
- `#inventory` : Marque comme inventaire
- `#[type]` : Type d'élément (plant, insect, animal, object, place)
- `#plantnet` : (optionnel) Force la reconnaissance PlantNet pour les plantes

### 2. Traitement par le Bot IA

Le script `Astroport.ONE/IA/UPlanet_IA_Responder.sh` détecte les messages `#BRO` et :

```bash
# Détection des tags
if [[ "$message_text" =~ \#BRO ]]; then TAGS[BRO]=true; fi
if [[ "$message_text" =~ \#plantnet ]]; then TAGS[plantnet]=true; fi
if [[ "$message_text" =~ \#inventory ]]; then TAGS[inventory]=true; fi
```

#### Pour les plantes (`#plantnet`) :
1. Télécharge l'image depuis IPFS
2. Envoie à l'API PlantNet
3. Récupère : nom scientifique, noms communs, confiance, lien Wikipedia

#### Pour les autres types :
1. Analyse l'image avec IA générique
2. Génère une description et un contrat de maintenance

### 3. Génération des Contrats

Le bot publie **3 événements** en réponse :

| Kind | Type | Contenu |
|------|------|---------|
| **1** | Note simple | Résumé sans markdown, photo, confiance, hashtags |
| **30023** | Article blog | Contenu riche en markdown avec image, détails complets, liens |
| **30312** | ORE Space | Espace géographique pour suivi et vérification |

**Exemple de contrat Kind 30023 :**
```markdown
# 🌱 Lavandula angustifolia

![Photo](https://ipfs.../image.jpg)

**Nom commun :** Lavande vraie
**Famille :** Lamiaceae
**Confiance :** 94.2%

## 📋 Contrat de Maintenance

- Arrosage : modéré, résistant à la sécheresse
- Taille : après floraison
- Multiplication : bouturage en été

📍 Position : 43.60°N, 1.44°E
🔗 [Wikipedia](https://fr.wikipedia.org/wiki/Lavandula_angustifolia)

---
#UPlanet #inventory #plant #ORE
```

### 4. Mise à Jour de la Biodiversité

Le bot appelle `OREBiodiversityTracker` (Python) :

```python
from ore_system import OREBiodiversityTracker

tracker = OREBiodiversityTracker('/path/to/umap')
result = tracker.add_inventory_observation(
    inventory_type='plant',
    item_name='Lavandula angustifolia',
    scientific_name='Lavandula angustifolia',
    observer_pubkey='hex_pubkey',
    confidence=0.942,
    image_url='https://ipfs.../image.jpg',
    nostr_event_id='event_id'
)
```

**Fichier mis à jour :** `ore_biodiversity.json`
```json
{
  "inventory": {
    "plant": {
      "count": 16,
      "items": {
        "Lavandula angustifolia": {
          "first_seen": "2025-06-15T10:30:00Z",
          "last_seen": "2025-06-15T10:30:00Z",
          "observations": 1,
          "confidence_avg": 0.942,
          "observers": ["hex_pubkey"]
        }
      }
    }
  },
  "diversity_score": 0.78,
  "total_observations": 43
}
```

### 5. Publication du DID UMAP

Le DID de l'UMAP (Kind 30800) est republié avec les nouvelles statistiques :

```json
{
  "kind": 30800,
  "tags": [
    ["d", "did"],
    ["g", "43.60,1.44"],
    ["diversity_score", "0.78"],
    ["biodiversity_score", "0.65"],
    ["species_count", "16"],
    ["total_observations", "43"],
    ["inventory_plant", "16"],
    ["inventory_object", "5"],
    ["inventory_insect", "3"]
  ],
  "content": "{...DID Document avec ore_metadata...}"
}
```

## 📊 Système de Score

### Diversity Score (0-1)

Le `diversity_score` évalue la richesse de l'inventaire d'une UMAP :

```
items_score       = min(total_weighted_items × 1.5, 50)
type_diversity    = min(types_with_items × 4, 20)
observation_score = min(total_observations × 0.3, 20)
observer_score    = min(observer_count × 2, 10)

diversity_score = min((sum) / 100, 1.0)
```

**Pondération par type :**
| Type | Poids |
|------|-------|
| `plant` | 2.0 |
| `insect` | 1.5 |
| `animal` | 1.5 |
| `object` | 1.0 |
| `place` | 1.0 |
| `person` | 0.5 |

### Progression ORE

**Seuil d'activation :** 8 éléments inventoriés dans une UMAP

Une fois le seuil atteint, le contrat ORE est activé et les récompenses en Ẑen peuvent être distribuées.

## 👍 Système de Validation (Likes)

### Principe
Les "likes" (Kind 7 reaction `+`) servent de :
- **Vote de confiance** : La communauté valide l'observation
- **Crédit de Ẑen** : Chaque like crédite des Ẑen au portefeuille UMAP

### Règle des 28 Jours

> ⚠️ **Important** : Si une observation n'a pas reçu de like dans les 28 jours, elle est **supprimée** avec ses contrats associés.

Cette règle évite l'accumulation de données non validées et encourage la participation communautaire.

**Implémentation :** `NOSTR.UMAP.refresh.sh` → `cleanup_inventory_without_likes()`

```bash
# Pseudo-code
for each inventory_event in umap:
    if event.age > 28_days:
        likes = count_kind7_reactions(event.id)
        if likes == 0:
            delete_event(event.id)
            delete_associated_contracts()
            notify_author("Observation supprimée faute de validation")
```

## 📅 Calendrier Lunaire & Styles de Production

L'onglet "Autonomie" propose un calendrier biodynamique avec plusieurs styles adaptés aux jardiniers de tous niveaux :

| Style | Icône | Description | Niveau |
|-------|-------|-------------|--------|
| **🌳 Forêt Jardin** | 🌳 | Écosystème comestible auto-entretenu, 7 strates verticales | ⭐ Débutant |
| **UMAP Optimisé** | 🏙️ | Maximiser la diversité sur petite surface (~1km²) | ⭐ Débutant |
| **Variété Nutritionnelle** | 🌿 | Couvrir tous les besoins alimentaires | ⭐ Débutant |
| **Autonomie Complète** | 🏡 | Produire 100% de sa nourriture | ⭐⭐⭐ Avancé |
| **Conservation Longue Durée** | 🥫 | Légumes de garde, stérilisation | ⭐⭐ Intermédiaire |
| **Production Continue** | 🔄 | Récoltes toute l'année | ⭐⭐⭐ Avancé |

### 🌳 Style Recommandé : Forêt Jardin

Le style **Forêt Jardin** est idéal pour les UMAPs car il :
- Crée un écosystème qui s'auto-entretient avec le temps
- Maximise la production sur 7 strates verticales
- Réduit le travail annuel (plantes pérennes)
- Favorise la biodiversité et les pollinisateurs
- S'adapte parfaitement aux débutants

**Les 7 strates de la Forêt Jardin :**
1. 🌳 **Canopée** : Arbres fruitiers hauts (pommiers, poiriers)
2. 🍎 **Arbres bas** : Fruitiers nains
3. 🫐 **Arbustes** : Baies, petits fruits (framboises, groseilles)
4. 🥬 **Herbacées** : Légumes perpétuels (chou Daubenton, oseille)
5. 🍓 **Couvre-sol** : Fraisiers, trèfle
6. 🥕 **Racines** : Ail des ours, topinambours
7. 🍇 **Grimpantes** : Vignes, kiwis

### 🌱 Guide Débutant : Rejoindre la Forêt Jardin UMAP

**Année 1 - Les bases :**
1. Plantez 2-3 arbres fruitiers (novembre = idéal)
2. Installez framboisiers et groseilliers
3. Semez trèfle et consoude (fertilité)
4. Paillez généreusement TOUT

**Année 2 - Développement :**
1. Ajoutez légumes perpétuels
2. Plantez couvre-sol (fraisiers)
3. Installez aromatiques pérennes
4. Premières récoltes de baies!

**Année 3+ - Maturité :**
- La forêt s'auto-gère
- Récoltes abondantes
- Très peu d'entretien

### 🤝 Les Guildes : Associations Bénéfiques

Une **guilde** est un groupe de plantes qui s'entraident :

**Guilde du Pommier :**
- 🍎 Pommier (centre)
- 🌿 Consoude (nutriments)
- ☘️ Trèfle (azote)
- 🌸 Capucines (piège à pucerons)
- 🧅 Ciboulette (répulsif)
- 🍓 Fraisiers (couvre-sol)

**Guilde des Tomates :**
- 🍅 Tomates (centre)
- 🌿 Basilic (répulsif + saveur)
- 🥕 Carottes (profondeur différente)
- 🌼 Œillets d'Inde (nématodes)

### Export iCal

Le calendrier peut être exporté en `.ics` avec :
- Semis optimaux selon les cycles lunaires
- Rappels d'entretien par strate (Forêt Jardin)
- Dates de récolte estimées
- Conseils pour débutants et progression
- Rappels de contribution UMAP
- Alertes météo générales

**Fonction :** `lunar-calendar.js` → `generateVegetarianGardenerICal(year, style)`

**Styles disponibles :** `foret`, `umap`, `variety`, `autonomy`, `conservation`, `continuous`

## 🏗️ Architecture Technique

### Fichiers Principaux

```
UPlanet/
├── earth/
│   ├── plantnet.html          # Interface utilisateur
│   └── lunar-calendar.js      # Fonctions calendrier lunaire

Astroport.ONE/
├── IA/
│   └── UPlanet_IA_Responder.sh  # Bot de traitement
├── tools/
│   └── ore_system.py          # OREBiodiversityTracker
├── RUNTIME/
│   └── NOSTR.UMAP.refresh.sh  # Cron de maintenance (nettoyage 28j)
└── docs/
    ├── PLANTNET_SYSTEM.md     # Cette documentation
    └── ORE_SYSTEM.md          # Système ORE complet
```

### Dépendances Externes

- **PlantNet API** : Reconnaissance des plantes
- **IPFS** : Stockage décentralisé des images
- **Nostr** : Réseau de publication des événements
- **Astronomy Engine** : Calculs lunaires précis (`astronomy.browser.min.js`)

### Events Nostr Utilisés

| Kind | Usage | NIP |
|------|-------|-----|
| 1 | Notes (observations, réponses) | NIP-01 |
| 7 | Réactions (likes/validation) | NIP-25 |
| 30023 | Articles (contrats de maintenance) | NIP-23 |
| 30312 | ORE Meeting Space | Custom |
| 30800 | DID Documents UMAP | NIP-101 |

## 🎮 Règles du Jeu

1. **Photographiez** un élément de votre territoire
2. **Publiez** via l'interface avec les bons hashtags
3. **Attendez** la réponse du bot (quelques secondes)
4. **Recevez** votre contrat de maintenance généré
5. **Faites voter** la communauté (likes = Ẑen)
6. **Contribuez** à la progression ORE de votre UMAP

### Objectifs Collectifs

- **8 éléments** : Activation du contrat ORE
- **Diversité** : Maximiser le `diversity_score`
- **Communauté** : Plus d'observateurs = meilleur score
- **Validation** : Likes dans les 28 jours

## 🔗 Liens Utiles

- **Interface** : `UPlanet/earth/plantnet.html`
- **Commons Editor** : `UPlanet/earth/collaborative-editor.html`
- **Système ORE** : `../explanation/ORE_SYSTEM.md`
- **Documents Collaboratifs** : `COLLABORATIVE_COMMONS_SYSTEM.md`
- **Journaux N²** : `../reference/JOURNAUX_N2_NOSTRCARD.md`
- **PlantNet** : https://plantnet.org
- **Nostr NIPs** : https://github.com/nostr-protocol/nips

## 🔄 Intégration avec les Documents Collaboratifs

Le système PlantNet s'intègre avec l'éditeur collaboratif de Commons pour permettre la création de plans de jardins validés par la communauté :

```
Observation PlantNet (kind 1 + #plantnet)
         ↓
Bot IA génère contrat maintenance (kind 30023)
         ↓
Utilisateur crée Plan de Jardin (Commons Editor)
         ↓
Document kind 30023 avec type "garden"
         ↓
Communauté valide via likes (kind 7)
         ↓
UMAP agrège et calcule score ORE
```

Voir `COLLABORATIVE_COMMONS_SYSTEM.md` pour le détail du workflow de co-édition.

---

*Documentation générée pour le projet UPlanet - Cadastre Écologique Décentralisé*

