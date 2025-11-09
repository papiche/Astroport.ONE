# PlantNet & ORE - TODO & Roadmap

## 🎯 Goal

Rendre le système PlantNet & ORE **complet, opérationnel et intégré** pour permettre le recensement de la biodiversité végétale et l'activation automatique de contrats ORE sur les UMAP.

---

## 📋 Current Status

### ✅ Completed

- [x] Interface Flora Quest (`plantnet.html`)
- [x] Reconnaissance PlantNet (`plantnet_recognition.py`)
- [x] Intégration ORE (`plantnet_ore_integration.py`)
- [x] Support tag `#plantnet` dans `UPlanet_IA_Responder.sh`
- [x] Carte interactive avec observations
- [x] Galerie d'observations
- [x] Système de badges
- [x] Calendrier lunaire
- [x] Barre de progression ORE (8 plantes)
- [x] Stockage biodiversité par UMAP (`ore_biodiversity.json`)

### 🚧 In Progress

- [ ] Publication automatique ORE Meeting Space (kind 30312)
- [ ] Mise à jour DID UMAP avec biodiversité
- [ ] Distribution automatique récompenses Ẑen
- [ ] Détection doublons améliorée

### ❌ Not Started

- [ ] Système de modération communautaire
- [ ] Vérification croisée observations
- [ ] Export données biodiversité (CSV, JSON)
- [ ] Intégration bases de données scientifiques
- [ ] Suivi migrations espèces (saisonnier)
- [ ] Détection espèces invasives
- [ ] Leaderboards contributeurs
- [ ] Notifications push (nouvelle espèce, ORE activé)

---

## 🔧 Core Functionality Improvements

### 1. Activation Automatique Contrats ORE

**Priority**: HIGH  
**Status**: Partially Complete

**Tasks**:
- [ ] Vérifier automatiquement seuil 8 plantes dans `NOSTR.UMAP.refresh.sh`
- [ ] Publier ORE Meeting Space (kind 30312) automatiquement
- [ ] Créer/mettre à jour DID UMAP avec contrat ORE
- [ ] Notifier utilisateurs contributeurs
- [ ] Activer récompenses Ẑen automatiques

**Implementation**:
```bash
# Dans NOSTR.UMAP.refresh.sh
if [[ "$species_count" -ge 8 && "$biodiversity_score" -gt 0.7 ]]; then
    publish_ore_meeting_space "$lat" "$lon"
    update_umap_did_with_ore "$lat" "$lon"
    distribute_ore_rewards "$lat" "$lon"
fi
```

### 2. Distribution Automatique Récompenses Ẑen

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Calculer récompenses par observation
  - Base : 0.5 Ẑen
  - Espèce unique : +1 Ẑen
  - Biodiversité : +10-100 Ẑen (selon score)
  - Engagement : +25-50 Ẑen (selon contribution)
- [ ] Intégrer avec `UPLANET.official.sh` pour virements
- [ ] Publier événements NOSTR pour traçabilité
- [ ] Notifier utilisateurs des récompenses

**Implementation Location**: `RUNTIME/NOSTR.UMAP.refresh.sh` ou nouveau script `ORE.rewards.sh`

### 3. Mise à Jour DID UMAP

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Mettre à jour DID UMAP avec statistiques biodiversité
- [ ] Inclure liste espèces observées
- [ ] Ajouter score biodiversité
- [ ] Référencer contrat ORE (kind 30312)
- [ ] Publier mise à jour (kind 30800, replaceable)

**Implementation**:
```python
# Dans ore_system.py
def update_umap_did_with_biodiversity(lat, lon):
    biodiversity = get_biodiversity_summary(lat, lon)
    did_document = load_umap_did(lat, lon)
    did_document['environmentalObligations']['biodiversity'] = biodiversity
    publish_did_update(did_document)
```

### 4. Détection Doublons Améliorée

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Vérifier espèce + coordonnées précises (pas seulement UMAP)
- [ ] Détecter observations similaires (même espèce, même jour, même observateur)
- [ ] Grouper observations multiples de même plante
- [ ] Afficher message si doublon détecté

**Current Limitation**: Vérifie seulement espèce dans UMAP, pas les doublons temporels

### 5. Système de Modération

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Signalement observations suspectes
- [ ] Vérification par contributeurs certifiés
- [ ] Système de votes (valide/invalide)
- [ ] Exclusion observations invalides des statistiques

