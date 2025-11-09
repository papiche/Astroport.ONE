# CoinFlip - TODO & Roadmap

## 🎯 Goal

Rendre le système CoinFlip **complet, testé et opérationnel** pour permettre un jeu de pile ou face décentralisé avec paiements ZEN automatiques.

---

## 📋 Current Status

### ✅ Completed

- [x] Interface utilisateur (`coinflip/index.html`)
- [x] Intégration NOSTR (authentification, profil)
- [x] Détection API uSPOT automatique
- [x] Affichage solde CAPITAINE
- [x] Gestion modes Entraînement/Réel
- [x] Logique de jeu (paradoxe de Saint-Pétersbourg)
- [x] Documentation README.md

### 🚧 In Progress

- [ ] Tests complets de l'implémentation
- [ ] Correction des bugs identifiés
- [ ] Implémentation script 7.sh relay

### ❌ Not Started

- [ ] Tests unitaires
- [ ] Tests d'intégration
- [ ] Tests end-to-end
- [ ] Documentation API complète
- [ ] Gestion d'erreurs améliorée
- [ ] Logging et monitoring
- [ ] Statistiques de jeu
- [ ] Leaderboards

---

## 🔧 Core Functionality Fixes

### 1. Script 7.sh Relay (CRITIQUE)

**Priority**: CRITICAL  
**Status**: Not Started

**Problem** : Le script `7.sh` sur le relay doit traiter les événements kind 7 (likes) et déclencher les paiements de 1 ẐEN du joueur au CAPITAINE.

**Tasks**:
- [ ] Créer/implémenter script `7.sh` dans le relay
- [ ] Détecter les likes au CAPITAINE (kind 7 avec tag `p` = captainHEX)
- [ ] Extraire le MULTIPASS du joueur depuis son profil NOSTR
- [ ] Appeler API `/zen_send` pour envoyer 1 ẐEN du joueur au CAPITAINE
- [ ] Logger les transactions pour traçabilité
- [ ] Gérer les erreurs (solde insuffisant, API indisponible)

**Implementation Location**: `~/.zen/relay/7.sh` ou dans le code du relay

**Example**:
```bash
#!/bin/bash
# 7.sh - Process kind 7 (reaction/like) events
# When a like is sent to CAPTAIN, send 1 ẐEN from player to CAPTAIN

EVENT="$1"
KIND=$(echo "$EVENT" | jq -r '.kind')

if [[ "$KIND" == "7" ]]; then
    # Extract CAPTAIN pubkey from tags
    CAPTAIN_PUBKEY=$(echo "$EVENT" | jq -r '.tags[] | select(.[0] == "p") | .[1]')
    
    # Get CAPTAIN data from ASTROPORT station
    CAPTAIN_DATA=$(curl -s "http://127.0.0.1:12345")
    CAPTAIN_G1PUB=$(echo "$CAPTAIN_DATA" | jq -r '.CAPTAING1PUB')
    
    # Extract player pubkey
    PLAYER_PUBKEY=$(echo "$EVENT" | jq -r '.pubkey')
    
    # Get player MULTIPASS from profile
    PLAYER_PROFILE=$(get_nostr_profile "$PLAYER_PUBKEY")
    PLAYER_G1PUB=$(echo "$PLAYER_PROFILE" | jq -r '.tags[] | select(.[0] == "i" and .[1] | startswith("g1pub:")) | .[1]' | sed 's/g1pub://')
    
    # Send 1 ẐEN from player to CAPTAIN
    curl -X POST "http://127.0.0.1:54321/zen_send" \
      -F "g1source=$PLAYER_G1PUB" \
      -F "g1dest=$CAPTAIN_G1PUB" \
      -F "zen=1" \
      -F "npub=$PLAYER_PUBKEY"
fi
```

### 2. Tests API Endpoints

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Test `GET /check_balance?g1pub={G1PUB}`
  - [ ] Vérifier format réponse
  - [ ] Tester avec MULTIPASS valide
  - [ ] Tester avec MULTIPASS invalide
  - [ ] Tester gestion erreurs
