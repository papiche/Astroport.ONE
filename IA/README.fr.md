# 🤖 Système Bot IA UPlanet

Bienvenue dans le Système Bot IA UPlanet ! C'est un assistant IA puissant et multifonctionnel qui s'intègre au réseau social géolocalisé UPlanet. Le bot peut générer des images, des vidéos, de la musique, rechercher sur le web et maintenir des conversations contextuelles sur 12 emplacements de mémoire différents.

## 🌟 Fonctionnalités Principales

### 🧠 **Système de Mémoire à 12 Emplacements**
- **600 messages au total** : 12 emplacements × 50 messages chacun
- **Conversations contextuelles** : Chaque emplacement maintient un historique de conversation séparé
- **Support multi-utilisateurs** : Chaque utilisateur a ses propres emplacements de mémoire privés
- **Mémoire géolocalisée** : Les souvenirs sont liés à des emplacements et utilisateurs spécifiques
- **Contrôle d'accès** : Emplacements 1-12 réservés aux sociétaires CopyLaRadio (détenteurs de ZenCard)

### 🎨 **Capacités de Génération IA**
- **Génération d'images** avec ComfyUI
- **Création de vidéos** avec des modèles Text2Video
- **Composition musicale** avec des modèles audio IA
- **Synthèse vocale** avec plusieurs voix (Pierre, Amélie)

### 🔍 **Information et Médias**
- **Recherche web** avec Perplexica
- **Téléchargement YouTube** avec conversion de format
- **Analyse d'images** avec le modèle de vision LLaVA

## 🚀 Démarrage Rapide

### Utilisation de Base
```
#BRO Bonjour, comment allez-vous ?
#BOT Quel temps fait-il ?
```

### Gestion de la Mémoire
```
#rec #3 Notes de réunion : Discussion des objectifs Q4
#BRO #3 Quels étaient nos points d'action ?
#mem #3 Montrez-moi les notes de réunion
#reset #3 Effacer la mémoire de réunion
```

## 📋 Référence Complète des Commandes

### 🤖 **Commandes Bot Principales**

| Commande | Description | Exemple |
|----------|-------------|---------|
| `#BRO` | Activer le bot avec une question | `#BRO Quelle est la capitale de la France ?` |
| `#BOT` | Activation alternative du bot | `#BOT Racontez-moi une blague` |

### 🧠 **Gestion de la Mémoire**

| Commande | Description | Exemple | Accès |
|----------|-------------|---------|-------|
| `#rec` | Enregistrer un message en mémoire | `#rec #3 Notes de réunion` | Tous les utilisateurs |
| `#rec #N` | Enregistrer dans un emplacement spécifique (1-12) | `#rec #5 Rappel personnel` | Sociétaires uniquement |
| `#rec2` | Auto-enregistrer la réponse du bot | `#rec2 #3 Demander sur la réunion` | Tous les utilisateurs |
| `#rec2 #N` | Auto-enregistrer la réponse du bot dans l'emplacement | `#rec2 #5 Demander le rappel` | Sociétaires uniquement |
| `#mem` | Afficher la mémoire de l'emplacement 0 | `#mem` | Tous les utilisateurs |
| `#mem #N` | Afficher la mémoire d'un emplacement spécifique | `#mem #3` | Sociétaires uniquement |
| `#reset` | Effacer l'emplacement 0 | `#reset` | Tous les utilisateurs |
| `#reset #N` | Effacer un emplacement spécifique | `#reset #3` | Sociétaires uniquement |
| `#reset #all` | Effacer tous les emplacements (0-12) | `#reset #all` | Sociétaires uniquement |

### 🎨 **Commandes de Génération IA**

