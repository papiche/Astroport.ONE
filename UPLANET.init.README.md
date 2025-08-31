# UPLANET.INIT.SH - Initialisation des Portefeuilles Coopératifs

## 📋 Description

`UPLANET.init.sh` est un script d'initialisation automatique des portefeuilles coopératifs de l'écosystème UPlanet ẐEN. Il vérifie l'état des portefeuilles système et les initialise si nécessaire en transférant 1 Ğ1 depuis un portefeuille source.

## 🎯 Objectif

Assurer que tous les portefeuilles coopératifs disposent d'un solde minimum pour fonctionner correctement dans l'écosystème UPlanet ẐEN, en respectant les contraintes de solde disponibles.

## 🏛️ Portefeuilles Coopératifs Gérés

Le script vérifie et initialise les portefeuilles suivants :

| Portefeuille | Fichier Dunikey | Description |
|---------------|------------------|-------------|
| `UPLANETNAME` | `uplanet.dunikey` | Compte d'exploitation principal |
| `UPLANETNAME.SOCIETY` | `uplanet.SOCIETY.dunikey` | Capital social et adhésions |
| `UPLANETNAME.CASH` | `uplanet.CASH.dunikey` | Trésorerie (33.33% du surplus) |
| `UPLANETNAME.RND` | `uplanet.RnD.dunikey` | Recherche & Développement (33.33% du surplus) |
| `UPLANETNAME.ASSETS` | `uplanet.ASSETS.dunikey` | Actifs et investissements (33.34% du surplus) |

## 🔧 Fonctionnement

### 1. Vérification des Prérequis
- Outils requis : `silkaj`, `jq`, `bc`, `G1check.sh`
- Portefeuille source disponible avec solde suffisant

### 2. Détection du Portefeuille Source
Le script recherche automatiquement un portefeuille source dans l'ordre suivant :
1. `~/.zen/game/uplanet.G1.dunikey` (portefeuille de réserve principal)
2. `~/.zen/game/uplanet.g1.dunikey`
3. `~/.zen/game/secret.G1.dunikey`
4. `~/.zen/game/secret.dunikey`

**Note** : `uplanet.G1.dunikey` est le portefeuille de réserve et de stabilité de l'écosystème UPlanet, conçu spécifiquement pour les transactions primaires et l'émission de Ẑen. Il est donc prioritaire pour l'initialisation des portefeuilles coopératifs.

### 3. Calcul de la Capacité d'Initialisation
- **Solde minimum** : 1 Ğ1 requis pour commencer
- **Limite maximale** : 5 portefeuilles (1 Ğ1 chacun)
- **Initialisation partielle** : Si le solde est insuffisant, le script initialise le maximum possible

### 4. Vérification des Portefeuilles
- Utilise `G1check.sh` pour vérifier les soldes
- Identifie les portefeuilles vides (< 0.01 Ğ1)
- Calcule le montant total requis

### 5. Initialisation
- Transfère 1 Ğ1 vers chaque portefeuille vide
- Attend la confirmation blockchain entre chaque transaction
- Limite le nombre de portefeuilles initialisés selon le solde disponible

## 📖 Utilisation

### Options Disponibles

```bash
./UPLANET.init.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--dry-run` | Mode simulation (aucune transaction) |
| `--force` | Initialisation sans confirmation |
| `--help` | Affiche l'aide |

### Exemples d'Utilisation

#### Mode Simulation (Recommandé)
```bash
./UPLANET.init.sh --dry-run
```
Affiche ce qui serait fait sans effectuer de transactions.

#### Initialisation Complète
```bash
./UPLANET.init.sh
```
Lance l'initialisation avec confirmation interactive.

#### Initialisation Forcée
```bash
./UPLANET.init.sh --force
```
Lance l'initialisation sans demander de confirmation.

## 🔍 Mode Simulation

Le mode `--dry-run` permet de :
- Vérifier l'état actuel des portefeuilles
- Identifier les portefeuilles nécessitant une initialisation
- Calculer le montant total requis
- Simuler le processus sans risque

## ⚠️ Limitations et Contraintes

### Solde Minimum
- **Requis** : 1 Ğ1 minimum pour commencer
- **Recommandé** : 5 Ğ1 pour initialiser tous les portefeuilles

### Initialisation Partielle
Si le solde est insuffisant :
- Le script initialise le maximum possible
- Affiche un avertissement d'initialisation partielle
- Permet de compléter l'initialisation ultérieurement