- [ ] Test `POST /zen_send`
  - [ ] Tester paiement joueur → CAPITAINE (perte)
  - [ ] Tester paiement CAPITAINE → joueur (gain)
  - [ ] Tester avec solde insuffisant
  - [ ] Tester avec paramètres manquants
  - [ ] Vérifier validation MULTIPASS

**Test Scripts**:
```bash
# test_check_balance.sh
# test_zen_send.sh
```

### 3. Validation Astroport

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Vérifier que la restriction Astroport fonctionne
- [ ] Tester avec différents domaines
- [ ] Améliorer message d'erreur si restriction échoue
- [ ] Documenter les domaines autorisés

**Current Implementation**: Vérifie `hostname.includes('astroport.')` ou `hostname.includes('copylaradio.com')`

### 4. Gestion d'Erreurs Améliorée

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Améliorer messages d'erreur utilisateur
- [ ] Logger toutes les erreurs côté serveur
- [ ] Gérer timeout API
- [ ] Gérer erreurs réseau
- [ ] Gérer erreurs authentification NOSTR
- [ ] Gérer erreurs paiement

### 5. Mode Entraînement

**Priority**: LOW  
**Status**: Basic Implementation

**Tasks**:
- [ ] Vérifier que les paiements sont bien simulés
- [ ] S'assurer qu'aucun vrai paiement n'est envoyé
- [ ] Améliorer feedback visuel pour mode entraînement
- [ ] Ajouter statistiques mode entraînement

---

## 🧪 Testing & Quality Assurance

### 6. Tests Unitaires

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Tests logique de jeu (calcul gains)
- [ ] Tests détection MULTIPASS
- [ ] Tests validation Astroport
- [ ] Tests format événements NOSTR
- [ ] Tests parsing données CAPITAINE

### 7. Tests d'Intégration

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Test flux complet : Connexion → Jeu → Paiement
- [ ] Test mode Entraînement complet
- [ ] Test mode Réel complet
- [ ] Test script 7.sh avec événements réels
- [ ] Test API avec données réelles

### 8. Tests End-to-End

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Test scénario complet : Joueur gagne et encaisse
- [ ] Test scénario complet : Joueur perd (FACE)
- [ ] Test scénario complet : Joueur continue plusieurs fois
- [ ] Test avec plusieurs joueurs simultanés
- [ ] Test avec solde insuffisant

---

## 🚀 Advanced Features

### 9. Statistiques de Jeu

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Enregistrer statistiques par joueur
- [ ] Afficher historique des parties
- [ ] Calculer gains/pertes totaux
- [ ] Afficher meilleur gain
- [ ] Afficher nombre de parties

### 10. Leaderboards

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Classement meilleurs gains
- [ ] Classement nombre de parties
- [ ] Classement meilleure série (piles consécutives)
- [ ] Classement par période (jour, semaine, mois)

### 11. Notifications

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Notification paiement reçu (gain)
- [ ] Notification paiement envoyé (perte)
- [ ] Notification solde insuffisant
- [ ] Notification partie terminée

---

## 📚 Documentation & API

### 12. Documentation API Complète

**Priority**: MEDIUM  
**Status**: Partial

**Tasks**:
- [x] Créer `COINFLIP.md` - Documentation système
- [x] Créer `COINFLIP.todo.md` - Ce fichier
- [ ] Documenter endpoints API en détail
- [ ] Documenter format événements NOSTR
- [ ] Documenter script 7.sh
- [ ] Exemples d'utilisation complets
- [ ] Guide développeur

### 13. Documentation Script 7.sh

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Documenter fonctionnement script 7.sh
- [ ] Documenter format événements traités
- [ ] Documenter variables d'environnement
- [ ] Documenter gestion d'erreurs
- [ ] Exemples de logs

---

## 🔒 Security & Validation

### 14. Validation Paiements

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Vérifier solde avant paiement
- [ ] Valider MULTIPASS source et destination
- [ ] Vérifier signature événements NOSTR
- [ ] Prévenir double dépense
- [ ] Rate limiting paiements

### 15. Audit & Logging

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Logger toutes les transactions
- [ ] Logger tous les événements NOSTR
- [ ] Logger erreurs API
- [ ] Créer dashboard monitoring
- [ ] Alertes erreurs critiques