| Commande | Description | Exemple | Accès |
|----------|-------------|---------|-------|
| `#image` | Générer une image | `#BRO #image Un coucher de soleil sur les montagnes` | Tous les utilisateurs |
| `#video` | Générer une vidéo | `#BRO #video Un chat jouant dans le jardin` | Tous les utilisateurs |
| `#music` | Générer de la musique | `#BRO #music Une mélodie de piano paisible` | Tous les utilisateurs |
| `#parole` | Ajouter des paroles à la musique | `#BRO #music #parole Une chanson sur l'amitié` | Tous les utilisateurs |
| `#BRO #N` | Utiliser le contexte d'emplacement pour l'IA | `#BRO #3 #image Design de tableau de bord` | Sociétaires uniquement |
| `#BOT #N` | Utiliser le contexte d'emplacement pour l'IA | `#BOT #5 #music Thème personnel` | Sociétaires uniquement |

### 🎤 **Synthèse Vocale**

| Commande | Description | Exemple |
|----------|-------------|---------|
| `#pierre` | Générer de la parole avec la voix Pierre | `#BRO #pierre Bienvenue sur UPlanet` |
| `#amelie` | Générer de la parole avec la voix Amélie | `#BRO #amelie Merci de votre visite` |

### 🔍 **Information et Médias**

| Commande | Description | Exemple | Accès |
|----------|-------------|---------|-------|
| `#search` | Recherche web | `#BRO #search Derniers développements IA` | Tous les utilisateurs |
| `#youtube` | Télécharger une vidéo YouTube | `#BRO #youtube https://youtube.com/watch?v=...` | Tous les utilisateurs |
| `#mp3` | Convertir YouTube en MP3 | `#BRO #youtube #mp3 https://youtube.com/...` | Tous les utilisateurs |

## 🧠 **Système de Mémoire Approfondi**

### Pourquoi 12 Emplacements ?

Le système à 12 emplacements vous permet d'organiser les conversations par contexte :

- **Emplacement 0** : Conversations générales (par défaut) - **Tous les utilisateurs**
- **Emplacement 1** : Discussions professionnelles - **Sociétaires uniquement**
- **Emplacement 2** : Projets personnels - **Sociétaires uniquement**
- **Emplacement 3** : Notes de réunion - **Sociétaires uniquement**
- **Emplacement 4** : Idées créatives - **Sociétaires uniquement**
- **Emplacement 5** : Rappels personnels - **Sociétaires uniquement**
- **Emplacement 6** : Discussions techniques - **Sociétaires uniquement**
- **Emplacement 7** : Sujets d'apprentissage - **Sociétaires uniquement**
- **Emplacement 8** : Plans de voyage - **Sociétaires uniquement**
- **Emplacement 9** : Santé et bien-être - **Sociétaires uniquement**
- **Emplacement 10** : Planification financière - **Sociétaires uniquement**
- **Emplacement 11** : Affaires familiales - **Sociétaires uniquement**
- **Emplacement 12** : Loisirs et intérêts - **Sociétaires uniquement**

### Types d'Enregistrement de Mémoire

#### `#rec` vs `#rec2`

- **`#rec`** : Enregistre uniquement le message de l'utilisateur en mémoire
  ```
  Utilisateur : #BRO #rec #3 Notes de réunion : Discussion des objectifs Q4
  Bot : Voici un résumé de votre réunion...
  → Seulement "Notes de réunion : Discussion des objectifs Q4" est stocké dans l'emplacement 3
  ```

- **`#rec2`** : Enregistre automatiquement la réponse du bot en mémoire
  ```
  Utilisateur : #BRO #rec2 #3 Quels étaient nos objectifs Q4 ?
  Bot : D'après notre discussion précédente, vos objectifs Q4 sont...
  → La réponse du bot est automatiquement stockée dans l'emplacement 3
  ```

#### **Utilisation Combinée**
```
#rec #3 Notes de réunion : Discussion des objectifs Q4
#BRO #rec2 #3 Quels étaient nos points d'action ?
#mem #3 Montrez-moi les notes et la réponse du bot
```

### Exemples d'Utilisation Réelle

#### 📊 **Scénario de Travail**
```
#rec #1 Réunion avec le client sur le projet Q4
#rec #1 Le client veut un tableau de bord alimenté par l'IA
#rec #1 Date limite : 15 décembre
#BRO #1 Quels sont les exigences clés de notre réunion ?
```

