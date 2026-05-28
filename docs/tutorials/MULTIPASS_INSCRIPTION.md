# 🎟️ Créer son MULTIPASS UPlanet

**Public :** Tout utilisateur souhaitant rejoindre l'écosystème UPlanet.  
**Résultat :** Un MULTIPASS actif, un Kin Maya intégré à votre DID, et votre identité NOSTR reconnue dans la barre UPH.  
**Durée :** 5 à 10 minutes.  
**Prérequis :** Un navigateur web, une adresse email, être connecté à une station UPlanet (`http://127.0.0.1:54321` en local ou `https://u.votre-domaine.tld`).

---

## Ce que vous allez obtenir

À la fin de ce tutoriel :

- ✅ Une identité NOSTR (`nsec` / `npub`) générée de façon déterministe
- ✅ Un portefeuille Ẑen dédié à votre activité UPlanet
- ✅ Un espace de stockage personnel IPFS (uDRIVE — 10 Go)
- ✅ Un QR code MULTIPASS sécurisé par SSSS (2-sur-3)
- ✅ Votre **Kin Maya Tzolkin** dans votre DID (si vous renseignez votre date de naissance)
- ✅ Votre identité reconnue dans la barre UPlanet Header (🌀)

---

## Étape 1 — Ouvrir la page d'inscription

Rendez-vous sur la page MULTIPASS de votre station :

```
http://127.0.0.1:54321/g1
```

Ou depuis l'interface UPlanet, cliquez sur **✨ MULTIPASS** dans le menu de navigation.

Vous arrivez sur la page **🌐️ MULTIPASS DISCO Respawn**.

> 💡 Si vous venez depuis la barre UPlanet Header (🔑 Accès → ✨ Créer un MULTIPASS), votre identifiant G1v1 et mot de passe sont pré-remplis dans les champs cachés — votre portefeuille Ẑen éventuel sera versé au collectif (crowdfunding coopératif).

---

## Étape 2 — Saisir votre email

Dans le champ **📧 Email**, entrez votre adresse email. Elle sert d'identifiant de récupération — elle ne sera jamais publiée publiquement.

```
exemple : alice@example.com
```

> ⚠️ Utilisez une adresse que vous contrôlez. En cas de perte, c'est le seul moyen de récupérer votre MULTIPASS via le mécanisme SSSS.

---

## Étape 3 — Choisir votre localisation GPS

La carte interactive affiche votre position actuelle (géolocalisation automatique).

**Options :**
- **Cliquez sur la carte** pour ajuster votre position manuellement
- **Glissez le marqueur** vers l'emplacement souhaité
- Cliquez **Ma position** pour utiliser le GPS de votre appareil

Les coordonnées (Lat / Lon arrondies à 0.01°) déterminent votre **cellule UMAP** — votre territoire coopératif sur la grille UPlanet.

> 💡 Précision suffisante : 0.01° ≈ 1 km². Vous pouvez affiner plus tard depuis votre profil.

---

## Étape 4 — Découvrir votre Kin Maya *(optionnel)*

Cliquez sur l'accordéon **🌀 Kin Maya — Empreinte Natale** pour le déplier.

### 4a. Renseigner votre date de naissance

Dans le champ **📅 Date de naissance**, entrez votre date (et heure si vous la connaissez).

Dès la saisie, le **Kin Maya** s'affiche en temps réel :

```
🌀 Kin 42 — ⚪ Blanc Ik (Vent), Tonalité Magnétique
```

Votre Kin est un numéro entre 1 et 260, calculé selon le calendrier **Tzolkin** (Dreamspell). Il exprime votre Sceau Solaire 🦎 et votre Tonalité Galactique 🔔.

→ [En savoir plus sur le système Kin Maya](/earth/kin.html)

### 4b. Renseigner votre lieu de naissance *(optionnel)*

Entrez une ville ou des coordonnées GPS — conservées dans votre espace chiffré uniquement.

