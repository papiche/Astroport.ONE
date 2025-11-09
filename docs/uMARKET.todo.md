# 🛒 uMARKET TODO - Refonte du Système de Marketplace

## Vue d'Ensemble

Le système uMARKET nécessite une **refonte complète** pour s'intégrer avec les contrats ORE UMAP et profiter des évolutions du système d'identité décentralisée.

**Statut** : 🔴 À Refondre  
**Priorité** : Moyenne (après stabilisation des systèmes ORE et DID)

---

## 🎯 Objectifs de la Refonte

### 1. Intégration avec ORE UMAP
- [ ] Utiliser les DIDs UMAP pour l'identité géographique des annonces
- [ ] Intégrer les contrats ORE pour la vérification des annonces
- [ ] Utiliser les événements Nostr (kind 30312/30313) pour le stockage
- [ ] Intégrer le système de récompenses Ẑen

### 2. Architecture Décentralisée
- [ ] Remplacer le stockage local par des événements Nostr
- [ ] Utiliser les abonnements Nostr pour la découverte
- [ ] Intégrer dans les documents DID UMAP
- [ ] Supprimer la dépendance aux fichiers locaux

### 3. Vérification et Certification
- [ ] Système de vérification ORE pour annonces certifiées
- [ ] Badges de vérification dans l'interface
- [ ] Récompenses Ẑen pour annonces vérifiées
- [ ] Intégration avec ORE Meeting Space

---

## 📋 Tâches par Priorité

### 🔴 Critique (Blocage)

#### Architecture et Structure de Données
- [ ] **Définir le format d'événement Nostr pour annonces**
  - [ ] Choisir le kind approprié (30312 réutilisé ou nouveau kind)
  - [ ] Définir les tags nécessaires (`price`, `category`, `ore-contract`, etc.)
  - [ ] Définir le format JSON du contenu
  - [ ] Documenter dans une NIP ou extension

- [ ] **Intégrer avec les DIDs UMAP**
  - [ ] Ajouter section `marketplace` dans les documents DID
  - [ ] Lier les annonces aux DIDs UMAP
  - [ ] Mettre à jour `did_manager_nostr.sh` pour supporter marketplace

- [ ] **Remplacer le stockage local par événements Nostr**
  - [ ] Supprimer les fichiers JSON locaux
  - [ ] Utiliser les abonnements Nostr pour la découverte
  - [ ] Implémenter le cache local optionnel

#### Détection et Traitement
- [ ] **Refondre la détection du tag `#market`**
  - [ ] Intégrer dans `UPlanet_IA_Responder.sh` ou `NOSTR.UMAP.refresh.sh`
  - [ ] Extraire les métadonnées (prix, catégorie, images)
  - [ ] Créer l'événement Nostr automatiquement

- [ ] **Créer le script de publication d'annonce**
  - [ ] `uMARKET_publish.sh` : Publication d'événement Nostr
  - [ ] Validation des métadonnées
  - [ ] Gestion des images (téléchargement IPFS)
  - [ ] Mise à jour du document DID UMAP

### 🟡 Important (Fonctionnalités Clés)

#### Vérification ORE
- [ ] **Intégrer la vérification ORE**
  - [ ] Lier les annonces aux contrats ORE
  - [ ] Créer des événements kind 30313 pour vérification
  - [ ] Vérification automatique via ORE Meeting Space
  - [ ] Badges de vérification dans l'interface

- [ ] **Système de récompenses Ẑen**
  - [ ] `uMARKET_reward.sh` : Distribution de récompenses
  - [ ] Intégration avec `UPLANET.official.sh`
  - [ ] Récompenses conditionnelles (uniquement si vérifié)
  - [ ] Portefeuille UMAP pour récompenses

#### Interface Web
- [ ] **Refondre l'interface web**
  - [ ] Lecture depuis événements Nostr au lieu de fichiers JSON
  - [ ] Abonnements Nostr en temps réel
  - [ ] Filtrage par UMAP, catégorie, prix
  - [ ] Affichage des badges de vérification ORE
  - [ ] Statistiques par UMAP

- [ ] **Génération d'interface dynamique**
  - [ ] `uMARKET_interface.sh` : Génération depuis Nostr
  - [ ] Cache local pour performance
  - [ ] Mise à jour automatique

### 🟢 Améliorations (Nice to Have)

#### Fonctionnalités Avancées
- [ ] **Recherche avancée**
  - [ ] Par localisation (rayon)
  - [ ] Par catégorie
  - [ ] Par prix
  - [ ] Par statut de vérification

- [ ] **Gestion des annonces**
  - [ ] Expiration automatique
  - [ ] Renouvellement d'annonce
  - [ ] Suppression d'annonce
  - [ ] Modification d'annonce

