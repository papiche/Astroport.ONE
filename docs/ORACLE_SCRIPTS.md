# 🔧 Scripts Oracle - Description et Alignement v3.0

**Version** : 3.0 - Système 100% Dynamique  
**Date** : Décembre 2025  
**Status** : Production

> Ce document décrit tous les scripts Oracle actifs et leur alignement avec le système v3.0.

---

## 📋 Liste des Scripts

### Scripts Actifs

1. **`RUNTIME/ORACLE.refresh.sh`** - Maintenance quotidienne (ACTIF)
2. **`tools/oracle_init_permit_definitions.sh`** - Gestion permits officiels (ACTIF)
3. **`tools/oracle.WoT_PERMIT.init.sh`** - Bootstrap permits officiels (ACTIF)
4. **`tools/oracle_test_permit_system.sh`** - Tests du système (ACTIF)

---

## 1. ORACLE.refresh.sh

**Localisation** : `Astroport.ONE/RUNTIME/ORACLE.refresh.sh`  
**Type** : Script de maintenance automatique  
**Exécution** : Quotidienne (via cron)  
**Version** : 3.0 - Aligné avec système 100% dynamique

### Description

Script de maintenance quotidienne qui automatise l'ensemble du cycle de vie des permits Oracle :

1. **Vérification des demandes 30501** :
   - Récupère toutes les demandes depuis Nostr
   - Compte les attestations 30502 pour chaque demande
   - Émet 30503 si seuil atteint

2. **Progression automatique WoTx2** :
   - Détecte les professions auto-proclamées validées (`PERMIT_PROFESSION_*_X{n}`)
   - Authentifie avec NIP-42 (kind 22242) avant chaque appel API
   - Crée automatiquement le niveau suivant (X(n+1))
   - Progression illimitée : X1 → X2 → ... → X144 → ...

3. **Vérification des credentials expirés** :
   - Liste tous les credentials
   - Signale ceux qui ont expiré

4. **Génération de statistiques** :
   - Compte demandes et credentials par permit
   - Sauvegarde dans `~/.zen/tmp/${IPFSNODEID}/ORACLE/`

5. **Publication sur Nostr** :
   - Publie un rapport quotidien (kind 1)
   - Signé par UPLANETNAME_G1

6. **Nettoyage** :
   - Supprime fichiers temporaires > 7 jours

### Alignement v3.0

✅ **Aligné** :
- Détection des professions auto-proclamées
- Progression automatique illimitée (X1 → X144+)
- Authentification NIP-42 avant appels API
- Labels dynamiques (Expert, Maître, Grand Maître, Maître Absolu)
- Calcul automatique des exigences (N signatures pour niveau XN)

### Configuration

```bash
# Exécution quotidienne à 2h du matin
0 2 * * * /path/to/ORACLE.refresh.sh >> /var/log/oracle_refresh.log 2>&1
```

### Variables Requises

- `IPFSNODEID` : Identifiant du nœud IPFS (obligatoire)
- `UPLANETNAME` : Nom de l'UPlanet (pour génération clés G1)
- `uSPOT` : URL de base de l'API (défaut: `http://127.0.0.1:54321`)
- `myRELAY` : URL du relay Nostr (défaut: `ws://127.0.0.1:7777`)

---

## 2. oracle_init_permit_definitions.sh

**Localisation** : `Astroport.ONE/tools/oracle_init_permit_definitions.sh`  
**Type** : Script interactif de gestion  
**Exécution** : Manuelle  
**Version** : 3.0 - Mis à jour pour système 100% dynamique

### Description

Script interactif en ligne de commande pour gérer les **permits officiels uniquement** :

**Fonctionnalités** :
1. **Ajouter un permit officiel** :
   - Sélection depuis le template JSON (`templates/NOSTR/permit_definitions.json`)
   - Publication sur Nostr (kind 30500)
   - Signé par UPLANETNAME_G1

2. **Éditer un permit existant** :
   - Liste tous les permits (officiels et WoTx2)
   - Permet de modifier un permit officiel
   - Republie sur Nostr (parameterized replaceable event)