#### 🎨 **Projet Créatif**
```
#rec #4 Idée : Application mobile pour agriculteurs locaux
#rec #4 Fonctionnalités : Suivi GPS, alertes météo
#rec #4 Utilisateurs cibles : Petits agriculteurs
#BRO #4 #image Interface d'application agricole moderne
```

#### 🏥 **Suivi de Santé**
```
#rec #9 Rendez-vous chez le médecin demain à 14h
#rec #9 Apporter les résultats d'analyse de sang
#rec #9 Questions sur le nouveau médicament
#mem #9 Montrez-moi mes rappels de santé
```

#### 🎵 **Création Musicale**
```
#rec #12 Travail sur un album ambient
#rec #12 Thème : Vagues océaniques et méditation
#rec #12 Besoin de 5 pistes supplémentaires
#BRO #12 #music Une piste ambient océanique paisible
```

## 🔐 **Système de Contrôle d'Accès**

### **Qui Peut Accéder à Quoi ?**

#### **Tous les Utilisateurs (Emplacement 0)**
- ✅ Enregistrer des souvenirs : `#rec Ma note`
- ✅ Voir les souvenirs : `#mem`
- ✅ Réinitialiser les souvenirs : `#reset`
- ✅ Utiliser la génération IA : `#BRO #image Un paysage`
- ✅ Recherche web : `#BRO #search Dernières nouvelles`
- ✅ Téléchargement YouTube : `#BRO #youtube [URL]`

#### **Sociétaires Uniquement (Emplacements 1-12)**
- ✅ Toutes les fonctionnalités de l'emplacement 0
- ✅ Enregistrer dans des emplacements spécifiques : `#rec #3 Notes de réunion`
- ✅ Voir les souvenirs d'emplacement : `#mem #3`
- ✅ Réinitialiser des emplacements spécifiques : `#reset #3`
- ✅ Utiliser le contexte d'emplacement pour l'IA : `#BRO #3 #image Tableau de bord`
- ✅ Auto-enregistrer les réponses du bot : `#rec2 #5 Demander le rappel`

### **Comment Fonctionne le Contrôle d'Accès**

Le système vérifie le statut de l'utilisateur en contrôlant si un répertoire existe dans `~/.zen/game/players/{email_utilisateur}/` :

```bash
# Exemple de structure de répertoire pour les sociétaires
~/.zen/game/players/
├── societaire1@copylaradio.com/
├── societaire2@copylaradio.com/
└── societaire3@copylaradio.com/
```

### **Messages d'Accès Refusé**

Quand un utilisateur régulier essaie d'accéder aux emplacements 1-12, il reçoit :

```
⚠️ Accès refusé aux emplacements de mémoire 1-12.

Pour utiliser les emplacements de mémoire 1-12, vous devez être sociétaire CopyLaRadio et posséder une ZenCard.

L'emplacement 0 reste accessible pour tous les utilisateurs autorisés.

Pour devenir sociétaire : [lien IPFS]

Votre Capitaine Astroport.
#CopyLaRadio #mem
```

### **Devenir Sociétaire**

Pour obtenir l'accès aux emplacements 1-12 :
1. **Rejoindre CopyLaRadio** : Devenir membre de la coopérative
2. **Obtenir une ZenCard** : Obtenir votre carte d'identité numérique
3. **Création de Répertoire** : Votre répertoire est automatiquement créé dans `~/.zen/game/players/`
4. **Accès Complet** : Profitez des 13 emplacements de mémoire (0-12)

### **Opérations Protégées**

Les opérations suivantes sont protégées pour les emplacements 1-12 :
- **Enregistrement de Mémoire** : `#rec #N` (N = 1-12)
- **Affichage de Mémoire** : `#mem #N` (N = 1-12)
- **Réinitialisation de Mémoire** : `#reset #N` (N = 1-12)
- **Contexte IA** : `#BRO #N` ou `#BOT #N` (N = 1-12)
- **Auto-Enregistrement** : `#rec2 #N` (N = 1-12)

