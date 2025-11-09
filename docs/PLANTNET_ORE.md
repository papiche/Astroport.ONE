# PlantNet & ORE - Système de Recensement de la Biodiversité

**Version** : 1.0  
**Date** : 2025-01-09  
**Status** : Opérationnel  
**License** : AGPL-3.0

---

## 📖 Vue d'Ensemble

Le système **PlantNet & ORE** permet aux utilisateurs de recenser les plantes et arbres dans leur environnement, d'activer des contrats ORE (Obligations Réelles Environnementales) sur des UMAP (zones géographiques), et de recevoir des récompenses en Ẑen pour leurs contributions à la biodiversité.

### Objectif

Créer un **cadastre écologique décentralisé** où chaque observation de plante contribue à :
- La protection environnementale via les contrats ORE
- La valorisation économique de la biodiversité
- La création d'un réseau de confiance autour de la nature

---

## 🏗️ Architecture

### Composants Principaux

```
┌─────────────────────────────────────────────────────────────┐
│                    FLORA QUEST (Frontend)                   │
│              UPlanet/earth/plantnet.html                     │
│  • Interface utilisateur (Bootstrap + Leaflet)              │
│  • Upload photos de plantes                                  │
│  • Carte ORE UMAPs                                           │
│  • Galerie d'observations                                    │
│  • Calendrier lunaire                                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Publication NOSTR (Kind 1)                     │
│  Tags: #BRO #plantnet #UPlanet                               │
│  • Image IPFS                                                 │
│  • Coordonnées GPS (tag g)                                   │
│  • Métadonnées (imeta)                                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│         UPlanet_IA_Responder.sh                             │
│  • Détecte tag #plantnet                                    │
│  • Appelle plantnet_recognition.py                          │
│  • Appelle plantnet_ore_integration.py                      │
│  • Publie réponse avec identification                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
┌──────────────────┐         ┌──────────────────┐
│ PlantNet API     │         │ ORE System        │
│ Recognition      │         │ Biodiversity     │
│                  │         │ Tracking         │
└──────────────────┘         └──────────────────┘
        │                             │
        └──────────────┬──────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Réponse NOSTR (Kind 1)                         │
│  Tags: #UPlanet #plantnet                                   │
│  • Identification PlantNet                                  │
│  • Statistiques ORE                                         │
│  • Progression contrat (8 plantes)                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Workflow Complet

### 1. Observation Utilisateur

**Interface** : `plantnet.html` → Section "Ajouter une Plante"

**Processus** :
1. Utilisateur prend/upload une photo de plante
2. Photo uploadée vers IPFS via `/api/fileupload`
3. Position GPS récupérée (géolocalisation ou carte)
4. Publication événement NOSTR (kind 1) :
   ```json
   {
     "kind": 1,
     "tags": [
       ["t", "plantnet"],
       ["t", "BRO"],
       ["t", "UPlanet"],
       ["g", "48.8566,2.3522"],
       ["imeta", "url /ipfs/Qm...", "m image/jpeg"]
     ],
     "content": "🌱 Observation\n📍 Position: 48.8566, 2.3522\n📸 Photo: /ipfs/Qm...\n#plantnet #UPlanet #BRO"
   }
   ```

### 2. Reconnaissance PlantNet

**Script** : `IA/plantnet_recognition.py`

**Processus** :
1. `UPlanet_IA_Responder.sh` détecte tag `#plantnet`
2. Extrait URL image depuis tags `imeta` ou contenu
3. Télécharge image depuis IPFS
4. Appelle API PlantNet avec :
   - Image (base64 ou URL)
   - Coordonnées GPS (latitude, longitude)
5. Reçoit résultats de reconnaissance :
   ```json
   {
     "results": [
       {
         "score": 0.95,
         "species": {
           "scientificNameWithoutAuthor": "Quercus robur",
           "commonNames": ["English Oak", "Chêne pédonculé"]
         }
       }
     ]
   }
   ```

### 3. Intégration ORE

**Script** : `IA/plantnet_ore_integration.py`

**Processus** :
1. Parse résultat PlantNet (espèce, confiance)
2. Vérifie si espèce déjà observée dans cette UMAP :
   ```bash
   python3 ore_system.py check_plant <lat> <lon> <scientific_name>
   ```
3. Enregistre observation dans ORE :
   ```bash
   python3 ore_system.py add_plant <lat> <lon> <species> <scientific> <pubkey> <confidence> <image_url> <event_id>
   ```
4. Calcule statistiques biodiversité :
   - Nombre d'espèces uniques
   - Nombre d'observations
   - Score biodiversité (0-1)
   - Progression vers contrat ORE (8 plantes)

### 4. Réponse Bot IA

**Script** : `IA/UPlanet_IA_Responder.sh`