---

## 🚀 Advanced Features

### 6. Export Données Biodiversité

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Export CSV par UMAP (espèces, dates, observateurs)
- [ ] Export JSON complet (métadonnées complètes)
- [ ] Export GeoJSON pour visualisation cartographique
- [ ] API REST pour accès programmatique

### 7. Intégration Bases de Données Scientifiques

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Synchronisation avec GBIF (Global Biodiversity Information Facility)
- [ ] Vérification espèces endémiques/protégées
- [ ] Alertes espèces invasives
- [ ] Enrichissement métadonnées (habitat, statut conservation)

### 8. Suivi Migrations Saisonnier

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Détection patterns saisonniers
- [ ] Alertes floraisons/migrations
- [ ] Statistiques temporelles par espèce
- [ ] Prédictions basées sur historique

### 9. Leaderboards et Gamification

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Classement contributeurs (observations, espèces, UMAPs)
- [ ] Classement UMAPs (biodiversité, observations)
- [ ] Badges spéciaux (saisonnier, espèces rares)
- [ ] Défis communautaires (ex: "Recenser 100 espèces en 1 mois")

### 10. Notifications Push

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Notification nouvelle espèce dans UMAP suivie
- [ ] Notification contrat ORE activé
- [ ] Notification récompense Ẑen reçue
- [ ] Notification badge débloqué

---

## 🎨 UI/UX Improvements

### 11. Amélioration Interface Flora Quest

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Filtres galerie (espèce, date, UMAP)
- [ ] Recherche espèces
- [ ] Vue détaillée observation (lightbox amélioré)
- [ ] Partage observations (liens NOSTR)
- [ ] Mode hors-ligne (cache observations)

### 12. Visualisation Données

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Graphiques évolution biodiversité (temporel)
- [ ] Heatmap observations (carte de chaleur)
- [ ] Répartition espèces (pie chart)
- [ ] Timeline observations

### 13. Mobile Optimization

**Priority**: MEDIUM  
**Status**: Partial

**Tasks**:
- [ ] Interface responsive complète
- [ ] Upload photo optimisé mobile
- [ ] Géolocalisation précise (GPS)
- [ ] Mode caméra natif

---

## 🔌 Integration Features

### 14. Intégration avec Oracle WoTx2

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Créer permit "Explorateur Biodiversité" (X1)
- [ ] Créer permit "Botaniste Certifié" (X2+)
- [ ] Attestations entre observateurs
- [ ] Progression automatique selon contributions

**Example**:
- 10 observations → Permit X1 "Explorateur"
- 50 observations + 3 attestations → Permit X2 "Botaniste"
- 100 observations + 5 attestations → Permit X3 "Expert"

### 15. API REST pour Flora Quest

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Endpoint `/api/plantnet/observations` (GET, POST)
- [ ] Endpoint `/api/plantnet/biodiversity/<lat>/<lon>`
- [ ] Endpoint `/api/plantnet/stats/<pubkey>`
- [ ] Authentification NIP-42

### 16. Export iCal Calendrier Lunaire

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Génération fichier .ics pour calendrier lunaire
- [ ] Export périodes optimales (lune montante/descendante)
- [ ] Intégration calendriers (Google, Apple, etc.)

---

## 📚 Documentation & Testing

### 17. Documentation Complète

**Priority**: MEDIUM  
**Status**: In Progress

**Tasks**:
- [x] Créer `PLANTNET_ORE.md` - Documentation système
- [x] Créer `PLANTNET_ORE.todo.md` - Ce fichier
- [ ] Guide utilisateur Flora Quest
- [ ] Guide développeur (API, intégrations)
- [ ] Exemples workflows complets

### 18. Tests Automatisés

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Tests unitaires `plantnet_recognition.py`
- [ ] Tests intégration ORE
- [ ] Tests end-to-end (photo → ORE activé)
- [ ] Tests performance (chargement carte, galerie)

---

## 🎯 Success Criteria

### Phase 1: Core Functionality (Current)
- ✅ Interface Flora Quest opérationnelle
- ✅ Reconnaissance PlantNet fonctionnelle
- ✅ Intégration ORE de base
- ✅ Stockage biodiversité par UMAP