## 🔧 **Architecture Technique**

### Structure des Fichiers
```
~/.zen/tmp/flashmem/
├── {email_utilisateur}/
│   ├── slot0.json      # Conversations générales
│   ├── slot1.json      # Discussions de travail
│   ├── slot2.json      # Projets personnels
│   └── ...
└── uplanet_memory/     # Mémoire basée sur les coordonnées (legacy)
    ├── {coord_key}.json
    └── pubkey/
        └── {pubkey}.json
```

### Format de Fichier de Mémoire
```json
{
  "user_id": "utilisateur@exemple.com",
  "slot": 3,
  "messages": [
    {
      "timestamp": "2024-01-01T12:00:00Z",
      "event_id": "event123",
      "latitude": "48.86",
      "longitude": "2.22",
      "content": "Notes de réunion : Discussion des objectifs Q4"
    }
  ]
}
```

### Chargement du Contexte IA
- **Contexte basé sur l'emplacement** : 20 derniers messages de l'emplacement spécifié
- **Fallback** : Mémoire basée sur pubkey ou coordonnées (legacy)
- **Optimisation des tokens** : Limite le contexte pour éviter le débordement de tokens IA

## 🎯 **Bonnes Pratiques**

### 1. **Organiser par Contexte**
- Utiliser des emplacements cohérents pour des sujets similaires
- Garder les conversations de travail et personnelles séparées
- Utiliser l'emplacement 0 pour le bavardage général

### 2. **Utilisation Efficace de la Mémoire**
- Enregistrer les informations importantes immédiatement avec `#rec`
- Utiliser un contenu descriptif pour un meilleur contexte IA
- Examiner la mémoire régulièrement avec `#mem`

### 3. **Conseils de Génération IA**
- Être spécifique dans vos descriptions
- Combiner les commandes : `#BRO #3 #image Un espace de bureau moderne`
- Utiliser le contexte : `#BRO #4 Basé sur notre discussion précédente, générez...`

### 4. **Gestion de la Mémoire**
- Réinitialiser les emplacements lors du démarrage de nouveaux projets
- Utiliser `#reset #all` avec parcimonie
- Garder les souvenirs importants dans des emplacements dédiés

## 🌍 **Intégration Géolocalisation**

Le bot s'intègre au système de géolocalisation d'UPlanet :

- **Conscient de l'emplacement** : Les souvenirs sont liés aux coordonnées GPS
- **Contexte local** : L'IA peut référencer des informations spécifiques à l'emplacement
- **Mémoire communautaire** : Souvenirs partagés à des emplacements spécifiques

## 🔒 **Confidentialité et Sécurité**

- **Isolation des utilisateurs** : La mémoire de chaque utilisateur est complètement séparée
- **Stockage local** : Tous les fichiers de mémoire stockés localement
- **Pas de synchronisation cloud** : Vos conversations restent privées
- **Partage optionnel** : Choisissez ce que vous partagez avec la communauté
- **Contrôle d'accès** : Emplacements 1-12 protégés pour les sociétaires CopyLaRadio
- **Vérification sécurisée** : Statut utilisateur vérifié via le répertoire `~/.zen/game/players/`

## 🚀 **Fonctionnalités Avancées**

### **Commandes Combinées**
```
#BRO #3 #image Un tableau de bord basé sur nos exigences de réunion
#BOT #5 #music #parole Une chanson sur mes objectifs personnels
#BRO #search #1 Derniers développements en IA pour les entreprises
```

### **Changement de Contexte**
```
#rec #1 Réunion de travail sur le calendrier du projet
#rec #5 Personnel : Besoin d'acheter des courses
#BRO #1 Quelle est notre date limite de projet ?
#BRO #5 Qu'est-ce que je devais acheter ?
```

### **Flux de Travail Créatifs**
```
#rec #4 Projet artistique : Série de peintures abstraites
#BRO #4 #image Une peinture abstraite avec bleu et or
#BRO #4 #music Musique ambient pour la galerie d'art
#BRO #4 #video Un timelapse du processus de peinture
```