---

## 🎨 UI/UX Improvements

### 16. Amélioration Interface

**Priority**: LOW  
**Status**: Basic Implementation

**Tasks**:
- [ ] Améliorer animations
- [ ] Améliorer feedback visuel
- [ ] Ajouter son (optionnel)
- [ ] Améliorer responsive design
- [ ] Ajouter thème sombre

### 17. Mobile Optimization

**Priority**: LOW  
**Status**: Partial

**Tasks**:
- [ ] Optimiser pour mobile
- [ ] Améliorer touch events
- [ ] Adapter taille éléments
- [ ] Tester sur différents appareils

---

## 🎯 Success Criteria

### Phase 1: Core Functionality (Current)
- ✅ Interface utilisateur opérationnelle
- ✅ Intégration NOSTR fonctionnelle
- ✅ Logique de jeu implémentée
- ⚠️ Script 7.sh manquant/à implémenter
- ⚠️ Tests API manquants

### Phase 2: Testing & Fixes (Next)
- [ ] Script 7.sh implémenté et testé
- [ ] Tests API complets
- [ ] Tests d'intégration
- [ ] Correction bugs identifiés
- [ ] Gestion d'erreurs améliorée

### Phase 3: Advanced Features
- [ ] Statistiques de jeu
- [ ] Leaderboards
- [ ] Notifications
- [ ] Monitoring

### Phase 4: Production Ready
- [ ] Documentation complète
- [ ] Tests automatisés
- [ ] Performance optimisée
- [ ] Sécurité renforcée
- [ ] Audit complet

---

## 💡 Future Ideas

- **Tournois** : Compétitions multi-joueurs
- **Pari** : Système de paris entre joueurs
- **Jackpot** : Cagnotte commune
- **Achievements** : Badges et récompenses
- **Historique** : Replay des parties
- **IA** : Adversaire IA pour mode entraînement
- **Multi-langues** : Support plusieurs langues
- **Thèmes** : Personnalisation visuelle
- **Sons** : Effets sonores et musique
- **Animations 3D** : Pièce 3D animée

---

## ⚠️ Critical Issues to Fix

1. **Script 7.sh manquant** : CRITIQUE - Sans ce script, les paiements de perte ne fonctionnent pas
2. **Tests API manquants** : Les endpoints ne sont pas testés
3. **Gestion d'erreurs** : Améliorer la gestion des erreurs de paiement
4. **Validation** : Vérifier toutes les validations (MULTIPASS, Astroport, solde)

---

**Last Updated**: 2025-01-09  
**Maintainer**: UPlanet/Astroport.ONE Team  
**Status**: ⚠️ Implémentation non testée - À corriger


## 🎯 Goal

Rendre le système CoinFlip **complet, testé et opérationnel** pour permettre un jeu de pile ou face décentralisé avec paiements ZEN automatiques.

---

## 📋 Current Status

### ✅ Completed

- [x] Interface utilisateur (`coinflip/index.html`)
- [x] Intégration NOSTR (authentification, profil)
- [x] Détection API uSPOT automatique
- [x] Affichage solde CAPITAINE
- [x] Gestion modes Entraînement/Réel
- [x] Logique de jeu (paradoxe de Saint-Pétersbourg)
- [x] Documentation README.md

### 🚧 In Progress

- [ ] Tests complets de l'implémentation
- [ ] Correction des bugs identifiés
- [ ] Implémentation script 7.sh relay

### ❌ Not Started

- [ ] Tests unitaires
- [ ] Tests d'intégration
- [ ] Tests end-to-end
- [ ] Documentation API complète
- [ ] Gestion d'erreurs améliorée
- [ ] Logging et monitoring
- [ ] Statistiques de jeu
- [ ] Leaderboards

---

## 🔧 Core Functionality Fixes

### 1. Script 7.sh Relay (CRITIQUE)

**Priority**: CRITICAL  
**Status**: Not Started

**Problem** : Le script `7.sh` sur le relay doit traiter les événements kind 7 (likes) et déclencher les paiements de 1 ẐEN du joueur au CAPITAINE.