### Sécurité
- Vérification de l'existence des fichiers dunikey
- Validation des clés publiques
- Confirmation interactive (sauf avec `--force`)

## 📊 Sortie et Rapports

### Informations Affichées
- **État des prérequis** : Outils disponibles
- **Portefeuille source** : Fichier et solde
- **Portefeuilles coopératifs** : Statut et soldes
- **Plan d'initialisation** : Nombre et montants
- **Résumé final** : Succès et échecs

### Codes de Sortie
- **0** : Succès
- **1** : Erreur (prérequis, solde insuffisant, etc.)

## 🚀 Cas d'Usage Typiques

### 1. Première Installation
```bash
# Vérifier l'état initial
./UPLANET.init.sh --dry-run

# Initialiser si nécessaire
./UPLANET.init.sh
```

### 2. Maintenance Régulière
```bash
# Vérifier périodiquement
./UPLANET.init.sh --dry-run

# Réinitialiser si des portefeuilles sont vides
./UPLANET.init.sh
```

### 3. Récupération Post-Erreur
```bash
# Identifier les problèmes
./UPLANET.init.sh --dry-run

# Forcer la réinitialisation
./UPLANET.init.sh --force
```

## 🔗 Intégration avec l'Écosystème

### Scripts Associés
- **`UPLANET.official.sh`** : Gestion des transferts officiels
- **`ZEN.COOPERATIVE.3x1-3.sh`** : Allocation hebdomadaire du surplus (utilise les mêmes fichiers dunikey)
- **`zen.sh`** : Gestionnaire principal de la station ẐEN

**Note de cohérence** : Les noms des fichiers dunikey des portefeuilles coopératifs sont identiques à ceux utilisés dans `ZEN.COOPERATIVE.3x1-3.sh`, garantissant une parfaite cohérence dans l'écosystème UPlanet.

### Workflow Typique
1. **Initialisation** : `UPLANET.init.sh` (ce script)
2. **Fonctionnement** : `UPLANET.official.sh` pour les transferts
3. **Maintenance** : `ZEN.COOPERATIVE.3x1-3.sh` pour l'allocation
4. **Surveillance** : `zen.sh` pour le monitoring

## 🛠️ Dépannage

### Problèmes Courants

#### Portefeuille Source Non Trouvé
```bash
❌ Aucun portefeuille source trouvé
```
**Solution** : Créer un fichier dunikey dans `~/.zen/game/`

#### Solde Insuffisant
```bash
❌ Solde insuffisant pour l'initialisation
```
**Solution** : Alimenter le portefeuille source avec au moins 1 Ğ1

#### Erreur de Clé
```bash
❌ Erreur clé
```
**Solution** : Vérifier le format du fichier dunikey

### Vérifications
```bash
# Vérifier les fichiers dunikey
ls -la ~/.zen/game/*.dunikey

# Vérifier les soldes
./tools/G1check.sh <PUBKEY>

# Tester le mode simulation
./UPLANET.init.sh --dry-run
```

## 📝 Notes Techniques

### Format des Fichiers Dunikey
- Contiennent clé privée et publique
- Format : `priv: <clé_privée> pub: <clé_publique>`
- Permissions recommandées : 600
- **Cohérence** : Les noms des fichiers correspondent exactement à ceux utilisés dans `ZEN.COOPERATIVE.3x1-3.sh`

### Calculs de Solde
- Utilise `G1check.sh` pour la précision
- Tolérance de 0.01 Ğ1 pour les comparaisons
- Conversion automatique Ğ1 ↔ Ẑen (1:10 après transaction primale)

### Sécurité des Transactions
- Vérification blockchain avant confirmation
- Pause entre transactions pour éviter la surcharge
- Gestion des erreurs et rollback si nécessaire

## 🤝 Contribution et Support

### Signaler un Problème
- Vérifier d'abord avec `--dry-run`
- Consulter les logs d'erreur
- Tester avec un solde suffisant

### Améliorations Suggérées
- Support de multiples portefeuilles sources
- Configuration des montants d'initialisation
- Intégration avec le monitoring automatique

---

**Version** : 1.0  
**Dernière mise à jour** : $(date +%Y-%m-%d)  
**Auteur** : Équipe UPlanet ẐEN  
**Licence** : Conforme à LEGAL.md
