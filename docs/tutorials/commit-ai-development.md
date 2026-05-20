# Développer avec commit.sh --ai

> `--ai` transforme commit.sh en assistant de développement à boucle courte :  
> l'IA propose, l'humain valide ou rejette à chaque étape, avec retry possible.

---

## Philosophie : l'humain dispose, l'IA propose

À chaque décision, vous avez le choix :

| Étape | Ce que l'IA propose | Ce que vous pouvez faire |
|-------|--------------------|-----------------------------|
| Groupement | Groupes de fichiers cohérents | Ignorer et saisir votre propre sélection |
| Message commit | Titre + description conventionnelle | Ajouter une note, refaire (`r`), valider |
| Revue de code | Problèmes détectés dans le diff | Ignorer, corriger manuellement, ou lancer code_assistant |
| Pull Request | Titre + corps complet | Modifier le titre, annuler |

**Rien n'est appliqué sans votre accord explicite.**

---

## Flux de développement assisté

### Scénario : vous avez travaillé sur plusieurs features

```
Fichiers modifiés :
  [ 1] IA/UPlanet_IA_Responder.sh   +8/-1
  [ 2] _12345.sh                    +13/-8
  [ 3] commit.sh                    +336/-25
  [ 4] install.sh                   +55/-1
  [ 5] tools/diceware.sh            +1/-5
  [ 6] tools/publish_nostr_video.sh +4/-0
  [ 7] issue.sh                     +1/-1
```

L'IA suggère des groupes :
```
Groupe A [1,2]: feat(IA): amélioration Responder + écriture atomique JSON
Groupe B [3]:   feat(commit): staging interactif + revue IA
Groupe C [4,5,6]: chore(tools): intégration RTK + diceware + NOSTR relay
Groupe D [7]:   fix(issue): correction _git
```

**Vous choisissez** de committer groupe par groupe, ou de fusionner C et D, ou de créer un ordre différent.

---

## Boucle de commit avec validation humaine

### Étape 1 : Sélection

```
Sélection : 1,2
📦 Staging :
  ✓ IA/UPlanet_IA_Responder.sh
  ✓ _12345.sh
```

**Retry possible** : si vous vous trompez, tapez `r` à la validation pour dé-stager et recommencer.

### Étape 2 : Message IA

```
# COMMIT
feat(IA): amélioration UPlanet Responder et écriture atomique

## Tâches réalisées
- Mise à jour du tag BRO dans UPlanet_IA_Responder.sh
- Écriture atomique des fichiers JSON dans _12345.sh

## Fichiers clés
- IA/UPlanet_IA_Responder.sh
- _12345.sh
```

**Vous pouvez** :
- Ajouter une note contextuelle (ex: `Closes #42`)
- Taper `r` pour refaire la sélection

### Étape 3 : Revue de code IA

```
🔍 Revue de code IA (--ai)...
── Revue de code ───────────────────────────────────────────
⚠️ _12345.sh écriture atomique : fichier tmp non nettoyé si erreur
───────────────────────────────────────────────────────────

🔧 Des problèmes ont été détectés par la revue.
   Corriger avec code_assistant (analyse → correction → patch) ? [o/N] :
```

Vous répondez `o` → `code_assistant` démarre en mode **analyse** :

```
╔══════════════════════════════════════════════════════════╗
║  🤖 code_assistant : _12345.sh                         ║
╚══════════════════════════════════════════════════════════╝
   Session   : ca-_12345-20260520
   Problèmes : écriture atomique : fichier tmp non nettoyé si erreur

📦 Extraction du contexte (depth=1)...
  ✓ 3 fichier(s) — ~4200 tokens

=== ANALYSE ===
1. [ROBUSTESSE] Trap EXIT absent pour nettoyage fichier tmp
   Localisation: _12345.sh:247
   Impact: MAJEUR
...
```

**Validation humaine dans code_assistant** :
- Choix du problème à corriger (`1`, `2` ou `3`)
- Choix de la variante (`a`, `b` ou `c`)
- Visualisation du diff avant application
- `[Y/n]` pour appliquer le patch

Après correction, commit.sh redémarre automatiquement avec les fichiers corrigés pour un nouveau cycle de revue.

### Étape 4 : Validation finale

```
Valider ce commit ? [o / N / r=refaire la sélection] : o
✅ Commit créé.
✅ Push réussi.

📂 5 fichier(s) encore non commités.
Traiter le prochain lot ? [o/N] : o
```

---

## Cas d'usage avancés

### Feature complète avec PR

```bash
git checkout -b feat/mon-module
# ... développement ...
commit.sh -s --ai --pr
```

Après le dernier commit + push :
```
Créer une Pull Request pour 'feat/mon-module' → 'master' ? [o/N] : o
🤖 Génération du titre et corps de PR par l'IA...

Titre PR : feat(module): nouveau module de traitement X

## Résumé
- Implémentation du module X
- Intégration au pipeline Y

Modifier le titre ? (Entrée pour conserver) :
✅ Pull Request créée !
```

### Audit de la semaine

```bash
commit.sh --week
# → résumé IA de tous les commits de la semaine
# → copié dans le presse-papier pour le standup
```

### Correction urgente sans AI

```bash
git add fichier_critique.sh
commit.sh -s  # sans --ai = plus rapide
```

---

## Raccourcis efficaces

```bash
# Alias recommandés dans ~/.bashrc
alias cs='commit.sh -s'
alias csa='commit.sh -s --ai'
alias csap='commit.sh -s --ai --pr'
```