### 4c. Renseigner votre poids de naissance *(optionnel)*

En kilogrammes — donnée personnelle stockée localement, jamais publiée.

> 🔐 Ces données restent dans `~/.zen/game/nostr/<email>/` sur votre station. Seul le numéro Kin apparaît dans votre DID public (kind 30800 NOSTR).

---

## Étape 5 — Soumettre le formulaire

Cliquez sur **📝 INSCRIPTION**.

Le serveur lance la génération de votre MULTIPASS — comptez **30 à 90 secondes** selon la charge de la station. Un indicateur de chargement s'affiche.

**Ce qui se passe en coulisse :**

1. `g1.sh` reçoit email, coordonnées, salt/pepper (générés aléatoirement si vides) et données natales
2. `make_NOSTRCARD.sh` génère les clés NOSTR (NSEC/NPUB), le portefeuille Ẑen jumeau, l'espace IPNS (uDRIVE), le document DID et les QR codes SSSS
3. Si une date de naissance est fournie, `kin.sh` calcule le Kin Maya et le badge est inclus dans le DID (kind 30800)
4. Le résultat est renvoyé comme page HTML (ZenCard / NOSTR Zine)

---

## Étape 6 — Récupérer votre MULTIPASS

La **modal résultat** s'ouvre avec votre page MULTIPASS.

Elle contient :
- 🎴 Votre **ZenCard** avec QR code(s) SSSS
- 👤 Votre profil NOSTR (nom, avatar, npub)
- 🌀 Votre **Kin Maya** (si date de naissance fournie)
- 💳 L'adresse de votre portefeuille Ẑen

**Actions possibles :**
- **Ouvrir** — ouvre dans un nouvel onglet pour imprimer ou sauvegarder
- → [Imprimer votre ZenCard](../how-to/print_multipass_cards.md)

> 💾 **Sauvegardez votre ZenCard dès maintenant.** Elle contient les parts SSSS de votre clé privée — sans elle, la récupération en cas de perte de session est impossible.

---

## Étape 7 — Se connecter à UPlanet Header (UPH)

La barre **UPlanet Header** (bande sombre en haut de page) vous permet de vous identifier sur toutes les pages UPlanet.

### Option A — Connexion G1v1 (recommandée)

Cliquez sur **🔑 Accès** dans la barre UPH pour ouvrir le panneau de connexion.

Dans la section **⚡ Dériver depuis G1v1** :

| Champ | Valeur |
|-------|--------|
| Login G1v1 | Le salt utilisé lors de l'inscription (ou votre email) |
| Mot de passe G1 | Le pepper utilisé lors de l'inscription |
| Email *(optionnel)* | Nom du compte sauvegardé dans votre navigateur |

Cliquez **Dériver G1v1 →**.

> 💡 Si salt/pepper étaient vides à l'inscription (générés aléatoirement), vous ne pouvez pas vous connecter en G1v1. Utilisez l'option B.

### Option B — Importer une nsec

Si vous avez récupéré votre `nsec1…` depuis votre ZenCard :

Dans la section **🗝 Importer une nsec**, collez votre nsec et cliquez **Importer nsec →**.

### Ce que vous voyez après connexion

- La barre UPH affiche votre **nom** et votre **solde ẐEN** 💰
- Le bouton **🔑 Accès** disparaît
- Le widget **🌀** affiche votre numéro de Kin (ex : `🌀42`) si votre date de naissance était renseignée

---

## Étape 8 — Explorer votre Kin Maya

Cliquez sur **🌀42** (ou **🌀** si Kin non chargé) dans la barre UPH.

Un panneau s'ouvre avec deux onglets :

### Onglet "Kin Maya"

```
42
Kin Maya de naissance

Sceau    ⚪ Blanc Ik (Vent)
Tonalité Magnétique
         ⚡ Unifier · 🔥 Unification · ✨ Présence
```

Votre profil NOSTR (nom, avatar) s'affiche en bas si le relay est accessible.