**Format de réponse** :
```
🌱 PlantNet Recognition

✅ Identified: English Oak (Quercus robur)
📊 Confidence: 95%

📍 Location: UMAP 48.86,2.35

📈 ORE Biodiversity:
• Species count: 3/8 (need 5 more for ORE contract)
• Observations: 5
• Biodiversity score: 0.42

💰 ORE Contribution:
Your observation contributes to this UMAP's environmental obligations!

#ORE #UPlanet #Biodiversity #FloraQuest #PlantNet
```

### 5. Activation Contrat ORE

**Script** : `RUNTIME/NOSTR.UMAP.refresh.sh`

**Conditions** :
- ✅ 8 plantes différentes observées dans l'UMAP
- ✅ Score biodiversité > 0.7
- ✅ Pas encore de contrat ORE actif

**Processus** :
1. Crée DID UMAP (kind 30800) si inexistant
2. Publie ORE Meeting Space (kind 30312)
3. Met à jour DID avec contrat ORE
4. Active récompenses Ẑen

---

## 📊 Système de Récompenses

### Récompenses par Observation

| Type | Montant | Condition |
|------|---------|-----------|
| **Base** | 0.5 Ẑen | Chaque observation validée |
| **Espèce unique** | +1 Ẑen | Nouvelle espèce dans l'UMAP |
| **Biodiversité** | +10-100 Ẑen | Score biodiversité élevé |
| **Engagement** | +25-50 Ẑen | Contribution communautaire |

### Activation Contrat ORE

**Seuil** : 8 plantes différentes dans une UMAP

**Bénéfices** :
- ✅ Contrat ORE actif (kind 30312)
- ✅ Récompenses bonus activées
- ✅ Statut "Guardian" dans Flora Quest
- ✅ Participation aux bénéfices ORE

---

## 🗺️ Intégration UMAP

### UMAP (Universal Map)

**Définition** : Cellule géographique de 0.01° × 0.01° (≈ 1.2 km²)

**Stockage** :
- Fichier : `~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_R_R/_S_S/_LAT_LON/ore_biodiversity.json`
- Format JSON avec :
  - Liste des espèces observées
  - Nombre d'observations par espèce
  - Observateurs (pubkeys)
  - Score biodiversité
  - Statut contrat ORE

### DID UMAP

**Kind** : 30800 (DID Document - NIP-101)

**Structure** :
```json
{
  "id": "did:nostr:{umap_hex}",
  "type": "UMAPGeographicCell",
  "geographicMetadata": {
    "coordinates": {"lat": 48.8566, "lon": 2.3522}
  },
  "environmentalObligations": {
    "oreContract": {
      "contractId": "ORE-2025-001",
      "description": "Maintenir biodiversité végétale",
      "biodiversityScore": 0.85,
      "speciesCount": 12,
      "observationsCount": 45
    }
  }
}
```

---

## 🎮 Flora Quest - Gamification

### Interface Utilisateur

**Fichier** : `UPlanet/earth/plantnet.html`

**Fonctionnalités** :
- 📸 Upload photos de plantes
- 🗺️ Carte interactive avec observations
- 📊 Statistiques personnelles
- 🏆 Système de badges
- 📅 Calendrier lunaire
- 🖼️ Galerie d'observations

### Badges Disponibles

| Badge | Condition | Récompense |
|-------|-----------|------------|
| 🌱 **First Step** | 1 observation | 0.5 Ẑen |
| 🔍 **Explorer** | 10 observations | 5 Ẑen |
| 🌺 **Botanist** | 50 observations | 25 Ẑen |
| 🌳 **Master** | 100 observations | 50 Ẑen |
| 🚀 **Pioneer** | Activer 1 contrat ORE | 100 Ẑen |
| 🛡️ **Guardian** | Contrat ORE actif | Récompenses continues |
| 🌍 **Nomad** | 5 UMAPs différents | 50 Ẑen |
| ⭐ **Legend** | Top 1% contributeurs | 200 Ẑen |

### Progression ORE

**Barre de progression** : 0/8 → 8/8 plantes

**Étapes** :
1. **0-4 plantes** : "Commencez !"
2. **5-7 plantes** : "Presque là !"
3. **8 plantes** : "Contrat ORE activé !"

---

## 🔧 Scripts et Outils

### Scripts Principaux

| Script | Fonction | Localisation |
|--------|----------|--------------|
| `plantnet_recognition.py` | Reconnaissance PlantNet API | `IA/plantnet_recognition.py` |
| `plantnet_ore_integration.py` | Intégration ORE | `IA/plantnet_ore_integration.py` |
| `ore_system.py` | Gestion ORE biodiversité | `tools/ore_system.py` |
| `NOSTR.UMAP.refresh.sh` | Activation contrats ORE | `RUNTIME/NOSTR.UMAP.refresh.sh` |
| `plantnet.html` | Interface utilisateur | `UPlanet/earth/plantnet.html` |