**Tasks**:
- [ ] Créer/implémenter script `7.sh` dans le relay
- [ ] Détecter les likes au CAPITAINE (kind 7 avec tag `p` = captainHEX)
- [ ] Extraire le MULTIPASS du joueur depuis son profil NOSTR
- [ ] Appeler API `/zen_send` pour envoyer 1 ẐEN du joueur au CAPITAINE
- [ ] Logger les transactions pour traçabilité
- [ ] Gérer les erreurs (solde insuffisant, API indisponible)

**Implementation Location**: `~/.zen/relay/7.sh` ou dans le code du relay

**Example**:
```bash
#!/bin/bash
# 7.sh - Process kind 7 (reaction/like) events
# When a like is sent to CAPTAIN, send 1 ẐEN from player to CAPTAIN

EVENT="$1"
KIND=$(echo "$EVENT" | jq -r '.kind')

if [[ "$KIND" == "7" ]]; then
    # Extract CAPTAIN pubkey from tags
    CAPTAIN_PUBKEY=$(echo "$EVENT" | jq -r '.tags[] | select(.[0] == "p") | .[1]')
    
    # Get CAPTAIN data from ASTROPORT station
    CAPTAIN_DATA=$(curl -s "http://127.0.0.1:12345")
    CAPTAIN_G1PUB=$(echo "$CAPTAIN_DATA" | jq -r '.CAPTAING1PUB')
    
    # Extract player pubkey
    PLAYER_PUBKEY=$(echo "$EVENT" | jq -r '.pubkey')
    
    # Get player MULTIPASS from profile
    PLAYER_PROFILE=$(get_nostr_profile "$PLAYER_PUBKEY")
    PLAYER_G1PUB=$(echo "$PLAYER_PROFILE" | jq -r '.tags[] | select(.[0] == "i" and .[1] | startswith("g1pub:")) | .[1]' | sed 's/g1pub://')
    
    # Send 1 ẐEN from player to CAPTAIN
    curl -X POST "http://127.0.0.1:54321/zen_send" \
      -F "g1source=$PLAYER_G1PUB" \
      -F "g1dest=$CAPTAIN_G1PUB" \
      -F "zen=1" \
      -F "npub=$PLAYER_PUBKEY"
fi
```

### 2. Tests API Endpoints

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Test `GET /check_balance?g1pub={G1PUB}`
  - [ ] Vérifier format réponse
  - [ ] Tester avec MULTIPASS valide
  - [ ] Tester avec MULTIPASS invalide
  - [ ] Tester gestion erreurs
- [ ] Test `POST /zen_send`
  - [ ] Tester paiement joueur → CAPITAINE (perte)
  - [ ] Tester paiement CAPITAINE → joueur (gain)
  - [ ] Tester avec solde insuffisant
  - [ ] Tester avec paramètres manquants
  - [ ] Vérifier validation MULTIPASS

**Test Scripts**:
```bash
# test_check_balance.sh
# test_zen_send.sh
```

### 3. Validation Astroport

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Vérifier que la restriction Astroport fonctionne
- [ ] Tester avec différents domaines
- [ ] Améliorer message d'erreur si restriction échoue
- [ ] Documenter les domaines autorisés

**Current Implementation**: Vérifie `hostname.includes('astroport.')` ou `hostname.includes('copylaradio.com')`

### 4. Gestion d'Erreurs Améliorée

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Améliorer messages d'erreur utilisateur
- [ ] Logger toutes les erreurs côté serveur
- [ ] Gérer timeout API
- [ ] Gérer erreurs réseau
- [ ] Gérer erreurs authentification NOSTR
- [ ] Gérer erreurs paiement

### 5. Mode Entraînement

**Priority**: LOW  
**Status**: Basic Implementation

**Tasks**:
- [ ] Vérifier que les paiements sont bien simulés
- [ ] S'assurer qu'aucun vrai paiement n'est envoyé
- [ ] Améliorer feedback visuel pour mode entraînement
- [ ] Ajouter statistiques mode entraînement

---

## 🧪 Testing & Quality Assurance