### Onglet "Debug"

- **Kind 0** — événement NOSTR brut de votre profil (JSON)
- **Kind 30800** — votre document DID complet (JSON), y compris le badge MayaKin
- **Kin extrait** — le badge Kin tel que parsé par le widget

> La console du navigateur (`F12 → Console`) contient les logs groupés `[kin.js]` avec le détail complet des événements NOSTR reçus.

---

## Étape 9 — Rejoindre votre constellation

Pour accéder aux fonctionnalités complètes du MULTIPASS (publication NOSTR, paiements ẐEN, uDRIVE…), vous devez être **ami avec au moins un astronaute** UPlanet (membre du réseau N² — amis d'amis).

**Comment trouver un astronaute :**
- Demandez à un membre existant de vous suivre sur NOSTR
- Rejoignez le relay `relay.copylaradio.com` et publiez un kind 1 de présentation
- Contactez `support@qo-op.com` pour un parrainage

> 🌐 Votre MULTIPASS est actif dès la création — le réseau N² détermine vos droits d'accès aux services coopératifs (voir [WoTx2](../reference/WOTX2_SYSTEM.md)).

---

## Récapitulatif des fichiers créés

Sur votre station, votre MULTIPASS génère les fichiers suivants :

```
~/.zen/game/nostr/<email>/
├── .secret.nostr          # NSEC + NPUB + HEX (chmod 600)
├── .multipass.json        # Données complètes MULTIPASS
├── .ssss.player.key       # Clé SSSS chiffrée (part M)
├── G1PUBNOSTR             # Adresse portefeuille Ẑen (SS58)
├── HEX                    # Clé publique NOSTR en hexadécimal
├── NPUB                   # Clé publique NOSTR (bech32)
├── LANG                   # Langue de l'interface
├── BIRTHDATE              # Date de naissance YYYY-MM-DD (si fournie)
├── .birth_datetime        # Date+heure naissance complète (si fournie)
├── .birth_place           # Lieu de naissance (si fourni)
├── .birth_weight          # Poids de naissance kg (si fourni)
├── picture.png            # Avatar
├── uSPOT.QR.png           # QR code accès station
└── .nostr.zine.html       # Page MULTIPASS (retournée au navigateur)
```

---

## Dépannage

### "EXISTING MULTIPASS" affiché

Un MULTIPASS existe déjà pour cet email. Si c'est le vôtre, reconnectez-vous via G1v1 ou nsec. Si vous avez oublié vos identifiants, contactez l'administrateur de la station.

### La génération dépasse 2 minutes

Vérifiez que le daemon IPFS est actif : `ipfs swarm peers | wc -l` doit retourner > 0. Relancez avec `./start.sh` si nécessaire.

### Le Kin n'apparaît pas dans l'UPH

Le badge Kin est publié dans le DID (kind 30800) lors de la génération du MULTIPASS. Si vous avez ajouté la date de naissance après coup, relancez `did_manager_nostr.sh` manuellement :

```bash
~/.zen/Astroport.ONE/tools/did_manager_nostr.sh update <email>
```

### Erreur "salt/pepper trop long"

Le champ salt ou pepper dépasse 56 caractères (limite SSSS DISCO). Raccourcissez vos identifiants G1v1.

---

## Référence rapide

| Document | Description |
|----------|-------------|
| [IDENTITY_MULTIPASS.md](../reference/IDENTITY_MULTIPASS.md) | Référence technique du MULTIPASS |
| [DID_IMPLEMENTATION.md](../explanation/DID_IMPLEMENTATION.md) | Architecture DID + badge Kin Maya |
| [print_multipass_cards.md](../how-to/print_multipass_cards.md) | Imprimer et distribuer les ZenCards |
| [WOTX2_SYSTEM.md](../reference/WOTX2_SYSTEM.md) | Système de Web of Trust N² |
| [kin.html](/earth/kin.html) | Page interactive Kin Maya |