### Phase 2: Automation (Next)
- [ ] Activation automatique contrats ORE
- [ ] Distribution automatique récompenses
- [ ] Mise à jour automatique DID UMAP
- [ ] Notifications automatiques

### Phase 3: Advanced Features
- [ ] Modération communautaire
- [ ] Export données
- [ ] Intégration bases scientifiques
- [ ] Leaderboards

### Phase 4: Integration
- [ ] Intégration Oracle WoTx2
- [ ] API REST complète
- [ ] Mobile optimization
- [ ] Notifications push

### Phase 5: Production Ready
- [ ] Documentation complète
- [ ] Tests automatisés
- [ ] Performance optimisée
- [ ] Sécurité renforcée

---

## 💡 Future Ideas

- **Reconnaissance Animaux** : Extension à la faune (via autre API)
- **Reconnaissance Champignons** : Extension mycologie
- **Reconnaissance Insectes** : Extension entomologie
- **IA Locale** : Modèles d'IA locaux pour reconnaissance (pas d'API externe)
- **AR (Réalité Augmentée)** : Overlay informations sur photo en temps réel
- **Collaboration Scientifique** : Partage données avec chercheurs
- **Citizen Science** : Projets scientifiques participatifs
- **Éducation** : Modules pédagogiques sur la biodiversité
- **Alertes Environnementales** : Notifications changements écosystème
- **Compétitions Communautaires** : Défis biodiversité entre UMAPs

---

**Last Updated**: 2025-01-09  
**Maintainer**: UPlanet/Astroport.ONE Team  
**Status**: Active Development


## 🎯 Goal

Rendre le système PlantNet & ORE **complet, opérationnel et intégré** pour permettre le recensement de la biodiversité végétale et l'activation automatique de contrats ORE sur les UMAP.

---

## 📋 Current Status

### ✅ Completed

- [x] Interface Flora Quest (`plantnet.html`)
- [x] Reconnaissance PlantNet (`plantnet_recognition.py`)
- [x] Intégration ORE (`plantnet_ore_integration.py`)
- [x] Support tag `#plantnet` dans `UPlanet_IA_Responder.sh`
- [x] Carte interactive avec observations
- [x] Galerie d'observations
- [x] Système de badges
- [x] Calendrier lunaire
- [x] Barre de progression ORE (8 plantes)
- [x] Stockage biodiversité par UMAP (`ore_biodiversity.json`)

### 🚧 In Progress

- [ ] Publication automatique ORE Meeting Space (kind 30312)
- [ ] Mise à jour DID UMAP avec biodiversité
- [ ] Distribution automatique récompenses Ẑen
- [ ] Détection doublons améliorée

### ❌ Not Started

- [ ] Système de modération communautaire
- [ ] Vérification croisée observations
- [ ] Export données biodiversité (CSV, JSON)
- [ ] Intégration bases de données scientifiques
- [ ] Suivi migrations espèces (saisonnier)
- [ ] Détection espèces invasives
- [ ] Leaderboards contributeurs
- [ ] Notifications push (nouvelle espèce, ORE activé)

---

## 🔧 Core Functionality Improvements

### 1. Activation Automatique Contrats ORE

**Priority**: HIGH  
**Status**: Partially Complete

**Tasks**:
- [ ] Vérifier automatiquement seuil 8 plantes dans `NOSTR.UMAP.refresh.sh`
- [ ] Publier ORE Meeting Space (kind 30312) automatiquement
- [ ] Créer/mettre à jour DID UMAP avec contrat ORE
- [ ] Notifier utilisateurs contributeurs
- [ ] Activer récompenses Ẑen automatiques

**Implementation**:
```bash
# Dans NOSTR.UMAP.refresh.sh
if [[ "$species_count" -ge 8 && "$biodiversity_score" -gt 0.7 ]]; then
    publish_ore_meeting_space "$lat" "$lon"
    update_umap_did_with_ore "$lat" "$lon"
    distribute_ore_rewards "$lat" "$lon"
fi
```

### 2. Distribution Automatique Récompenses Ẑen

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Calculer récompenses par observation
  - Base : 0.5 Ẑen
  - Espèce unique : +1 Ẑen
  - Biodiversité : +10-100 Ẑen (selon score)
  - Engagement : +25-50 Ẑen (selon contribution)
