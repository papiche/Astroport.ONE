# Système de Suivi TODO - Guide d'Utilisation

## 📋 Vue d'Ensemble

Le système de suivi TODO permet de consigner les avancées quotidiennes sur les différents systèmes de UPlanet :

- **ECONOMY** : Système économique ẐEN
- **DID** : Identité décentralisée (MULTIPASS + UMAP)
- **ORE UMAP** : Obligations Réelles Environnementales
- **ORACLE WoTx2** : Système de permits dynamiques
- **Nostr Tube** : Plateforme vidéo décentralisée
- **Cookie & N8N** : Système de workflow automation

---

## 📁 Structure des Fichiers

### Fichiers Principaux

- **`TODO.md`** : Fichier principal de suivi (mis à jour manuellement)
- **`TODO.today.md`** : Résumé automatique des modifications du jour (généré par `todo.sh`)
- **`todo.sh`** : Script d'automatisation pour générer `TODO.today.md`

### Fichiers par Système

Chaque système peut avoir :

1. **`{SYSTEM}.todo.md`** : Liste des tâches à faire pour ce système
   - Exemple : `docs/N8N.todo.md`
   - Contient les tâches complétées, en cours, et à faire

2. **`{SYSTEM}.100%.md`** : Attestation de concordance complète
   - Exemple : `docs/ECONOMY.100%.md`
   - Indique que le système est **100% conforme** entre spec, implémentation et résultat
   - **Aucun TODO nécessaire** pour ce système

---

## 🚀 Utilisation

### Génération Automatique du TODO Quotidien

```bash
# Depuis la racine du projet
./todo.sh
```

Le script :
1. ✅ Capture les modifications Git des dernières 24h
2. ✅ Analyse les changements par système
3. ✅ Utilise `question.py` (Ollama) pour générer un résumé intelligent
4. ✅ Crée `TODO.today.md` avec les modifications détectées

### Mise à Jour Manuelle de TODO.md

Après avoir généré `TODO.today.md` :

1. **Ouvrir** `TODO.today.md` pour voir le résumé automatique
2. **Analyser** les modifications détectées
3. **Intégrer** les informations pertinentes dans `TODO.md` :
   - Ajouter les avancées dans la section "Avancées Quotidiennes"
   - Mettre à jour les statuts des systèmes
   - Noter les blocages éventuels

### Exemple de Workflow

```bash
# 1. Fin de session de développement
./todo.sh

# 2. Ouvrir TODO.today.md
cat TODO.today.md

# 3. Éditer TODO.md pour intégrer les informations
vim TODO.md

# 4. Commit des modifications
git add TODO.md TODO.today.md
git commit -m "docs: mise à jour TODO quotidien"
```

---

## 📊 Statuts des Systèmes

### 🟢 100% (Concordance Complète)

Système avec fichier `.100%.md` :
- ✅ Spécification complète
- ✅ Implémentation complète
- ✅ Résultat validé
- ✅ Aucun TODO nécessaire

**Exemple** : `docs/ECONOMY.100%.md`

### 🟡 En Cours (Développement Actif)

Système avec fichier `.todo.md` :
- 📝 Tâches complétées
- 🔄 Tâches en cours
- ❌ Tâches à faire

**Exemple** : `docs/N8N.todo.md`

### 🔴 Blocage (Problème Identifié)

Système avec problème :
- ⚠️ Blocage documenté dans `TODO.md`
- 🔧 Solution en cours d'identification

---

## 🔧 Configuration du Script `todo.sh`

Le script `todo.sh` utilise :

- **Git** : Pour détecter les modifications
- **question.py** : Pour générer un résumé intelligent via Ollama
- **Modèle IA** : `gemma3:latest` (configurable)

### Personnalisation

Pour changer le modèle IA utilisé :

```bash
# Éditer todo.sh, ligne ~100
local ai_summary=$(echo "$prompt" | python3 "$QUESTION_PY" --model "votre-modele" 2>/dev/null)
```

---

## 📝 Format des Fichiers

### TODO.md

```markdown
## 📅 Avancées Quotidiennes

### YYYY-MM-DD

#### Système X
- ✅ Tâche complétée
- 🔄 Tâche en cours
- ❌ Blocage identifié
```

### {SYSTEM}.todo.md

```markdown
## ✅ Completed
- [x] Tâche 1
- [x] Tâche 2

## 🚧 In Progress
- [ ] Tâche 3

## ❌ Not Started
- [ ] Tâche 4
```

### {SYSTEM}.100%.md

```markdown
# {SYSTEM} System - Concordance 100%

**Date de validation** : YYYY-MM-DD  
**Statut** : ✅ **CONCORDANCE COMPLÈTE**

## ✅ Validation Complète
- [x] Spécification complète
- [x] Implémentation complète
- [x] Résultat validé
```

---

## 🔗 Liens Utiles

- [TODO Principal](../TODO.md)
- [Documentation Principale](../DOCUMENTATION.md)
- [README Principal](../README.md)

---

**Note** : Ce système de suivi est conçu pour être **simple et efficace**. Utilisez `todo.sh` quotidiennement pour maintenir une trace des avancées.


