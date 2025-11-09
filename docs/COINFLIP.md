# CoinFlip - Jeu de Pile ou Face (St. Petersburg Paradox)

**Version** : 1.0  
**Date** : 2025-01-09  
**Status** : Implémentation non testée - À corriger  
**License** : AGPL-3.0

---

## 📖 Vue d'Ensemble

**CoinFlip** est un jeu de pile ou face basé sur le **paradoxe de Saint-Pétersbourg**, intégré avec l'authentification NOSTR et les paiements UPlanet Ẑen. Les joueurs utilisent leur MULTIPASS pour jouer, et toutes les transactions sont traitées via le MULTIPASS du CAPITAINE.

### Objectif

Créer un jeu de hasard décentralisé où :
- Les joueurs peuvent gagner des Ẑen en doublant leurs gains à chaque pile
- Les pertes déclenchent un paiement de 1 Ẑen au CAPITAINE
- L'authentification et les paiements sont gérés via NOSTR et UPlanet

---

## 🎮 Mécaniques de Jeu

### Paradoxe de Saint-Pétersbourg

- **Gains Progressifs** : Les gains doublent à chaque pile consécutive (2⁰ = 1, 2¹ = 2, 2² = 4, 2³ = 8...)
- **Risque vs Récompense** : Les joueurs peuvent encaisser à tout moment ou continuer à jouer
- **Fin de Partie** : Quand face apparaît, le joueur perd la cagnotte et envoie 1 ẐEN au CAPITAINE

### Système de Choix du Joueur

- **Encaisser** : Sécuriser les gains actuels et terminer la partie avec succès
- **Continuer** : Risquer tout pour doubler le gain au prochain lancer
- **Résultat Face** : Le joueur perd tous les gains potentiels et envoie 1 ẐEN au CAPITAINE

---

## 🔐 Authentification & Système de Paiement

### Exigence MULTIPASS

- **MULTIPASS Uniquement** : Seuls les joueurs avec un MULTIPASS valide (g1pub dans le profil NOSTR) peuvent jouer
- **Restriction Astroport** : Le jeu ne peut être joué que sur l'Astroport où le MULTIPASS du joueur est enregistré (requis pour que le relay NOSTR trouve la clé du joueur lors de l'envoi du like au CAPITAINE)

### Flux de Paiement

1. **MULTIPASS Joueur** : Utilisé pour l'identification et la vérification du solde
2. **MULTIPASS CAPITAINE** : Toutes les transactions sont traitées via le portefeuille du CAPITAINE
3. **Système de Paiement** : Quand FACE apparaît, le joueur envoie un like au CAPITAINE → déclenche un paiement de 1 ẐEN du joueur au CAPITAINE
4. **Gains** : Payés directement au MULTIPASS du joueur depuis le portefeuille du CAPITAINE lors de l'encaissement

---

## 🎯 Modes de Jeu

### Mode Entraînement

- **Pas d'Authentification** : Disponible pour tous les utilisateurs
- **Paiements Simulés** : Aucun argent réel impliqué
- **Simulation de Paiement** : Le paiement FACE du joueur au CAPITAINE est simulé, pas de vrais paiements
- **Éducatif** : Apprendre les mécaniques du jeu sans risque financier

### Mode Réel

- **MULTIPASS Requis** : Doit avoir un MULTIPASS valide dans le profil NOSTR
- **Vrais Paiements** : Toutes les transactions utilisent la vraie monnaie ZEN
- **Paiements de Perte** : FACE envoie un like au CAPITAINE → paiement de 1 ẐEN du joueur au CAPITAINE traité
- **Paiements de Gains** : Vrais paiements ZEN envoyés au MULTIPASS du gagnant lors de l'encaissement

---

## 🏗️ Architecture Technique

### Intégration NOSTR

- **Récupération de Profil** : Récupère le profil du joueur depuis les relays NOSTR
- **Détection MULTIPASS** : Vérifie les tags g1pub ou g1pubv2 dans le profil
- **Vérification du Solde** : Récupère le solde ZEN du joueur via l'API uSPOT
- **Authentification** : Authentification NIP-42 relay pour communication sécurisée

### Traitement des Paiements

- **Données CAPITAINE** : Récupérées depuis l'API ASTROPORT station
- **Source de Transaction** : MULTIPASS du CAPITAINE (paramètre g1source)
- **Destination de Transaction** : MULTIPASS du joueur (paramètre g1dest)
- **Point de Terminaison API** : `/zen_send` via l'API uSPOT

### Système de Paiement de Perte

- **Événement NOSTR** : Kind 7 (réaction) envoyé au premier message du CAPITAINE quand FACE se produit
- **Déclencheur de Paiement** : Le like déclenche un paiement de 1 ẐEN du joueur au CAPITAINE
- **Traitement Relay** : Script 7.sh sur le relay traite le paiement du joueur au CAPITAINE