## 🎉 **Pourquoi Ce Système est Incroyable**

### **1. Gestion de Contexte Sans Précédent**
- **600 messages au total** sur 12 emplacements
- **Changement de contexte instantané** entre les sujets
- **Mémoire persistante** à travers les sessions

### **2. Intégration IA Multi-Modale**
- Génération **texte, image, vidéo, audio**
- **Flux de travail transparent** entre différents modèles IA
- **Génération consciente du contexte** basée sur l'historique des conversations

### **3. Pratique Réelle**
- **Organisation du travail** : Emplacements séparés pour différents projets
- **Gestion personnelle** : Santé, finances, famille dans des emplacements dédiés
- **Projets créatifs** : Suivre les idées et générer du contenu connexe

### **4. Intelligence Géolocalisée**
- **Conversations conscientes de l'emplacement**
- **Mémoire communautaire** à des endroits spécifiques
- **Contexte local** pour de meilleures réponses IA

### **5. Conception Axée sur la Confidentialité**
- **Stockage local** de tous les souvenirs
- **Isolation des utilisateurs** pour une confidentialité complète
- **Aucune dépendance cloud**

## 🛠️ **Dépannage**

### Problèmes Courants

**Mémoire introuvable**
- Vérifiez si vous utilisez le bon numéro d'emplacement
- Vérifiez que l'ID utilisateur (email) est correct
- Assurez-vous que le fichier de mémoire existe

**Accès refusé aux emplacements 1-12**
- Vérifiez que vous êtes sociétaire CopyLaRadio avec ZenCard
- Vérifiez que votre répertoire existe dans `~/.zen/game/players/`
- Utilisez l'emplacement 0 pour les conversations générales (accessible à tous)
- Contactez CopyLaRadio pour devenir sociétaire

**Échec de génération IA**
- Vérifiez que les services requis fonctionnent (ComfyUI, Ollama)
- Vérifiez la connexion internet pour la recherche web
- Assurez-vous de la syntaxe correcte des commandes

**La réinitialisation ne fonctionne pas**
- Confirmez que vous utilisez le bon numéro d'emplacement
- Vérifiez les permissions de fichier dans `~/.zen/tmp/flashmem/`
- Vérifiez que le répertoire utilisateur existe

### Obtenir de l'Aide

1. Vérifiez les logs : `~/.zen/tmp/IA.log`
2. Vérifiez le statut des services : `./ollama.me.sh`
3. Testez les composants individuels : `./test_slot_memory.sh`

## 🎯 **Liste de Démarrage**

- [ ] Envoyer votre premier message : `#BRO Bonjour !`
- [ ] Enregistrer quelque chose : `#rec Mon premier souvenir` (emplacement 0)
- [ ] Voir la mémoire : `#mem`
- [ ] Générer du contenu : `#BRO #image Un beau paysage`
- [ ] Rechercher sur le web : `#BRO #search Dernières nouvelles technologiques`
- [ ] Créer de la musique : `#BRO #music Une mélodie relaxante`

**Pour les Sociétaires (emplacements 1-12) :**
- [ ] Enregistrer dans un emplacement spécifique : `#rec #3 Notes de réunion`
- [ ] Voir la mémoire d'emplacement : `#mem #3`
- [ ] Utiliser le contexte pour l'IA : `#BRO #3 #image Design de tableau de bord`
- [ ] Réinitialiser un emplacement spécifique : `#reset #3`

---

**Bienvenue dans le futur des conversations IA contextuelles !** 🚀

Le Système Bot IA UPlanet combine la puissance de multiples modèles IA avec une gestion intelligente de la mémoire pour créer un assistant vraiment personnalisé et conscient du contexte. Que vous gériez des projets de travail, poursuiviez des projets créatifs ou que vous ayez simplement une conversation, le système de mémoire à 12 emplacements garantit que votre assistant IA se souvient toujours de ce qui vous importe. 