### 6. Tests Unitaires

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Tests logique de jeu (calcul gains)
- [ ] Tests détection MULTIPASS
- [ ] Tests validation Astroport
- [ ] Tests format événements NOSTR
- [ ] Tests parsing données CAPITAINE

### 7. Tests d'Intégration

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Test flux complet : Connexion → Jeu → Paiement
- [ ] Test mode Entraînement complet
- [ ] Test mode Réel complet
- [ ] Test script 7.sh avec événements réels
- [ ] Test API avec données réelles

### 8. Tests End-to-End

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Test scénario complet : Joueur gagne et encaisse
- [ ] Test scénario complet : Joueur perd (FACE)
- [ ] Test scénario complet : Joueur continue plusieurs fois
- [ ] Test avec plusieurs joueurs simultanés
- [ ] Test avec solde insuffisant

---

## 🚀 Advanced Features

### 9. Statistiques de Jeu

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Enregistrer statistiques par joueur
- [ ] Afficher historique des parties
- [ ] Calculer gains/pertes totaux
- [ ] Afficher meilleur gain
- [ ] Afficher nombre de parties

### 10. Leaderboards

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Classement meilleurs gains
- [ ] Classement nombre de parties
- [ ] Classement meilleure série (piles consécutives)
- [ ] Classement par période (jour, semaine, mois)

### 11. Notifications

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Notification paiement reçu (gain)
- [ ] Notification paiement envoyé (perte)
- [ ] Notification solde insuffisant
- [ ] Notification partie terminée

---

## 📚 Documentation & API

### 12. Documentation API Complète

**Priority**: MEDIUM  
**Status**: Partial

**Tasks**:
- [x] Créer `COINFLIP.md` - Documentation système
- [x] Créer `COINFLIP.todo.md` - Ce fichier
- [ ] Documenter endpoints API en détail
- [ ] Documenter format événements NOSTR
- [ ] Documenter script 7.sh
- [ ] Exemples d'utilisation complets
- [ ] Guide développeur

### 13. Documentation Script 7.sh

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Documenter fonctionnement script 7.sh
- [ ] Documenter format événements traités
- [ ] Documenter variables d'environnement
- [ ] Documenter gestion d'erreurs
- [ ] Exemples de logs

---

## 🔒 Security & Validation

### 14. Validation Paiements

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Vérifier solde avant paiement
- [ ] Valider MULTIPASS source et destination
- [ ] Vérifier signature événements NOSTR
- [ ] Prévenir double dépense
- [ ] Rate limiting paiements

### 15. Audit & Logging

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Logger toutes les transactions
- [ ] Logger tous les événements NOSTR
- [ ] Logger erreurs API
- [ ] Créer dashboard monitoring
- [ ] Alertes erreurs critiques

---

## 🎨 UI/UX Improvements

### 16. Amélioration Interface

**Priority**: LOW  
**Status**: Basic Implementation

**Tasks**:
- [ ] Améliorer animations
- [ ] Améliorer feedback visuel
- [ ] Ajouter son (optionnel)
- [ ] Améliorer responsive design
- [ ] Ajouter thème sombre

### 17. Mobile Optimization

**Priority**: LOW  
**Status**: Partial

**Tasks**:
- [ ] Optimiser pour mobile
- [ ] Améliorer touch events
- [ ] Adapter taille éléments
- [ ] Tester sur différents appareils

---

## 🎯 Success Criteria

### Phase 1: Core Functionality (Current)
- ✅ Interface utilisateur opérationnelle
- ✅ Intégration NOSTR fonctionnelle
- ✅ Logique de jeu implémentée
- ⚠️ Script 7.sh manquant/à implémenter
- ⚠️ Tests API manquants

### Phase 2: Testing & Fixes (Next)
- [ ] Script 7.sh implémenté et testé
- [ ] Tests API complets
- [ ] Tests d'intégration
- [ ] Correction bugs identifiés
- [ ] Gestion d'erreurs améliorée

### Phase 3: Advanced Features
- [ ] Statistiques de jeu
- [ ] Leaderboards
- [ ] Notifications
- [ ] Monitoring

### Phase 4: Production Ready
- [ ] Documentation complète
- [ ] Tests automatisés
- [ ] Performance optimisée
- [ ] Sécurité renforcée
- [ ] Audit complet