- [ ] Intégrer avec `UPLANET.official.sh` pour virements
- [ ] Publier événements NOSTR pour traçabilité
- [ ] Notifier utilisateurs des récompenses

**Implementation Location**: `RUNTIME/NOSTR.UMAP.refresh.sh` ou nouveau script `ORE.rewards.sh`

### 3. Mise à Jour DID UMAP

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Mettre à jour DID UMAP avec statistiques biodiversité
- [ ] Inclure liste espèces observées
- [ ] Ajouter score biodiversité
- [ ] Référencer contrat ORE (kind 30312)
- [ ] Publier mise à jour (kind 30800, replaceable)

**Implementation**:
```python
# Dans ore_system.py
def update_umap_did_with_biodiversity(lat, lon):
    biodiversity = get_biodiversity_summary(lat, lon)
    did_document = load_umap_did(lat, lon)
    did_document['environmentalObligations']['biodiversity'] = biodiversity
    publish_did_update(did_document)
```

### 4. Détection Doublons Améliorée

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Vérifier espèce + coordonnées précises (pas seulement UMAP)
- [ ] Détecter observations similaires (même espèce, même jour, même observateur)
- [ ] Grouper observations multiples de même plante
- [ ] Afficher message si doublon détecté

**Current Limitation**: Vérifie seulement espèce dans UMAP, pas les doublons temporels

### 5. Système de Modération

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Signalement observations suspectes
- [ ] Vérification par contributeurs certifiés
- [ ] Système de votes (valide/invalide)
- [ ] Exclusion observations invalides des statistiques

---

## 🚀 Advanced Features

### 6. Export Données Biodiversité

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Export CSV par UMAP (espèces, dates, observateurs)
- [ ] Export JSON complet (métadonnées complètes)
- [ ] Export GeoJSON pour visualisation cartographique
- [ ] API REST pour accès programmatique

### 7. Intégration Bases de Données Scientifiques

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Synchronisation avec GBIF (Global Biodiversity Information Facility)
- [ ] Vérification espèces endémiques/protégées
- [ ] Alertes espèces invasives
- [ ] Enrichissement métadonnées (habitat, statut conservation)

### 8. Suivi Migrations Saisonnier

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Détection patterns saisonniers
- [ ] Alertes floraisons/migrations
- [ ] Statistiques temporelles par espèce
- [ ] Prédictions basées sur historique

### 9. Leaderboards et Gamification

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Classement contributeurs (observations, espèces, UMAPs)
- [ ] Classement UMAPs (biodiversité, observations)
- [ ] Badges spéciaux (saisonnier, espèces rares)
- [ ] Défis communautaires (ex: "Recenser 100 espèces en 1 mois")

### 10. Notifications Push

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Notification nouvelle espèce dans UMAP suivie
- [ ] Notification contrat ORE activé
- [ ] Notification récompense Ẑen reçue
- [ ] Notification badge débloqué

---

## 🎨 UI/UX Improvements

### 11. Amélioration Interface Flora Quest

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Filtres galerie (espèce, date, UMAP)
- [ ] Recherche espèces
- [ ] Vue détaillée observation (lightbox amélioré)
- [ ] Partage observations (liens NOSTR)
- [ ] Mode hors-ligne (cache observations)

### 12. Visualisation Données

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Graphiques évolution biodiversité (temporel)
- [ ] Heatmap observations (carte de chaleur)
- [ ] Répartition espèces (pie chart)
- [ ] Timeline observations

### 13. Mobile Optimization

**Priority**: MEDIUM  
**Status**: Partial

**Tasks**:
- [ ] Interface responsive complète
- [ ] Upload photo optimisé mobile
- [ ] Géolocalisation précise (GPS)
- [ ] Mode caméra natif

---

## 🔌 Integration Features

### 14. Intégration avec Oracle WoTx2

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Créer permit "Explorateur Biodiversité" (X1)
- [ ] Créer permit "Botaniste Certifié" (X2+)
- [ ] Attestations entre observateurs
- [ ] Progression automatique selon contributions

**Example**:
- 10 observations → Permit X1 "Explorateur"
- 50 observations + 3 attestations → Permit X2 "Botaniste"
- 100 observations + 5 attestations → Permit X3 "Expert"

### 15. API REST pour Flora Quest

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Endpoint `/api/plantnet/observations` (GET, POST)
- [ ] Endpoint `/api/plantnet/biodiversity/<lat>/<lon>`
- [ ] Endpoint `/api/plantnet/stats/<pubkey>`
- [ ] Authentification NIP-42