## 📋 Vue d'Ensemble

Le système de suivi TODO permet de consigner les avancées quotidiennes sur les différents systèmes de UPlanet :

- **ECONOMY** : Système économique ẐEN
- **DID** : Identité décentralisée (MULTIPASS + UMAP)
- **ORE UMAP** : Obligations Réelles Environnementales
- **ORACLE WoTx2** : Système de permits dynamiques
- **Nostr Tube** : Plateforme vidéo décentralisée
- **Cookie & N8N** : Système de workflow automation

---

## 📁 Structure des Fichiers

### Fichiers Principaux

- **`TODO.md`** : Fichier principal de suivi (mis à jour manuellement)
- **`TODO.today.md`** : Résumé automatique des modifications du jour (généré par `todo.sh`)
- **`todo.sh`** : Script d'automatisation pour générer `TODO.today.md`

### Fichiers par Système

Chaque système peut avoir :

1. **`{SYSTEM}.todo.md`** : Liste des tâches à faire pour ce système
   - Exemple : `docs/N8N.todo.md`
   - Contient les tâches complétées, en cours, et à faire

2. **`{SYSTEM}.100%.md`** : Attestation de concordance complète
   - Exemple : `docs/ECONOMY.100%.md`
   - Indique que le système est **100% conforme** entre spec, implémentation et résultat
   - **Aucun TODO nécessaire** pour ce système

---

## 🚀 Utilisation

### Génération Automatique du TODO Quotidien

```bash
# Depuis la racine du projet
./todo.sh
```

Le script :
1. ✅ Capture les modifications Git des dernières 24h
2. ✅ Analyse les changements par système
3. ✅ Utilise `question.py` (Ollama) pour générer un résumé intelligent
4. ✅ Crée `TODO.today.md` avec les modifications détectées

### Mise à Jour Manuelle de TODO.md

Après avoir généré `TODO.today.md` :

1. **Ouvrir** `TODO.today.md` pour voir le résumé automatique
2. **Analyser** les modifications détectées
3. **Intégrer** les informations pertinentes dans `TODO.md` :
   - Ajouter les avancées dans la section "Avancées Quotidiennes"
   - Mettre à jour les statuts des systèmes
   - Noter les blocages éventuels

### Exemple de Workflow

```bash
# 1. Fin de session de développement
./todo.sh

# 2. Ouvrir TODO.today.md
cat TODO.today.md

# 3. Éditer TODO.md pour intégrer les informations
vim TODO.md

# 4. Commit des modifications
git add TODO.md TODO.today.md
git commit -m "docs: mise à jour TODO quotidien"
```

---

## 📊 Statuts des Systèmes

### 🟢 100% (Concordance Complète)

Système avec fichier `.100%.md` :
- ✅ Spécification complète
- ✅ Implémentation complète
- ✅ Résultat validé
- ✅ Aucun TODO nécessaire

**Exemple** : `docs/ECONOMY.100%.md`

### 🟡 En Cours (Développement Actif)

Système avec fichier `.todo.md` :
- 📝 Tâches complétées
- 🔄 Tâches en cours
- ❌ Tâches à faire

**Exemple** : `docs/N8N.todo.md`

### 🔴 Blocage (Problème Identifié)

Système avec problème :
- ⚠️ Blocage documenté dans `TODO.md`
- 🔧 Solution en cours d'identification

---

## 🔧 Configuration du Script `todo.sh`

Le script `todo.sh` utilise :

- **Git** : Pour détecter les modifications
- **question.py** : Pour générer un résumé intelligent via Ollama
- **Modèle IA** : `gemma3:latest` (configurable)

### Personnalisation

Pour changer le modèle IA utilisé :

```bash
# Éditer todo.sh, ligne ~100
local ai_summary=$(echo "$prompt" | python3 "$QUESTION_PY" --model "votre-modele" 2>/dev/null)
```

---

## 📝 Format des Fichiers

### TODO.md

```markdown
## 📅 Avancées Quotidiennes

### YYYY-MM-DD

#### Système X
- ✅ Tâche complétée
- 🔄 Tâche en cours
- ❌ Blocage identifié
```

### {SYSTEM}.todo.md

```markdown
## ✅ Completed
- [x] Tâche 1
- [x] Tâche 2

## 🚧 In Progress
- [ ] Tâche 3

## ❌ Not Started
- [ ] Tâche 4
```

### {SYSTEM}.100%.md

```markdown
# {SYSTEM} System - Concordance 100%

**Date de validation** : YYYY-MM-DD  
**Statut** : ✅ **CONCORDANCE COMPLÈTE**

## ✅ Validation Complète
- [x] Spécification complète
- [x] Implémentation complète
- [x] Résultat validé
```

---

## 🔗 Liens Utiles

- [TODO Principal](../TODO.md)
- [Documentation Principale](../DOCUMENTATION.md)
- [README Principal](../README.md)

---

**Note** : Ce système de suivi est conçu pour être **simple et efficace**. Utilisez `todo.sh` quotidiennement pour maintenir une trace des avancées.