---

## 💡 Future Ideas

- **Tournois** : Compétitions multi-joueurs
- **Pari** : Système de paris entre joueurs
- **Jackpot** : Cagnotte commune
- **Achievements** : Badges et récompenses
- **Historique** : Replay des parties
- **IA** : Adversaire IA pour mode entraînement
- **Multi-langues** : Support plusieurs langues
- **Thèmes** : Personnalisation visuelle
- **Sons** : Effets sonores et musique
- **Animations 3D** : Pièce 3D animée

---

## ⚠️ Critical Issues to Fix

1. **Script 7.sh manquant** : CRITIQUE - Sans ce script, les paiements de perte ne fonctionnent pas
2. **Tests API manquants** : Les endpoints ne sont pas testés
3. **Gestion d'erreurs** : Améliorer la gestion des erreurs de paiement
4. **Validation** : Vérifier toutes les validations (MULTIPASS, Astroport, solde)

---

**Last Updated**: 2025-01-09  
**Maintainer**: UPlanet/Astroport.ONE Team  
**Status**: ⚠️ Implémentation non testée - À corriger


## 🎯 Goal

Rendre le système CoinFlip **complet, testé et opérationnel** pour permettre un jeu de pile ou face décentralisé avec paiements ZEN automatiques.

---

## 📋 Current Status

### ✅ Completed

- [x] Interface utilisateur (`coinflip/index.html`)
- [x] Intégration NOSTR (authentification, profil)
- [x] Détection API uSPOT automatique
- [x] Affichage solde CAPITAINE
- [x] Gestion modes Entraînement/Réel
- [x] Logique de jeu (paradoxe de Saint-Pétersbourg)
- [x] Documentation README.md

### 🚧 In Progress

- [ ] Tests complets de l'implémentation
- [ ] Correction des bugs identifiés
- [ ] Implémentation script 7.sh relay

### ❌ Not Started

- [ ] Tests unitaires
- [ ] Tests d'intégration
- [ ] Tests end-to-end
- [ ] Documentation API complète
- [ ] Gestion d'erreurs améliorée
- [ ] Logging et monitoring
- [ ] Statistiques de jeu
- [ ] Leaderboards

---

## 🔧 Core Functionality Fixes

### 1. Script 7.sh Relay (CRITIQUE)

**Priority**: CRITICAL  
**Status**: Not Started

**Problem** : Le script `7.sh` sur le relay doit traiter les événements kind 7 (likes) et déclencher les paiements de 1 ẐEN du joueur au CAPITAINE.

**Tasks**:
- [ ] Créer/implémenter script `7.sh` dans le relay
- [ ] Détecter les likes au CAPITAINE (kind 7 avec tag `p` = captainHEX)
- [ ] Extraire le MULTIPASS du joueur depuis son profil NOSTR
- [ ] Appeler API `/zen_send` pour envoyer 1 ẐEN du joueur au CAPITAINE
- [ ] Logger les transactions pour traçabilité
- [ ] Gérer les erreurs (solde insuffisant, API indisponible)

**Implementation Location**: `~/.zen/relay/7.sh` ou dans le code du relay

**Example**:
```bash
#!/bin/bash
# 7.sh - Process kind 7 (reaction/like) events
# When a like is sent to CAPTAIN, send 1 ẐEN from player to CAPTAIN

EVENT="$1"
KIND=$(echo "$EVENT" | jq -r '.kind')

if [[ "$KIND" == "7" ]]; then
    # Extract CAPTAIN pubkey from tags
    CAPTAIN_PUBKEY=$(echo "$EVENT" | jq -r '.tags[] | select(.[0] == "p") | .[1]')
    
    # Get CAPTAIN data from ASTROPORT station
    CAPTAIN_DATA=$(curl -s "http://127.0.0.1:12345")
    CAPTAIN_G1PUB=$(echo "$CAPTAIN_DATA" | jq -r '.CAPTAING1PUB')
    
    # Extract player pubkey
    PLAYER_PUBKEY=$(echo "$EVENT" | jq -r '.pubkey')
    
    # Get player MULTIPASS from profile
    PLAYER_PROFILE=$(get_nostr_profile "$PLAYER_PUBKEY")
    PLAYER_G1PUB=$(echo "$PLAYER_PROFILE" | jq -r '.tags[] | select(.[0] == "i" and .[1] | startswith("g1pub:")) | .[1]' | sed 's/g1pub://')
    
    # Send 1 ẐEN from player to CAPTAIN
    curl -X POST "http://127.0.0.1:54321/zen_send" \
      -F "g1source=$PLAYER_G1PUB" \
      -F "g1dest=$CAPTAIN_G1PUB" \
      -F "zen=1" \
      -F "npub=$PLAYER_PUBKEY"
fi
```