### 16. Export iCal Calendrier Lunaire

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Génération fichier .ics pour calendrier lunaire
- [ ] Export périodes optimales (lune montante/descendante)
- [ ] Intégration calendriers (Google, Apple, etc.)

---

## 📚 Documentation & Testing

### 17. Documentation Complète

**Priority**: MEDIUM  
**Status**: In Progress

**Tasks**:
- [x] Créer `PLANTNET_ORE.md` - Documentation système
- [x] Créer `PLANTNET_ORE.todo.md` - Ce fichier
- [ ] Guide utilisateur Flora Quest
- [ ] Guide développeur (API, intégrations)
- [ ] Exemples workflows complets

### 18. Tests Automatisés

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Tests unitaires `plantnet_recognition.py`
- [ ] Tests intégration ORE
- [ ] Tests end-to-end (photo → ORE activé)
- [ ] Tests performance (chargement carte, galerie)

---

## 🎯 Success Criteria

### Phase 1: Core Functionality (Current)
- ✅ Interface Flora Quest opérationnelle
- ✅ Reconnaissance PlantNet fonctionnelle
- ✅ Intégration ORE de base
- ✅ Stockage biodiversité par UMAP

### Phase 2: Automation (Next)
- [ ] Activation automatique contrats ORE
- [ ] Distribution automatique récompenses
- [ ] Mise à jour automatique DID UMAP
- [ ] Notifications automatiques

### Phase 3: Advanced Features
- [ ] Modération communautaire
- [ ] Export données
- [ ] Intégration bases scientifiques
- [ ] Leaderboards

### Phase 4: Integration
- [ ] Intégration Oracle WoTx2
- [ ] API REST complète
- [ ] Mobile optimization
- [ ] Notifications push

### Phase 5: Production Ready
- [ ] Documentation complète
- [ ] Tests automatisés
- [ ] Performance optimisée
- [ ] Sécurité renforcée

---

## 💡 Future Ideas

- **Reconnaissance Animaux** : Extension à la faune (via autre API)
- **Reconnaissance Champignons** : Extension mycologie
- **Reconnaissance Insectes** : Extension entomologie
- **IA Locale** : Modèles d'IA locaux pour reconnaissance (pas d'API externe)
- **AR (Réalité Augmentée)** : Overlay informations sur photo en temps réel
- **Collaboration Scientifique** : Partage données avec chercheurs
- **Citizen Science** : Projets scientifiques participatifs
- **Éducation** : Modules pédagogiques sur la biodiversité
- **Alertes Environnementales** : Notifications changements écosystème
- **Compétitions Communautaires** : Défis biodiversité entre UMAPs

---

**Last Updated**: 2025-01-09  
**Maintainer**: UPlanet/Astroport.ONE Team  
**Status**: Active Development


## 🎯 Goal

Rendre le système PlantNet & ORE **complet, opérationnel et intégré** pour permettre le recensement de la biodiversité végétale et l'activation automatique de contrats ORE sur les UMAP.

---

## 📋 Current Status

### ✅ Completed

- [x] Interface Flora Quest (`plantnet.html`)
- [x] Reconnaissance PlantNet (`plantnet_recognition.py`)
- [x] Intégration ORE (`plantnet_ore_integration.py`)
- [x] Support tag `#plantnet` dans `UPlanet_IA_Responder.sh`
- [x] Carte interactive avec observations
- [x] Galerie d'observations
- [x] Système de badges
- [x] Calendrier lunaire
- [x] Barre de progression ORE (8 plantes)
- [x] Stockage biodiversité par UMAP (`ore_biodiversity.json`)

### 🚧 In Progress

- [ ] Publication automatique ORE Meeting Space (kind 30312)
- [ ] Mise à jour DID UMAP avec biodiversité
- [ ] Distribution automatique récompenses Ẑen
- [ ] Détection doublons améliorée

### ❌ Not Started

- [ ] Système de modération communautaire
- [ ] Vérification croisée observations
- [ ] Export données biodiversité (CSV, JSON)
- [ ] Intégration bases de données scientifiques
- [ ] Suivi migrations espèces (saisonnier)
- [ ] Détection espèces invasives
- [ ] Leaderboards contributeurs
- [ ] Notifications push (nouvelle espèce, ORE activé)