- [ ] **Notifications**
  - [ ] Notifications pour nouvelles annonces dans une UMAP
  - [ ] Notifications pour vérifications ORE
  - [ ] Notifications pour récompenses

#### Intégrations
- [ ] **Intégration avec PlantNet**
  - [ ] Annonces de produits locaux avec reconnaissance PlantNet
  - [ ] Vérification ORE automatique pour produits locaux

- [ ] **Intégration avec Oracle WoTx2**
  - [ ] Permis pour vendeurs certifiés
  - [ ] Badges de compétence pour annonceurs

#### Tests et Documentation
- [ ] **Tests complets**
  - [ ] Tests unitaires pour chaque script
  - [ ] Tests d'intégration avec ORE
  - [ ] Tests de publication/récupération d'annonces
  - [ ] Tests de vérification ORE
  - [ ] Tests de récompenses Ẑen

- [ ] **Documentation**
  - [ ] Guide utilisateur pour publier une annonce
  - [ ] Guide développeur pour intégration
  - [ ] Documentation API (si API nécessaire)
  - [ ] Exemples d'utilisation

---

## 🔄 Migration depuis l'Ancien Système

### Phase 1 : Analyse
- [ ] Inventorier les annonces existantes
- [ ] Analyser la structure des données actuelles
- [ ] Identifier les dépendances

### Phase 2 : Conversion
- [ ] Script de conversion des annonces locales en événements Nostr
- [ ] Validation des données converties
- [ ] Test de conversion sur un échantillon

### Phase 3 : Publication
- [ ] Publication des événements convertis sur Nostr
- [ ] Mise à jour des documents DID UMAP
- [ ] Vérification de la découverte

### Phase 4 : Dépréciation
- [ ] Arrêt des scripts locaux obsolètes
- [ ] Suppression des fichiers locaux
- [ ] Mise à jour de la documentation

---

## 📝 Scripts à Créer/Refondre

### Nouveaux Scripts
- [ ] `uMARKET_publish.sh` : Publication d'annonce via événement Nostr
- [ ] `uMARKET_verify.sh` : Vérification ORE d'une annonce
- [ ] `uMARKET_reward.sh` : Distribution de récompenses Ẑen
- [ ] `uMARKET_interface.sh` : Génération d'interface web depuis Nostr
- [ ] `uMARKET_convert.sh` : Conversion des annonces locales en événements Nostr

### Scripts à Refondre
- [ ] `_uMARKET.generate.sh` → Basé sur événements Nostr
- [ ] `_uMARKET.aggregate.sh` → Utilisation d'abonnements Nostr
- [ ] `_uMARKET.test.sh` → Tests avec événements Nostr
- [ ] `NOSTR.UMAP.refresh.sh` → Détection et traitement des annonces

### Scripts à Supprimer
- [ ] `_uMARKET.monitor.sh` → Remplacé par monitoring Nostr
- [ ] `_uMARKET.deploy_global.sh` → Remplacé par agrégation Nostr

---

## 🔗 Dépendances

### Systèmes Requis
- [ ] **ORE UMAP** : Système ORE opérationnel et testé
- [ ] **DID** : Système DID opérationnel
- [ ] **Nostr Relays** : Relais Nostr fonctionnels
- [ ] **IPFS** : Stockage IPFS pour images

### Scripts Requis
- [ ] `did_manager_nostr.sh` : Gestion des DIDs UMAP
- [ ] `ore_system.py` : Système ORE
- [ ] `nostr_send_note.py` : Publication d'événements Nostr
- [ ] `UPLANET.official.sh` : Distribution de récompenses Ẑen

---

## 📊 Métriques de Succès

### Fonctionnalités
- [ ] Publication d'annonce fonctionnelle via tag `#market`
- [ ] Découverte d'annonces via abonnements Nostr
- [ ] Vérification ORE opérationnelle
- [ ] Récompenses Ẑen distribuées automatiquement
- [ ] Interface web dynamique basée sur Nostr

### Performance
- [ ] Temps de publication < 5 secondes
- [ ] Découverte d'annonces < 2 secondes
- [ ] Interface web chargée < 3 secondes

### Qualité
- [ ] Tests de couverture > 80%
- [ ] Documentation complète
- [ ] Aucune dépendance aux fichiers locaux

---

## 🎯 Prochaines Étapes

1. **Analyse approfondie** : Étudier l'intégration avec ORE UMAP
2. **Prototype** : Créer un prototype avec événements Nostr
3. **Tests** : Tester la publication et découverte d'annonces
4. **Refonte progressive** : Migrer fonctionnalité par fonctionnalité
5. **Documentation** : Documenter le nouveau système

---

**Note** : Cette refonte est prioritaire après la stabilisation des systèmes ORE et DID. Le système actuel reste fonctionnel mais limité.