### 2. Tests API Endpoints

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Test `GET /check_balance?g1pub={G1PUB}`
  - [ ] Vérifier format réponse
  - [ ] Tester avec MULTIPASS valide
  - [ ] Tester avec MULTIPASS invalide
  - [ ] Tester gestion erreurs
- [ ] Test `POST /zen_send`
  - [ ] Tester paiement joueur → CAPITAINE (perte)
  - [ ] Tester paiement CAPITAINE → joueur (gain)
  - [ ] Tester avec solde insuffisant
  - [ ] Tester avec paramètres manquants
  - [ ] Vérifier validation MULTIPASS

**Test Scripts**:
```bash
# test_check_balance.sh
# test_zen_send.sh
```

### 3. Validation Astroport

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Vérifier que la restriction Astroport fonctionne
- [ ] Tester avec différents domaines
- [ ] Améliorer message d'erreur si restriction échoue
- [ ] Documenter les domaines autorisés

**Current Implementation**: Vérifie `hostname.includes('astroport.')` ou `hostname.includes('copylaradio.com')`

### 4. Gestion d'Erreurs Améliorée

**Priority**: MEDIUM  
**Status**: Basic Implementation

**Tasks**:
- [ ] Améliorer messages d'erreur utilisateur
- [ ] Logger toutes les erreurs côté serveur
- [ ] Gérer timeout API
- [ ] Gérer erreurs réseau
- [ ] Gérer erreurs authentification NOSTR
- [ ] Gérer erreurs paiement

### 5. Mode Entraînement

**Priority**: LOW  
**Status**: Basic Implementation

**Tasks**:
- [ ] Vérifier que les paiements sont bien simulés
- [ ] S'assurer qu'aucun vrai paiement n'est envoyé
- [ ] Améliorer feedback visuel pour mode entraînement
- [ ] Ajouter statistiques mode entraînement

---

## 🧪 Testing & Quality Assurance

### 6. Tests Unitaires

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Tests logique de jeu (calcul gains)
- [ ] Tests détection MULTIPASS
- [ ] Tests validation Astroport
- [ ] Tests format événements NOSTR
- [ ] Tests parsing données CAPITAINE

### 7. Tests d'Intégration

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Test flux complet : Connexion → Jeu → Paiement
- [ ] Test mode Entraînement complet
- [ ] Test mode Réel complet
- [ ] Test script 7.sh avec événements réels
- [ ] Test API avec données réelles

### 8. Tests End-to-End

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Test scénario complet : Joueur gagne et encaisse
- [ ] Test scénario complet : Joueur perd (FACE)
- [ ] Test scénario complet : Joueur continue plusieurs fois
- [ ] Test avec plusieurs joueurs simultanés
- [ ] Test avec solde insuffisant

---

## 🚀 Advanced Features

### 9. Statistiques de Jeu

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Enregistrer statistiques par joueur
- [ ] Afficher historique des parties
- [ ] Calculer gains/pertes totaux
- [ ] Afficher meilleur gain
- [ ] Afficher nombre de parties

### 10. Leaderboards

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Classement meilleurs gains
- [ ] Classement nombre de parties
- [ ] Classement meilleure série (piles consécutives)
- [ ] Classement par période (jour, semaine, mois)

### 11. Notifications

**Priority**: LOW  
**Status**: Not Started

**Tasks**:
- [ ] Notification paiement reçu (gain)
- [ ] Notification paiement envoyé (perte)
- [ ] Notification solde insuffisant
- [ ] Notification partie terminée

