# 📝 Journal N² Personnel - Documentation

SPAMMY SERVICE !! IT IS NOT ACTIVATED BY DEFAULT ... 
BETTER JOURNAL ARE MADE BY GEO KEYS

## Vue d'ensemble

Le système de journaux N² personnel génère automatiquement des résumés de l'activité du réseau social NOSTR pour chaque MULTIPASS. Ces journaux sont **individuels et personnalisés** selon le réseau de chaque utilisateur (N1 + N²).

## 🗓️ Quand sont-ils créés ?

### Condition de déclenchement
- **Uniquement lors du `daily_update`** : Le journal est généré uniquement lorsque le refresh quotidien est déclenché (`REFRESH_REASON == "daily_update"`)
- **Heure programmée** : Chaque MULTIPASS a une heure de refresh aléatoire entre 00:01 et 20:11, stockée dans `~/.zen/game/nostr/${PLAYER}/.refresh_time`

### Détermination du type de journal

Le type de journal est déterminé automatiquement selon l'ancienneté du MULTIPASS (jours depuis la création) :

| Type | Condition | Période | Fréquence |
|------|-----------|---------|-----------|
| **Daily** | Par défaut (tous les jours sauf exceptions) | 24 heures | Tous les jours |
| **Weekly** | `days_since_birth % 7 == 0` ET `days_since_birth >= 7` | 7 jours | Toutes les semaines |
| **Monthly** | `days_since_birth % 28 == 0` ET `days_since_birth >= 28` | 28 jours | Tous les mois |
| **Yearly** | `days_since_birth % 365 == 0` ET `days_since_birth >= 365` | 365 jours | Tous les ans |

**Note** : Les priorités sont vérifiées dans cet ordre : Yearly > Monthly > Weekly > Daily

## 📊 Structure du réseau N²

### Construction du réseau

1. **Amis directs (N1)** :
   - Récupérés via `nostr_get_N1.sh ${HEX}`
   - Liste des utilisateurs suivis directement par le MULTIPASS

2. **Amis des amis (N²)** :
   - Pour chaque ami N1, récupération de leurs propres amis via `nostr_get_N1.sh ${friend_hex}`
   - Tous ajoutés à la liste étendue

3. **Déduplication** :
   - Les doublons sont supprimés : `sort -u`
   - Résultat : liste unique d'amis (N1 + N²)

**Log** : `Personal N² journal: ${#friends_list[@]} total friends (N1 + N²) for ${PLAYER}'s individual network`

## 🔍 Sources de données par type de journal

### 📝 Daily (Quotidien)

**Source** : Messages bruts (kind 1) des amis du réseau N²

**Requête** :
```bash
nostr_get_events.sh \
    --kind 1 \
    --author "${friends_comma}" \  # Liste séparée par virgules de tous les amis N1+N²
    --since "${since_timestamp}" \  # 24 heures avant
    --limit 500
```

**Traitement** :
- Extraction des champs : `id`, `content`, `created_at`, `author`, `tags`
- Ajout de métadonnées : `application`, `latitude`, `longitude` (si disponibles)
- Format : Un message par ligne avec date, auteur (nprofile), localisation, contenu

### 📊 Weekly (Hebdomadaire)

**Source** : Résumés quotidiens publiés précédemment (kind 30023 - format blog)

**Requête** :
```bash
nostr_get_events.sh \
    --kind 30023 \
    --author "${HEX}" \  # Le MULTIPASS lui-même
    --tag-t "SummaryType:Daily" \
    --since "${since_timestamp}" \  # 7 jours avant
    --limit 100
```

**Stratégie** : Plus efficace que de récupérer tous les messages bruts de 7 jours
- **Lit les journaux quotidiens (format blog)** publiés dans les 7 derniers jours
- Les agrège dans le résumé hebdomadaire
- Chaque daily journal est un article kind 30023 avec tag `SummaryType:Daily`

**Traitement** :
- Lecture des résumés quotidiens existants (format blog kind 30023)
- Format : Un résumé quotidien par section avec date et contenu
- Chaque daily journal est traité comme un article complet

### 📅 Monthly (Mensuel)

**Source** : Résumés hebdomadaires publiés précédemment (kind 30023 - format blog)

**Requête** :
```bash
nostr_get_events.sh \
    --kind 30023 \
    --author "${HEX}" \
    --tag-t "SummaryType:Weekly" \
    --since "${since_timestamp}" \  # 28 jours avant (4 semaines)
    --limit 100
```

**Stratégie** : Encore plus efficace
- **Lit les journaux hebdomadaires (format blog) des 4 dernières semaines** (28 jours)
- Récupère les ~4 résumés hebdomadaires déjà publiés
- Les agrège dans le résumé mensuel
- Chaque weekly journal est un article kind 30023 avec tag `SummaryType:Weekly`