3. **Supprimer un permit** :
   - Vérifie qu'aucun credential 30503 n'existe
   - Publie un marqueur de suppression
   - Sécurité : demande confirmation explicite

4. **Lister les permits** :
   - Affiche tous les permits depuis Nostr
   - Distingue visuellement permits officiels et WoTx2
   - Compteurs : X officiels, Y WoTx2

### Alignement v3.0

✅ **Aligné** :
- Avertissements clairs : script pour permits officiels uniquement
- Détection des professions auto-proclamées (avertit si tentative de création)
- Liste améliorée avec distinction officiels/WoTx2
- Référence vers `/wotx2` pour créer des professions auto-proclamées

⚠️ **Limitations** :
- Ne peut pas créer de professions auto-proclamées (utiliser `/wotx2`)
- Ne gère pas la progression automatique (géré par `ORACLE.refresh.sh`)

### Usage

```bash
cd Astroport.ONE/tools
./oracle_init_permit_definitions.sh
```

### Menu

```
1. Add permit definition (from template) - OFFICIAL ONLY
2. Edit permit definition (from NOSTR)
3. Delete permit definition (from NOSTR)
4. List all permit definitions (NOSTR)
5. List template definitions (JSON)
6. Exit
```

### Avertissements

Le script affiche clairement :
- ⚠️ Ce script gère les **permits officiels uniquement**
- Pour les professions auto-proclamées (WoTx2), utiliser `/wotx2`
- Si tentative de créer un WoTx2 via ce script → avertissement et redirection

---

## 3. oracle.WoT_PERMIT.init.sh

**Localisation** : `Astroport.ONE/tools/oracle.WoT_PERMIT.init.sh`  
**Type** : Script de bootstrap  
**Exécution** : Manuelle (quand nécessaire)  
**Version** : 2.0 - À mettre à jour pour clarifier le scope

### Description

Script de **bootstrap pour permits officiels uniquement**. Résout le problème de l'œuf et la poule : comment obtenir les premiers détenteurs d'un permit si personne ne peut attester ?

**Fonctionnalités** :
1. **Liste les permits sans détenteurs** :
   - Trouve tous les permits (30500) sans credentials (30503)
   - Affiche le nombre minimum de membres requis

2. **Sélection interactive** :
   - Permet de choisir un permit à initialiser
   - Demande les emails MULTIPASS des membres initiaux
   - Minimum : `min_attestations + 1` membres

3. **Création automatique du "Block 0"** :
   - Crée des demandes 30501 pour chaque membre
   - Crée des attestations croisées 30502 (chaque membre atteste tous les autres)
   - Attend l'émission automatique des credentials 30503

4. **Authentification NIP-42** :
   - Authentifie chaque membre avant chaque opération
   - Utilise `nostr_send_note.py` avec kind 22242

### Alignement v3.0