---

## 📚 Documentation & API

### 12. Documentation API Complète

**Priority**: MEDIUM  
**Status**: Partial

**Tasks**:
- [x] Créer `COINFLIP.md` - Documentation système
- [x] Créer `COINFLIP.todo.md` - Ce fichier
- [ ] Documenter endpoints API en détail
- [ ] Documenter format événements NOSTR
- [ ] Documenter script 7.sh
- [ ] Exemples d'utilisation complets
- [ ] Guide développeur

### 13. Documentation Script 7.sh

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Documenter fonctionnement script 7.sh
- [ ] Documenter format événements traités
- [ ] Documenter variables d'environnement
- [ ] Documenter gestion d'erreurs
- [ ] Exemples de logs

---

## 🔒 Security & Validation

### 14. Validation Paiements

**Priority**: HIGH  
**Status**: Not Started

**Tasks**:
- [ ] Vérifier solde avant paiement
- [ ] Valider MULTIPASS source et destination
- [ ] Vérifier signature événements NOSTR
- [ ] Prévenir double dépense
- [ ] Rate limiting paiements

### 15. Audit & Logging

**Priority**: MEDIUM  
**Status**: Not Started

**Tasks**:
- [ ] Logger toutes les transactions
- [ ] Logger tous les événements NOSTR
- [ ] Logger erreurs API
- [ ] Créer dashboard monitoring
- [ ] Alertes erreurs critiques

---

## 🎨 UI/UX Improvements

### 16. Amélioration Interface

**Priority**: LOW  
**Status**: Basic Implementation

**Tasks**:
- [ ] Améliorer animations
- [ ] Améliorer feedback visuel
- [ ] Ajouter son (optionnel)
- [ ] Améliorer responsive design
- [ ] Ajouter thème sombre

### 17. Mobile Optimization

**Priority**: LOW  
**Status**: Partial

**Tasks**:
- [ ] Optimiser pour mobile
- [ ] Améliorer touch events
- [ ] Adapter taille éléments
- [ ] Tester sur différents appareils

---

## 🎯 Success Criteria

### Phase 1: Core Functionality (Current)
- ✅ Interface utilisateur opérationnelle
- ✅ Intégration NOSTR fonctionnelle
- ✅ Logique de jeu implémentée
- ⚠️ Script 7.sh manquant/à implémenter
- ⚠️ Tests API manquants

### Phase 2: Testing & Fixes (Next)
- [ ] Script 7.sh implémenté et testé
- [ ] Tests API complets
- [ ] Tests d'intégration
- [ ] Correction bugs identifiés
- [ ] Gestion d'erreurs améliorée

### Phase 3: Advanced Features
- [ ] Statistiques de jeu
- [ ] Leaderboards
- [ ] Notifications
- [ ] Monitoring

### Phase 4: Production Ready
- [ ] Documentation complète
- [ ] Tests automatisés
- [ ] Performance optimisée
- [ ] Sécurité renforcée
- [ ] Audit complet

---

## 💡 Future Ideas

- **Tournois** : Compétitions multi-joueurs
- **Pari** : Système de paris entre joueurs
- **Jackpot** : Cagnotte commune
- **Achievements** : Badges et récompenses
- **Historique** : Replay des parties
- **IA** : Adversaire IA pour mode entraînement
- **Multi-langues** : Support plusieurs langues
- **Thèmes** : Personnalisation visuelle
- **Sons** : Effets sonores et musique
- **Animations 3D** : Pièce 3D animée

---

## ⚠️ Critical Issues to Fix

1. **Script 7.sh manquant** : CRITIQUE - Sans ce script, les paiements de perte ne fonctionnent pas
2. **Tests API manquants** : Les endpoints ne sont pas testés
3. **Gestion d'erreurs** : Améliorer la gestion des erreurs de paiement
4. **Validation** : Vérifier toutes les validations (MULTIPASS, Astroport, solde)

---

**Last Updated**: 2025-01-09  
**Maintainer**: UPlanet/Astroport.ONE Team  
**Status**: ⚠️ Implémentation non testée - À corriger