---

## 🔄 Workflow Complet

### 1. Connexion & Authentification

1. Connexion avec extension NOSTR
2. Le profil est récupéré et validé
3. Le paramètre MULTIPASS est vérifié
4. Le solde est vérifié via l'API uSPOT

### 2. Initialisation du Jeu

1. Le jeu commence immédiatement avec le premier lancer
2. Le mode de jeu est déterminé (Entraînement vs Réel)
3. Les données CAPITAINE sont récupérées pour le traitement des paiements

### 3. Boucle de Gameplay

- **Pile** : Continuer à lancer, les gains doublent, pas de paiement
- **Face** : Le jeu se termine, le joueur perd tous les gains potentiels, like envoyé au CAPITAINE → paiement de 1 ẐEN envoyé au CAPITAINE
- **Encaisser** : Le joueur peut sécuriser les gains à tout moment et terminer le jeu avec succès

### 4. Traitement des Paiements

- **Paiement de Perte** : 1 ẐEN envoyé du joueur au CAPITAINE quand FACE apparaît
- **Paiement de Gain** : Gains finaux envoyés au MULTIPASS du joueur (seulement si le joueur encaisse)
- **Événement de Perte** : Quand face apparaît, le joueur perd tous les gains potentiels et envoie 1 ẐEN au CAPITAINE
- **Source de Transaction** : Portefeuille MULTIPASS du CAPITAINE
- **Confirmation** : Statut de paiement affiché au joueur

---

## 🔌 Intégration API

### API uSPOT

**Vérification du Solde** :
```bash
GET /check_balance?g1pub={G1PUB}
```

**Paiement** :
```bash
POST /zen_send
Content-Type: application/x-www-form-urlencoded

g1source={CAPTAIN_G1PUB}
g1dest={PLAYER_G1PUB}
zen={AMOUNT}
npub={PLAYER_NPUB}
zencard={CAPTAIN_ZENCARD_G1PUB}
```

**Paramètres** :
- `g1source` : MULTIPASS du CAPITAINE (source du paiement)
- `g1dest` : MULTIPASS du joueur (destination du paiement)
- `zen` : Montant en Ẑen
- `npub` : Clé publique NOSTR du joueur
- `zencard` : ZENCARD du CAPITAINE (optionnel)

### API ASTROPORT Station

**Données CAPITAINE** : Récupère captainHEX, captainG1pub, captainZencardG1pub

**Point de Terminaison** : URL Station configurée via détection du hostname

**Format** :
```json
{
  "captainHEX": "hex_pubkey",
  "CAPTAING1PUB": "g1pub_key",
  "CAPTAINZENCARDG1PUB": "zencard_g1pub_key"
}
```

### Relays NOSTR

- **Récupération de Profil** : Événements kind 0 pour les profils des joueurs
- **Publication de Like** : Événements kind 7 pour les réactions CAPITAINE
- **Authentification** : Challenge/réponse NIP-42

---

## 🔒 Fonctionnalités de Sécurité

### Authentification

- **NIP-42** : Authentification relay sécurisée
- **Vérification MULTIPASS** : Seuls les profils vérifiés peuvent jouer en mode réel
- **Restriction Astroport** : Empêche le gameplay cross-domain

### Sécurité des Paiements

- **Source CAPITAINE** : Tous les paiements proviennent du portefeuille du CAPITAINE
- **Destination Joueur** : Paiements envoyés au MULTIPASS vérifié du joueur
- **Validation de Transaction** : Tous les paiements nécessitent un MULTIPASS valide

### Gestion de Session

- **Validation de Profil** : Vérification continue des identifiants du joueur
- **Vérification du Solde** : Mises à jour du solde en temps réel
- **Confirmation de Paiement** : Rapports détaillés du statut de transaction

---

## 🐛 Gestion des Erreurs

### Problèmes Courants

1. **"MULTIPASS requis"** : Ajouter le tag g1pub au profil NOSTR
2. **"Astroport Requis"** : Jouer uniquement sur le domaine Astroport enregistré
3. **Paiement échoué** : Vérifier le solde du CAPITAINE et la connectivité réseau
4. **Authentification échouée** : Vérifier l'extension NOSTR et l'accès au relay

### Informations de Débogage

- Journalisation console pour toutes les opérations
- Suivi des requêtes/réponses de paiement
- Détails de validation de profil
- Rapports de conditions d'erreur

---

## 📡 Événements NOSTR

### Kind 0 - Profil Utilisateur

**Définition** : Profil NOSTR du joueur

**Tags Requis** :
- `["i", "g1pub:VOTRE_CLE_G1"]` : MULTIPASS du joueur
- `["i", "zencard:VOTRE_ZENCARD"]` : ZENCARD (optionnel)