**Traitement** :
- Lecture des résumés hebdomadaires existants (format blog kind 30023)
- Format : Un résumé hebdomadaire par section
- Chaque weekly journal est traité comme un article complet

### 🗓️ Yearly (Annuel)

**Source** : Résumés mensuels publiés précédemment (kind 30023)

**Requête** :
```bash
nostr_get_events.sh \
    --kind 30023 \
    --author "${HEX}" \
    --tag-t "SummaryType:Monthly" \
    --since "${since_timestamp}" \  # 365 jours avant
    --limit 100
```

**Stratégie** : La plus efficace
- Récupère les ~12 résumés mensuels déjà publiés
- Les agrège dans le résumé annuel

**Traitement** :
- Lecture des résumés mensuels existants
- Format : Un résumé mensuel par section

## 🤖 Résumé IA (si nécessaire)

### Condition d'activation

Le résumé IA est généré automatiquement si le nombre d'éléments dépasse un seuil :

| Type | Seuil | Signification |
|------|-------|---------------|
| Daily | 5 messages | Plus de 5 messages à résumer |
| Weekly | 5 résumés | Plus de 5 résumés quotidiens |
| Monthly | 3 résumés | Plus de 3 résumés hebdomadaires |
| Yearly | 8 résumés | Plus de 8 résumés mensuels |

### Génération IA

**Modèle** : `gemma3:12b` (via `question.py`)

**Prompts personnalisés** par type :

1. **Daily** : Crée un "RECONNECTION SUMMARY" avec :
   - Résumé exécutif de bienvenue
   - Section "What You Missed"
   - Regroupement par auteur
   - Highlights clés
   - Activité réseau
   - Langue du contenu original préservée
   - Insights réseau N²

2. **Weekly** : Crée un "WEEKLY RECONNECTION SUMMARY" avec :
   - Vue d'ensemble hebdomadaire
   - Analyse des tendances des résumés quotidiens
   - "Week in Review"
   - Évolution temporelle

3. **Monthly** : Crée un "MONTHLY RECONNECTION SUMMARY" avec :
   - Vue d'ensemble mensuelle
   - Analyse des tendances des résumés hebdomadaires
   - "Month in Review"
   - Évolution à long terme
   - Jalons importants

4. **Yearly** : Crée un "YEARLY RECONNECTION SUMMARY" avec :
   - Vue d'ensemble annuelle
   - Analyse des tendances des résumés mensuels
   - "Year in Review"
   - Tendances saisonnières
   - Évolution annuelle

**Remplacé** : Si l'IA est activée, le fichier markdown brut est remplacé par le résumé IA.

## 📄 Format du fichier journal

### En-tête (Markdown)

```markdown
# 📝 Daily Friends Activity Summary - 2024-01-15
**Date**: 2024-01-15
**MULTIPASS**: user@example.com
**NProfile**: nostr:nprofile1...
**Period**: 24 hours
**Type**: Personal N² Journal (Daily)
**Network**: 42 friends (N1 + N²)
**Location**: 43.6047, 1.4442
**UMAP Zone**: 43.6047_1.4442
```

### Corps (selon le type)

**Daily** :
```markdown
### 📝 2024-01-15 14:30
**Author**: nostr:nprofile1...
**App**: NostrTube
**Location**: 43.6047, 1.4442

Contenu du message...
```

**Weekly/Monthly/Yearly** :
```markdown
### 📅 2024-01-15
**Daily Summary** (ou Weekly/Monthly)

[Contenu du résumé précédent]
---
```

## 📤 Publication NOSTR

### Format de publication

- **Kind** : `30023` (NIP-23 - Article)
- **Tags NIP-23** :
  - `d` : Identifiant unique (`personal-n2-journal-${PLAYER}-${summary_type}-${TODATE}`)
  - `title` : Titre du journal
  - `summary` : Premiers 200 caractères
  - `published_at` : Timestamp Unix
  - `t` : Hashtags multiples :
    - `PersonalN2Journal`
    - `N2Network`
    - Type (`Daily`, `Weekly`, `Monthly`, `Yearly`)
    - `UPlanet`
    - `SummaryType:${type}` (pour les requêtes futures)

### Validation

1. **NIP-23 compliance** : Validation via `validate_nip23_event()`
2. **Longueur** : Tronqué à 100k caractères si nécessaire
3. **Clé** : Signé avec `~/.zen/game/nostr/${PLAYER}/.secret.nostr`

### Relay

- Publié sur `$myRELAY` (relay NOSTR configuré)
- Script : `nostr_send_note.py --kind 30023`