### Commandes CLI

```bash
# Ajouter observation plante
python3 ore_system.py add_plant <lat> <lon> <species> <scientific> <pubkey> <confidence> [image_url] [event_id]

# Vérifier si espèce existe
python3 ore_system.py check_plant <lat> <lon> <scientific_name>

# Résumé biodiversité UMAP
python3 ore_system.py biodiversity_summary <lat> <lon>

# Reconnaissance PlantNet
python3 plantnet_recognition.py <image_url> <latitude> <longitude>
```

---

## 📡 Événements NOSTR

### Kind 1 - Observations et Réponses

**Observation Utilisateur** :
- Tags : `#BRO`, `#plantnet`, `#UPlanet`
- Contenu : Description + URL image IPFS
- Géolocalisation : Tag `g` (latitude,longitude)
- Image : Tag `imeta` avec URL IPFS

**Réponse Bot IA** :
- Tags : `#UPlanet`, `#plantnet`, `#ORE`
- Référence : Tag `e` (event ID observation)
- Contenu : Identification + statistiques ORE

### Kind 30800 - DID UMAP

**Définition** : Identité décentralisée de l'UMAP

**Contenu** : Document DID avec métadonnées ORE

### Kind 30312 - ORE Meeting Space

**Définition** : Espace géographique persistant pour vérifications ORE

**Publication** : Automatique après 8 plantes observées

---

## 🔐 Sécurité et Validation

### Validation des Observations

1. **Vérification image** : Image valide et accessible
2. **Vérification GPS** : Coordonnées dans limites raisonnables
3. **Vérification PlantNet** : Confiance > 0.5
4. **Détection doublons** : Espèce déjà observée dans UMAP

### Protection Anti-Abus

- Limite : 10 observations/jour/utilisateur
- Vérification : Espèce valide dans base PlantNet
- Modération : Observations suspectes signalées

---

## 📈 Métriques et Statistiques

### Métriques UMAP

- **Espèces uniques** : Nombre d'espèces différentes
- **Observations totales** : Nombre d'observations
- **Contributeurs** : Nombre d'observateurs uniques
- **Score biodiversité** : 0-1 (calculé automatiquement)
- **Statut ORE** : Actif/Inactif

### Métriques Utilisateur

- **Plantes cataloguées** : Total observations
- **UMAPs explorés** : Nombre d'UMAPs différents
- **Badges débloqués** : Progression achievements
- **Contribution ORE** : Score total

---

## 🔗 Intégrations

### PlantNet API

- **Endpoint** : `https://my-api.plantnet.org/v2/identify`  
- **Authentification** : API Key (variable d'environnement)
- **Limite** : 500 requêtes/jour (gratuit)

### ORE System

- **Intégration** : Via `ore_system.py`
- **Stockage** : Fichiers JSON par UMAP
- **Synchronisation** : NOSTR events (kind 30800, 30312)

### IPFS

- **Upload** : Via `/api/fileupload`
- **Format** : Images JPEG/PNG
- **Taille max** : 10MB

---

## 🚀 Utilisation

### Pour les Utilisateurs

1. **Accéder à Flora Quest** : `http://127.0.0.1:54321/plantnet` ou via IPNS
2. **Se connecter** : Bouton "Connexion" (NOSTR)
3. **Prendre une photo** : Section "Ajouter une Plante"
4. **Partager l'observation** : Bouton "Partager l'observation"
5. **Attendre la reconnaissance** : Bot IA répond en 2-5 secondes
6. **Suivre la progression** : Section "Atlas" → Barre de progression ORE

### Pour les Développeurs

```bash
# Tester reconnaissance PlantNet
python3 IA/plantnet_recognition.py \
  "https://ipfs.copylaradio.com/ipfs/Qm..." \
  48.8566 2.3522

# Tester intégration ORE
python3 IA/plantnet_ore_integration.py \
  48.8566 2.3522 \
  "npub1..." \
  "event_123" \
  "PlantNet result text"

# Vérifier biodiversité UMAP
python3 tools/ore_system.py biodiversity_summary 48.8566 2.3522
```

---

## 📚 Références

- **[ORE_SYSTEM.md](ORE_SYSTEM.md)** : Documentation système ORE
- **[DID_IMPLEMENTATION.md](../DID_IMPLEMENTATION.md)** : Identités décentralisées
- **[PlantNet API](https://my.plantnet.org/)** : Documentation API PlantNet
- **[NIP-101](../nostr-nips/101.md)** : Protocole UPlanet (DID, ORE)

---

**Version** : 1.0  
**Dernière mise à jour** : 2025-01-09  
**Mainteneur** : UPlanet/Astroport.ONE Team

