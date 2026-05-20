# Prise en main — commit.sh

> Workflow de commit Git assisté par IA : staging interactif, message automatique, revue de code, Pull Request.

---

## Démarrage rapide (5 minutes)

### 1. Lancer le workflow

```bash
commit.sh -s          # staging interactif + commit IA
commit.sh -s --ai     # idem + regroupement sémantique + revue de code
commit.sh -s --ai --pr  # tout activé + Pull Request finale
```

### 2. Sélectionner les fichiers à committer

Le script affiche tous vos fichiers modifiés, **triés du plus récent au plus ancien**, avec le nombre de lignes modifiées :

```
📁 Fichiers disponibles (plus récent d'abord) :

  [ 1] 2026-05-20 14:32  commit.sh                      +45/-12    (M)
  [ 2] 2026-05-20 14:31  tools/publish_nostr_video.sh   +4/-0      (M)
  [ 3] 2026-05-20 10:15  install/setup/setup.sh         +4/-7      (M)
  [ 4] 2026-05-20 01:55  tools/diceware-wordlist.txt.bak  7775L new  (?)
```

**Légende** :
- `(M)` = fichier modifié, `(?)` = fichier non-tracké (nouveau)
- `+N/-M` = lignes ajoutées/supprimées
- `NL new` = nombre de lignes du nouveau fichier

### 3. Saisir votre sélection

| Saisie | Effet |
|--------|-------|
| `1` | Fichier numéro 1 |
| `1,3,7` | Fichiers 1, 3 et 7 |
| `1-5` | Fichiers 1 à 5 (plage) |
| `tout` ou `all` | Tous les fichiers |
| `aujourd'hui` | Fichiers modifiés aujourd'hui |
| Entrée vide | Annuler |

### 4. L'IA génère le message de commit

Format [Conventional Commits](https://www.conventionalcommits.org/) :

```
# COMMIT
feat(tools): ajout de gestion des relays dynamiques

## Tâches réalisées
- Ajout d'une condition pour intégrer $myRELAY à la liste des relais

## Fichiers clés
- tools/publish_nostr_video.sh
```

### 5. Valider ou affiner

```
Conclusion / note à ajouter ? (Entrée pour garder tel quel) :
Valider ce commit ? [o / N / r=refaire la sélection] :
```

- `o` → commit + push automatique
- `N` → annuler (fichiers restent stagés)
- `r` → dé-stage tout et recommence la sélection

### 6. Le script propose le lot suivant

S'il reste des fichiers non commités, le script propose de continuer avec le lot suivant — sans repasser par la sélection de branche ni le pull.

---

## Cycle complet en exemple

```
$ commit.sh -s --ai

📁 Fichiers disponibles :
  [ 1] IA/UPlanet_IA_Responder.sh   +8/-1  (M)
  [ 2] commit.sh                    +336/-25 (M)
  [ 3] install.sh                   +55/-1  (M)
  [ 4] tools/diceware.sh            +1/-5   (M)

🤖 Analyse sémantique (--ai)...
── Groupes suggérés ─────────────────────────────────────────
Groupe A [1]: feat(IA): amélioration IA Responder
Groupe B [2]: feat(commit): staging interactif + revue IA
Groupe C [3,4]: chore(install): mise à jour scripts

Sélection : 1

📦 Staging :
  ✓ IA/UPlanet_IA_Responder.sh

# COMMIT
feat(IA): amélioration UPlanet IA Responder

🔍 Revue de code (--ai)...
✅ Aucun problème détecté.

Valider ce commit ? [o / N / r=refaire la sélection] : o
✅ Commit créé.
✅ Push réussi.

📂 3 fichier(s) encore non commités.
Traiter le prochain lot ? [o/N] : o
...
```