## 📋 Vue d'Ensemble

Le système de suivi TODO permet de consigner les avancées quotidiennes sur les différents systèmes de UPlanet :

- **ECONOMY** : Système économique ẐEN
- **DID** : Identité décentralisée (MULTIPASS + UMAP)
- **ORE UMAP** : Obligations Réelles Environnementales
- **ORACLE WoTx2** : Système de permits dynamiques
- **Nostr Tube** : Plateforme vidéo décentralisée
- **Cookie & N8N** : Système de workflow automation

---

## 📁 Structure des Fichiers

### Fichiers Principaux

- **`TODO.md`** : Fichier principal de suivi (mis à jour manuellement)
- **`TODO.today.md`** : Résumé automatique des modifications du jour (généré par `todo.sh`)
- **`todo.sh`** : Script d'automatisation pour générer `TODO.today.md`

### Fichiers par Système

Chaque système peut avoir :

1. **`{SYSTEM}.todo.md`** : Liste des tâches à faire pour ce système
   - Exemple : `docs/N8N.todo.md`
   - Contient les tâches complétées, en cours, et à faire

2. **`{SYSTEM}.100%.md`** : Attestation de concordance complète
   - Exemple : `docs/ECONOMY.100%.md`
   - Indique que le système est **100% conforme** entre spec, implémentation et résultat
   - **Aucun TODO nécessaire** pour ce système

---

## 🚀 Utilisation

### Génération Automatique du TODO Quotidien

```bash
# Depuis la racine du projet
./todo.sh
```

Le script :
1. ✅ Capture les modifications Git des dernières 24h
2. ✅ Analyse les changements par système
3. ✅ Utilise `question.py` (Ollama) pour générer un résumé intelligent
4. ✅ Crée `TODO.today.md` avec les modifications détectées

### Mise à Jour Manuelle de TODO.md

Après avoir généré `TODO.today.md` :

1. **Ouvrir** `TODO.today.md` pour voir le résumé automatique
2. **Analyser** les modifications détectées
3. **Intégrer** les informations pertinentes dans `TODO.md` :
   - Ajouter les avancées dans la section "Avancées Quotidiennes"
   - Mettre à jour les statuts des systèmes
   - Noter les blocages éventuels

### Exemple de Workflow

```bash
# 1. Fin de session de développement
./todo.sh

# 2. Ouvrir TODO.today.md
cat TODO.today.md

# 3. Éditer TODO.md pour intégrer les informations
vim TODO.md

# 4. Commit des modifications
git add TODO.md TODO.today.md
git commit -m "docs: mise à jour TODO quotidien"
```

---

## 📊 Statuts des Systèmes

### 🟢 100% (Concordance Complète)

Système avec fichier `.100%.md` :
- ✅ Spécification complète
- ✅ Implémentation complète
- ✅ Résultat validé
- ✅ Aucun TODO nécessaire

**Exemple** : `docs/ECONOMY.100%.md`

### 🟡 En Cours (Développement Actif)

Système avec fichier `.todo.md` :
- 📝 Tâches complétées
- 🔄 Tâches en cours
- ❌ Tâches à faire

**Exemple** : `docs/N8N.todo.md`

### 🔴 Blocage (Problème Identifié)

Système avec problème :
- ⚠️ Blocage documenté dans `TODO.md`
- 🔧 Solution en cours d'identification

---

## 🔧 Configuration du Script `todo.sh`

Le script `todo.sh` utilise :

- **Git** : Pour détecter les modifications
- **question.py** : Pour générer un résumé intelligent via Ollama
- **Modèle IA** : `gemma3:latest` (configurable)

### Personnalisation

Pour changer le modèle IA utilisé :

```bash
# Éditer todo.sh, ligne ~100
local ai_summary=$(echo "$prompt" | python3 "$QUESTION_PY" --model "votre-modele" 2>/dev/null)
```

---

## 📝 Format des Fichiers

### TODO.md

```markdown
## 📅 Avancées Quotidiennes

### YYYY-MM-DD

#### Système X
- ✅ Tâche complétée
- 🔄 Tâche en cours
- ❌ Blocage identifié
```

### {SYSTEM}.todo.md

```markdown
## ✅ Completed
- [x] Tâche 1
- [x] Tâche 2

## 🚧 In Progress
- [ ] Tâche 3

## ❌ Not Started
- [ ] Tâche 4
```

### {SYSTEM}.100%.md

```markdown
# {SYSTEM} System - Concordance 100%

**Date de validation** : YYYY-MM-DD  
**Statut** : ✅ **CONCORDANCE COMPLÈTE**

## ✅ Validation Complète
- [x] Spécification complète
- [x] Implémentation complète
- [x] Résultat validé
```

---

## 🔗 Liens Utiles

- [TODO Principal](../TODO.md)
- [Documentation Principale](../DOCUMENTATION.md)
- [README Principal](../README.md)

---

**Note** : Ce système de suivi est conçu pour être **simple et efficace**. Utilisez `todo.sh` quotidiennement pour maintenir une trace des avancées.