⚠️ **À clarifier** :
- Ce script est **uniquement pour permits officiels**
- Les professions auto-proclamées (WoTx2) **ne nécessitent pas de bootstrap**
- WoTx2 démarre avec 1 signature (pas de problème d'œuf et poule)

✅ **Fonctionnel** :
- Fonctionne correctement pour permits officiels
- Authentification NIP-42 implémentée
- Gestion des erreurs correcte

### Usage

```bash
# Mode interactif
cd Astroport.ONE/tools
./oracle.WoT_PERMIT.init.sh

# Mode direct
./oracle.WoT_PERMIT.init.sh PERMIT_ORE_V1 alice@example.com bob@example.com carol@example.com
```

### Exemple

Pour `PERMIT_ORE_V1` (5 signatures requises) :
- Minimum 6 membres MULTIPASS
- Chaque membre reçoit 5 attestations (de tous les autres)
- Tous obtiennent le credential simultanément

### Notes Importantes

- ⚠️ **Ne s'applique PAS aux professions auto-proclamées (WoTx2)**
- WoTx2 démarre directement avec 1 signature (pas de bootstrap requis)
- Ce script est uniquement pour les permits officiels qui nécessitent un bootstrap initial

---

## 4. oracle_test_permit_system.sh

**Localisation** : `Astroport.ONE/tools/oracle_test_permit_system.sh`  
**Type** : Suite de tests  
**Exécution** : Manuelle (développement/QA)  
**Version** : 2.0 - À mettre à jour pour tester WoTx2

### Description

Suite de tests complète pour le système Oracle. Teste l'ensemble du workflow :

**Tests inclus** :
1. **Test 1** : Récupération des définitions de permits (30500)
2. **Test 2** : Demande de permit (30501)
3. **Test 3** : Attestations (30502)
4. **Test 4** : Vérification du statut
5. **Test 5** : Listing des permits
6. **Test 6** : Récupération de credential (30503)
7. **Test 7** : Scripts helper et interface web
8. **Test 8** : Virement PERMIT (blockchain)
9. **Test 9** : Oracle system (oracle_system.py)
10. **Test 10** : Événements NOSTR (strfry)
11. **Test 11** : API NOSTR fetch

### Alignement v3.0

⚠️ **À améliorer** :
- Ne teste pas spécifiquement les professions auto-proclamées (WoTx2)
- Ne teste pas la progression automatique X1 → X2 → ...
- Ne teste pas l'authentification NIP-42 pour la création de permits
- Ne teste pas les labels dynamiques (Expert, Maître, etc.)

✅ **Fonctionnel** :
- Tests de base fonctionnels
- Tests NOSTR intégrés
- Tests API complets

### Usage

```bash
# Menu interactif
cd Astroport.ONE/tools
./oracle_test_permit_system.sh

# Tous les tests
./oracle_test_permit_system.sh --all
```

### Tests Manquants pour v3.0

Les tests suivants devraient être ajoutés :
- [ ] Test création profession auto-proclamée via `/wotx2`
- [ ] Test progression automatique X1 → X2
- [ ] Test authentification NIP-42 avant création permit
- [ ] Test labels dynamiques selon le niveau
- [ ] Test progression illimitée (X144+)

---

## 🔄 Alignement Global avec v3.0

### ✅ Scripts Alignés

| Script | Alignement | Notes |
|--------|-----------|-------|
| `ORACLE.refresh.sh` | ✅ 100% | Progression automatique, NIP-42, labels dynamiques |
| `oracle_init_permit_definitions.sh` | ✅ 100% | Avertissements WoTx2, distinction officiels/WoTx2 |

### ⚠️ Scripts à Améliorer

| Script | Alignement | Améliorations Nécessaires |
|--------|-----------|---------------------------|
| `oracle.WoT_PERMIT.init.sh` | ⚠️ 80% | Clarifier que WoTx2 ne nécessite pas de bootstrap |
| `oracle_test_permit_system.sh` | ⚠️ 70% | Ajouter tests WoTx2, progression automatique, NIP-42 |

---

## 📝 Recommandations

### Pour oracle.WoT_PERMIT.init.sh

1. **Ajouter un avertissement** au début du script :
   ```bash
   echo "⚠️  NOTE: This script is for OFFICIAL PERMITS only"
   echo "   WoTx2 auto-proclaimed professions do NOT require bootstrap"
   echo "   WoTx2 starts with 1 signature (no chicken-and-egg problem)"
   ```

2. **Détecter les professions auto-proclamées** :
   - Si un permit `PERMIT_PROFESSION_*_X1` est sélectionné → avertir
   - Rediriger vers `/wotx2` pour créer des demandes

### Pour oracle_test_permit_system.sh

1. **Ajouter des tests WoTx2** :
   - Test création profession auto-proclamée
   - Test progression X1 → X2
   - Test authentification NIP-42
   - Test labels dynamiques

2. **Mettre à jour la documentation** :
   - Mentionner les tests WoTx2
   - Expliquer la différence tests officiels vs WoTx2

---

## 🔗 Liens

- **Documentation complète** : `docs/ORACLE.doc.md`
- **Scripts** : `tools/oracle_*.sh`, `RUNTIME/ORACLE.refresh.sh`
- **Interface web** : `/oracle` (permits officiels), `/wotx2` (professions auto-proclamées)

---

**Dernière mise à jour** : $(date +"%Y-%m-%d")  
**Version système** : 3.0 - 100% Dynamique