### Kind 7 - Réaction (Like)

**Définition** : Like envoyé au CAPITAINE quand FACE apparaît

**Structure** :
```json
{
  "kind": 7,
  "tags": [
    ["e", "CAPTAIN_FIRST_MESSAGE_ID"],
    ["p", "CAPTAIN_HEX"],
    ["k", "1"]
  ],
  "content": "+"
}
```

**Traitement** : Le script `7.sh` sur le relay traite le paiement de 1 ẐEN du joueur au CAPITAINE

### Kind 22242 - Authentification NIP-42

**Définition** : Événement d'authentification pour le relay

**Structure** :
```json
{
  "kind": 22242,
  "tags": [
    ["relay", "wss://relay.url"],
    ["challenge", "challenge_string"]
  ],
  "content": ""
}
```

---

## 🚀 Utilisation

### Pour les Utilisateurs

1. **Accéder au Jeu** : `http://127.0.0.1:54321/coinflip` ou via IPNS
2. **Se connecter** : Bouton "Se connecter avec Nostr" (extension NOSTR requise)
3. **Vérifier MULTIPASS** : Le profil doit contenir un tag `g1pub`
4. **Jouer** : Cliquer sur la pièce pour lancer
5. **Encaisser** : Bouton "💰 ENCAISSER" pour sécuriser les gains
6. **Continuer** : Cliquer à nouveau sur la pièce pour risquer et doubler

### Pour les Développeurs

**Tester l'API** :
```bash
# Vérifier le solde
curl "http://127.0.0.1:54321/check_balance?g1pub=G1PUB_KEY"

# Envoyer un paiement (exemple)
curl -X POST "http://127.0.0.1:54321/zen_send" \
  -F "g1source=CAPTAIN_G1PUB" \
  -F "g1dest=PLAYER_G1PUB" \
  -F "zen=1" \
  -F "npub=PLAYER_NPUB" \
  -F "zencard=CAPTAIN_ZENCARD_G1PUB"
```

**Tester le Relay** :
```bash
# Vérifier que le script 7.sh existe et traite les likes
ls -la ~/.zen/relay/7.sh
```

---

## 🔧 Composants Techniques

### Frontend

**Fichier** : `UPlanet/earth/coinflip/index.html`

**Fonctionnalités** :
- Interface utilisateur Bootstrap
- Intégration NOSTR (nostr.bundle.js)
- Détection API uSPOT automatique
- Affichage solde CAPITAINE
- Gestion modes Entraînement/Réel
- Animations et feedback visuel

### Backend API

**Endpoints** :
- `GET /check_balance?g1pub={G1PUB}` : Vérification solde
- `POST /zen_send` : Envoi paiement ZEN

**Scripts** :
- `zen_send.sh` : Script de traitement des paiements
- `7.sh` : Script relay pour traitement des likes (kind 7)

### Intégration Relay

**Script 7.sh** : Doit traiter les événements kind 7 (likes) et déclencher les paiements

**Localisation** : `~/.zen/relay/7.sh`

**Fonctionnalité** : Détecte les likes au CAPITAINE et envoie 1 ẐEN du joueur au CAPITAINE

---

## ⚠️ Problèmes Connus & À Corriger

### Problèmes Identifiés

1. **Script 7.sh manquant** : Le script relay pour traiter les likes n'est peut-être pas implémenté
2. **API non testée** : Les endpoints `/zen_send` et `/check_balance` nécessitent des tests
3. **Gestion d'erreurs** : Améliorer la gestion des erreurs de paiement
4. **Validation Astroport** : Vérifier que la restriction Astroport fonctionne correctement
5. **Mode Entraînement** : S'assurer que les paiements sont bien simulés

### Tests Requis

- [ ] Test connexion NOSTR
- [ ] Test vérification MULTIPASS
- [ ] Test vérification solde
- [ ] Test paiement gain (encaissement)
- [ ] Test paiement perte (FACE → like → 1 ẐEN)
- [ ] Test script 7.sh relay
- [ ] Test restriction Astroport
- [ ] Test mode Entraînement (simulation)

---

## 📚 Références

- **[README CoinFlip](UPlanet/earth/coinflip/README.md)** : Documentation originale
- **[API uSPOT](UPassport/README.md)** : Documentation API uSPOT
- **[NIP-42](../nostr-nips/42.md)** : Authentification NOSTR
- **[NIP-25](../nostr-nips/25.md)** : Réactions (kind 7)

---

**Version** : 1.0  
**Dernière mise à jour** : 2025-01-09  
**Mainteneur** : UPlanet/Astroport.ONE Team  
**Status** : ⚠️ Implémentation non testée - À corriger