## 📈 Métriques et logs

### Compteurs globaux

- `DAILY_SUMMARIES` : Nombre de résumés quotidiens
- `WEEKLY_SUMMARIES` : Nombre de résumés hebdomadaires
- `MONTHLY_SUMMARIES` : Nombre de résumés mensuels
- `YEARLY_SUMMARIES` : Nombre de résumés annuels
- `FRIENDS_SUMMARIES_PUBLISHED` : Total publié
- `USOCIETY_N2_EXPANSIONS` : Expansions réseau N²

### Logs de performance

- Durée des requêtes `nostr_get_events.sh`
- Durée de génération IA
- Nombre de messages/résumés récupérés
- Temps de publication NOSTR

## 🔄 Hiérarchie et dépendances

```
Daily (messages bruts kind 1 du réseau N²)
  ↓ publié comme kind 30023 (format blog) avec tag SummaryType:Daily
Weekly (lit les daily journals des 7 derniers jours)
  ↓ publié comme kind 30023 (format blog) avec tag SummaryType:Weekly
Monthly (lit les weekly journals des 4 dernières semaines - 28 jours)
  ↓ publié comme kind 30023 (format blog) avec tag SummaryType:Monthly
Yearly (lit les monthly journals des 12 derniers mois - 365 jours)
  ↓ publié comme kind 30023 (format blog) avec tag SummaryType:Yearly
```

**Avantage** : Chaque niveau réutilise les données déjà agrégées (format blog kind 30023), évitant de retraiter des milliers de messages bruts.

**Clarification** :
- **Daily** : Collecte les messages kind 1 du réseau N² (N1 + N² friends)
- **Weekly** : Lit les daily journals (format blog) publiés dans les 7 derniers jours
- **Monthly** : Lit les weekly journals (format blog) publiés dans les 4 dernières semaines (28 jours)
- **Yearly** : Lit les monthly journals (format blog) publiés dans les 12 derniers mois (365 jours)

## 🎯 Points clés

1. **Personnalisé** : Chaque MULTIPASS a son propre journal basé sur son réseau unique (N1 + N²)
2. **Efficace** : Les résumés hebdomadaires/mensuels/annuels réutilisent les résumés précédents
3. **Scalable** : L'IA est activée automatiquement pour les grands volumes
4. **Décentralisé** : Publié sur NOSTR (kind 30023), accessible à tous
5. **Persistant** : Les journaux restent disponibles pour les résumés futurs
6. **Conforme** : Respecte NIP-23 pour la compatibilité avec les clients NOSTR

## 📝 Notes techniques

- Les fichiers temporaires sont créés dans `~/.zen/tmp/${MOATS}/friends_summary_${PLAYER}/`
- Nettoyage automatique après publication
- Les erreurs de publication sont loggées mais n'interrompent pas le processus
- Les journaux vides (aucun ami ou aucun message) ne sont pas publiés
- **Vérification de doublons** : Avant publication, vérifie si un journal avec le même `d_tag` existe déjà pour éviter les doublons

## 🔄 Comparaison avec Autres Systèmes

### MULTIPASS Journals (NOSTRCARD)
- Hiérarchie : Daily → Weekly → Monthly → Yearly
- Source Daily : Messages kind 1 du réseau N²
- Source Weekly+ : Lit les journaux précédents (format blog kind 30023)
- Personnalisé : Basé sur le réseau N² unique de chaque MULTIPASS

### UMAP Journals (NOSTR.UMAP)
- Pas de hiérarchie daily/weekly/monthly
- Source : Messages des amis de la zone géographique UMAP
- Filtre par likes : SECTOR (≥3 likes), REGION (≥12 likes)
- Géographique : Basé sur la localisation (0.01° pour UMAP)

### Documents Collaboratifs (Commons)
- Kind 30023 avec tag `collaborative`
- Signé par l'UMAP (collectif) et non par l'individu
- Validation par vote communautaire (kind 7)
- Édition WYSIWYG avec Milkdown
- Système de gouvernance (quorum, majorité, fork)
- Voir : `COLLABORATIVE_COMMONS_SYSTEM.md`

## 🔗 Liens Utiles

- **Interface PlantNet** : `UPlanet/earth/plantnet.html`
- **Commons Editor** : `UPlanet/earth/collaborative-editor.html`
- **Système ORE** : `Astroport.ONE/docs/ORE_SYSTEM.md`
- **Système PlantNet** : `Astroport.ONE/docs/PLANTNET_SYSTEM.md`
- **Documents Collaboratifs** : `Astroport.ONE/docs/COLLABORATIVE_COMMONS_SYSTEM.md`