---

## 🔧 Core Functionality Improvements

### 1. Activation Automatique Contrats ORE

**Priority**: HIGH  
**Status**: Partially Complete

**Tasks**:
- [ ] Vérifier automatiquement seuil 8 plantes dans `NOSTR.UMAP.refresh.sh`
- [ ] Publier ORE Meeting Space (kind 30312) automatiquement
- [ ] Créer/mettre à jour DID UMAP avec contrat ORE
- [ ] Notifier utilisateurs contributeurs
- [ ] Activer récompenses Ẑen automatiques

**Implementation**:
```bash
# Dans NOSTR.UMAP.refresh.sh
if [[ "$species_count" -ge 8 && "$biodiversity_score" -gt 0.7 ]]; then
    publish_ore_meeting_space "$lat" "$lon"
    update_umap_did_with_ore "$lat" "$lon"
    distribute_ore_rewards "$lat" "$lon"
fi
```

### 2. Distribution Automatique Récompenses Ẑen

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Calculer récompenses par observation
  - Base : 0.5 Ẑen
  - Espèce unique : +1 Ẑen
  - Biodiversité : +10-100 Ẑen (selon score)
  - Engagement : +25-50 Ẑen (selon contribution)
- [ ] Intégrer avec `UPLANET.official.sh` pour virements
- [ ] Publier événements NOSTR pour traçabilité
- [ ] Notifier utilisateurs des récompenses

**Implementation Location**: `RUNTIME/NOSTR.UMAP.refresh.sh` ou nouveau script `ORE.rewards.sh`

### 3. Mise à Jour DID UMAP

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Mettre à jour DID UMAP avec statistiques biodiversité
- [ ] Inclure liste espèces observées
- [ ] Ajouter score biodiversité
- [ ] Référencer contrat ORE (kind 30312)
- [ ] Publier mise à jour (kind 30800, replaceable)

**Implementation**:
```python
# Dans ore_system.py
def update_umap_did_with_biodiversity(lat, lon):
    biodiversity = get_biodiversity_summary(lat, lon)
    did_document = load_umap_did(lat, lon)
    did_document['environmentalObligations']['biodiversity'] = biodiversity
    publish_did_update(did_document)
```

### 4. Détection Doublons Améliorée

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Vérifier espèce + coordonnées précises (pas seulement UMAP)
- [ ] Détecter observations similaires (même espèce, même jour, même observateur)
- [ ] Grouper observations multiples de même plante
- [ ] Afficher message si doublon détecté

**Current Limitation**: Vérifie seulement espèce dans UMAP, pas les doublons temporels

### 5. Système de Modération

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Signalement observations suspectes
- [ ] Vérification par contributeurs certifiés
- [ ] Système de votes (valide/invalide)
- [ ] Exclusion observations invalides des statistiques

---

## 🚀 Advanced Features

### 6. Export Données Biodiversité

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Export CSV par UMAP (espèces, dates, observateurs)
- [ ] Export JSON complet (métadonnées complètes)
- [ ] Export GeoJSON pour visualisation cartographique
- [ ] API REST pour accès programmatique

### 7. Intégration Bases de Données Scientifiques

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Synchronisation avec GBIF (Global Biodiversity Information Facility)
- [ ] Vérification espèces endémiques/protégées
- [ ] Alertes espèces invasives
- [ ] Enrichissement métadonnées (habitat, statut conservation)

### 8. Suivi Migrations Saisonnier

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Détection patterns saisonniers
- [ ] Alertes floraisons/migrations
- [ ] Statistiques temporelles par espèce
- [ ] Prédictions basées sur historique

### 9. Leaderboards et Gamification

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Classement contributeurs (observations, espèces, UMAPs)
- [ ] Classement UMAPs (biodiversité, observations)
- [ ] Badges spéciaux (saisonnier, espèces rares)
- [ ] Défis communautaires (ex: "Recenser 100 espèces en 1 mois")

### 10. Notifications Push

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Notification nouvelle espèce dans UMAP suivie
- [ ] Notification contrat ORE activé
- [ ] Notification récompense Ẑen reçue
- [ ] Notification badge débloqué

---

## 🎨 UI/UX Improvements

### 11. Amélioration Interface Flora Quest

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Filtres galerie (espèce, date, UMAP)
- [ ] Recherche espèces
- [ ] Vue détaillée observation (lightbox amélioré)
- [ ] Partage observations (liens NOSTR)
- [ ] Mode hors-ligne (cache observations)

### 12. Visualisation Données

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Graphiques évolution biodiversité (temporel)
- [ ] Heatmap observations (carte de chaleur)
- [ ] Répartition espèces (pie chart)
- [ ] Timeline observations

### 13. Mobile Optimization

**Priority**: MEDIUM  
**Status**: Partial

**Tasks**:
- [ ] Interface responsive complète
- [ ] Upload photo optimisé mobile
- [ ] Géolocalisation précise (GPS)
- [ ] Mode caméra natif

---

## 🔌 Integration Features

### 14. Intégration avec Oracle WoTx2

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Créer permit "Explorateur Biodiversité" (X1)
- [ ] Créer permit "Botaniste Certifié" (X2+)
- [ ] Attestations entre observateurs
- [ ] Progression automatique selon contributions

**Example**:
- 10 observations → Permit X1 "Explorateur"
- 50 observations + 3 attestations → Permit X2 "Botaniste"
- 100 observations + 5 attestations → Permit X3 "Expert"

### 15. API REST pour Flora Quest

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Endpoint `/api/plantnet/observations` (GET, POST)
- [ ] Endpoint `/api/plantnet/biodiversity/<lat>/<lon>`
- [ ] Endpoint `/api/plantnet/stats/<pubkey>`
- [ ] Authentification NIP-42

### 16. Export iCal Calendrier Lunaire

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Génération fichier .ics pour calendrier lunaire
- [ ] Export périodes optimales (lune montante/descendante)
- [ ] Intégration calendriers (Google, Apple, etc.)

---

## 📚 Documentation & Testing

### 17. Documentation Complète

**Priority**: MEDIUM  
**Status**: In Progress

**Tasks**:
- [x] Créer `PLANTNET_ORE.md` - Documentation système
- [x] Créer `PLANTNET_ORE.todo.md` - Ce fichier
- [ ] Guide utilisateur Flora Quest
- [ ] Guide développeur (API, intégrations)
- [ ] Exemples workflows complets

### 18. Tests Automatisés

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Tests unitaires `plantnet_recognition.py`
- [ ] Tests intégration ORE
- [ ] Tests end-to-end (photo → ORE activé)
- [ ] Tests performance (chargement carte, galerie)

---

## 🎯 Success Criteria

### Phase 1: Core Functionality (Current)
- ✅ Interface Flora Quest opérationnelle
- ✅ Reconnaissance PlantNet fonctionnelle
- ✅ Intégration ORE de base
- ✅ Stockage biodiversité par UMAP

### Phase 2: Automation (Next)
- [ ] Activation automatique contrats ORE
- [ ] Distribution automatique récompenses
- [ ] Mise à jour automatique DID UMAP
- [ ] Notifications automatiques

### Phase 3: Advanced Features
- [ ] Modération communautaire
- [ ] Export données
- [ ] Intégration bases scientifiques
- [ ] Leaderboards

### Phase 4: Integration
- [ ] Intégration Oracle WoTx2
- [ ] API REST complète
- [ ] Mobile optimization
- [ ] Notifications push

### Phase 5: Production Ready
- [ ] Documentation complète
- [ ] Tests automatisés
- [ ] Performance optimisée
- [ ] Sécurité renforcée

---

## 💡 Future Ideas

- **Reconnaissance Animaux** : Extension à la faune (via autre API)
- **Reconnaissance Champignons** : Extension mycologie
- **Reconnaissance Insectes** : Extension entomologie
- **IA Locale** : Modèles d'IA locaux pour reconnaissance (pas d'API externe)
- **AR (Réalité Augmentée)** : Overlay informations sur photo en temps réel
- **Collaboration Scientifique** : Partage données avec chercheurs
- **Citizen Science** : Projets scientifiques participatifs
- **Éducation** : Modules pédagogiques sur la biodiversité
- **Alertes Environnementales** : Notifications changements écosystème
- **Compétitions Communautaires** : Défis biodiversité entre UMAPs

---

**Last Updated**: 2025-01-09  
**Maintainer**: UPlanet/Astroport.ONE Team  
**Status**: Active Development

