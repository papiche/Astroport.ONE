# MINELIFE — Système de Crafting de Compétences WoTx2

**Version** : 1.0  
**Interface** : `UPlanet/earth/minelife.html`  
**Statut** : Production  
**License** : AGPL-3.0

MineLife est l'interface de crafting décentralisé des compétences WoTx2 sur UPlanet. Inspirée de l'esthétique Minecraft, elle permet de visualiser, synthétiser et enrichir collectivement des compétences certifiées sur un relay NOSTR.

---

## 1. Acteurs et Clés

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ACTEURS DU SYSTÈME                                │
│                                                                             │
│  MULTIPASS (joueur)          UPLANETNAME_G1 (oracle)    NODE (station)      │
│  ┌─────────────┐             ┌──────────────────┐       ┌───────────────┐   │
│  │ clé NOSTR   │             │ clé G1 dérivée   │       │ clé NOSTR     │   │
│  │ (NIP-07)    │             │ → clé NOSTR      │       │ home_station  │   │
│  │ pubkey hex  │             │ = UPLANETNAME    │       │ dans MULTIPASS│   │
│  └──────┬──────┘             └────────┬─────────┘       └──────┬────────┘   │
│         │                            │                         │            │
│         │ signe 30501, 30502,        │ signe 30503 Oracle      │ reçoit     │
│         │ 30503 (auto), 30504,       │                         │ Kind 4 DM  │
│         │ 7 (reaction), 4 (DM)       │                         │ (BRO)      │
└─────────┴────────────────────────────┴─────────────────────────┴────────────┘
```

### Champ `home_station` du MULTIPASS (Kind 0)

Le profil NOSTR du MULTIPASS (Kind 0) contient un champ `home_station` au format :

```
home_station = "IPFSNODEID:NODE_HEX_64"
```

- **IPFSNODEID** : identifiant du nœud IPFS de la station (ex: `12D3KooW...` ou `Qm...`)
- **NODE_HEX_64** : pubkey NOSTR hexadécimale 64 chars de la station

Ce champ est la **seule** source authoritative pour l'adresse BRO. Il est publié par `nostr_setup_profile.py` lors du setup du MULTIPASS.

---

## 2. Kinds NOSTR — Schéma Complet

```
Kind 0     Kind 30500   Kind 30501   Kind 30502   Kind 30503   Kind 7      Kind 30504   Kind 4
(MULTIPASS) (Permit def) (Demande)   (Adoubement) (Cert.)      (Reaction)  (Formation)  (DM BRO)
     │           │            │            │            │           │            │           │
     │           │            │            │            │           │           │            │
     ▼           ▼            ▼            ▼            ▼           ▼           ▼            ▼
[pubkey]   [d, t, r ...]  [d, l, p]  [d, e, p]   [d, l, p]  [e, p, t]   [d, t, r]   [p, content]
```

### Kind 0 — Profil MULTIPASS

Publié par `nostr_setup_profile.py`. Contient le champ `home_station` en JSON.

```json
{
  "kind": 0,
  "pubkey": "<joueur_hex>",
  "content": "{
    \"name\": \"Alice\",
    \"home_station\": \"12D3KooWxxx:NODE_HEX_64\",
    \"g1pub\": \"<g1_pubkey>\",
    \"nip05\": \"alice@station.domain.tld\"
  }",
  "tags": [
    ["i", "home_station:12D3KooWxxx:NODE_HEX_64", ""],
    ["i", "g1pub:<g1_pubkey>", ""]
  ]
}
```

---

### Kind 30500 — Définition de Permit (Recette de Craft)

Toute personne peut créer un permit. Les crafts simples utilisent uniquement `t` (folksonomy), les crafts composites ajoutent des tags `requires` pour spécifier les ingrédients avec leur niveau minimum.

**Permit simple (auto-proclamé) :**

```json
{
  "kind": 30500,
  "pubkey": "<créateur_hex>",
  "tags": [
    ["d", "PERMIT_LINUX_X1"],
    ["t", "permit"],
    ["t", "auto_proclaimed"],
    ["t", "linux"],
    ["r", "/ipfs/Qm.../intro-linux.pdf", "document"]
  ],
  "content": "{\"id\":\"PERMIT_LINUX_X1\",\"name\":\"Linux Fondamentaux\",\"icon\":\"🐧\",\"skill_tag\":\"linux\",\"auto_proclaimed\":true}"
}
```

**Permit composite (craft avec ingrédients) :**

```json
{
  "kind": 30500,
  "pubkey": "<créateur_hex>",
  "tags": [
    ["d", "PERMIT_DEVOPS_X1"],
    ["t", "permit"],
    ["t", "composite"],
    ["requires", "linux", "1"],
    ["requires", "docker", "1"],
    ["requires", "bash", "1"],
    ["t", "linux"],
    ["t", "docker"],
    ["t", "bash"],
    ["r", "/ipfs/Qm.../formation-devops.pdf", "document"],
    ["r", "https://ipfs.station/ipfs/Qm.../video.mp4", "video"]
  ],
  "content": "{\"id\":\"PERMIT_DEVOPS_X1\",\"name\":\"DevOps Station\",\"icon\":\"⚙️\",\"description\":\"Opération complète d'une station Astroport\",\"skill_tag\":\"devops\"}"
}
```

**Règle MineLife — Ingrédients (`parseRecipeFromPermit`) :**

| Priorité | Source | Format | Niveau |
|---|---|---|---|
| 1 (explicite) | tag `requires` | `["requires", "skill", "level"]` | Niveau minimum spécifié |
| 2 (fallback) | tag `t` hors `_META_T` | `["t", "skill"]` | Niveau 1 implicite |

`_META_T = {'permit', 'auto_proclaimed', 'composite', 'formation', 'training'}` — exclus de l'analyse ingrédients.

Les tags `t` sont **toujours émis en doublure** des `requires` pour permettre le filtrage relay par skill.  
Les tags `r` sont les **ressources de formation** affichées dans l'onglet Formation.

---

### Kind 30501 — Demande d'apprentissage

Auto-signé par l'apprenti. Déclenche le processus de validation communautaire.

```json
{
  "kind": 30501,
  "pubkey": "<apprenti_hex>",
  "tags": [
    ["d", "req_<timestamp>"],
    ["l", "PERMIT_DEVOPS_X1", "permit_type"],
    ["p", "<apprenti_hex>"],
    ["t", "permit"], ["t", "request"], ["t", "devops"]
  ],
  "content": "{
    \"permit_definition_id\": \"PERMIT_DEVOPS_X1\",
    \"statement\": \"J'opère une station Astroport depuis 6 mois\"
  }"
}
```

---

### Kind 30502 — Adoubement (Règle B)

Un pair de niveau X1+ adoube directement l'apprenti. Suffit pour déclencher une montée de niveau sans attendre 3 réactions. Le tag `l` expose le permit du validateur pour auto-vérification.

```json
{
  "kind": 30502,
  "pubkey": "<pair_hex>",
  "tags": [
    ["d", "att_<id>"],
    ["e", "<event_id_30501>"],
    ["p", "<apprenti_hex>"],
    ["l", "PERMIT_DEVOPS_X1", "permit_type"],
    ["t", "permit"], ["t", "attestation"], ["t", "devops"]
  ],
  "content": "{\"attested_skill\":\"devops\",\"attested_at\":\"2026-05-16T...\"}"
}
```

---

### Kind 30503 — Certificat de Compétence (deux formats)

#### Format Oracle (signé par UPLANETNAME_G1)

```json
{
  "kind": 30503,
  "pubkey": "<UPLANETNAME_G1_hex>",
  "tags": [
    ["d", "cred_<id>"],
    ["l", "PERMIT_DEVOPS_X1", "permit_type"],
    ["p", "<joueur_hex>"]
  ],
  "content": "{\"credential_id\":\"cred_<id>\",\"holder_npub\":\"<joueur_hex>\"}"
}
```

#### Format P2P / auto-signé (TrocZen, MineLife)

```json
{
  "kind": 30503,
  "pubkey": "<joueur_hex>",
  "tags": [
    ["d", "PERMIT_DEVOPS_X1"],
    ["t", "devops"],
    ["t", "composite"],
    ["level", "1"],
    ["expiration", "<timestamp_3ans>"],
    ["p", "<joueur_npub>"],
    ["e", "<kind30503_linux>"],
    ["e", "<kind30503_docker>"],
    ["e", "<kind30503_bash>"]
  ],
  "content": "{\"id\":\"PERMIT_DEVOPS_X1\",\"name\":\"DevOps Station\",\"composite\":true,\"synthesized_at\":\"...\"}"
}
```

Les `e` tags pointent vers les Kind 30503 ingrédients (preuve de prérequis).  
Le tag `expiration` (NIP-40) fixe un TTL de 3 ans pour forcer le renouvellement.

---

### Kind 7 — Réaction de validation (Règle A)

3 réactions `+` distinctes → l'apprenti peut auto-signer un Kind 30503.

```json
{
  "kind": 7,
  "pubkey": "<pair_hex>",
  "tags": [
    ["e", "<event_id_30501>"],
    ["p", "<apprenti_hex>"],
    ["t", "wotx-review"],
    ["t", "devops"],
    ["k", "30500"]
  ],
  "content": "+"
}
```

---

### Kind 30504 — Ressource de Formation

Publiée par n'importe quel utilisateur MULTIPASS pour enrichir collectivement les formations.  
Lie un contenu multimédia (IPFS/URL) à un skill via le tag `r`.

```json
{
  "kind": 30504,
  "pubkey": "<contributeur_hex>",
  "tags": [
    ["d", "training_devops_<timestamp>"],
    ["t", "devops"],
    ["t", "formation"],
    ["r", "/ipfs/Qm.../tuto-docker.mp4", "video"],
    ["title", "Introduction à Docker pour DevOps"]
  ],
  "content": "{
    \"description\": \"Ressource formation devops\",
    \"skill\": \"devops\",
    \"resource_url\": \"/ipfs/Qm.../tuto-docker.mp4\",
    \"resource_type\": \"video\"
  }"
}
```

**Types de médias supportés** (conformes `UPlanet_FILE_CONTRACT.md`) :

| Type tag `r` | Kind source | Produit par |
|---|---|---|
| `video` | Kind 21/22 (NIP-71) | `webcam.html`, `ajouter_media.sh` |
| `audio` | Kind 1222 (NIP-A0) | VOCALS system |
| `document` | Kind 1063 (NIP-94) | `ajouter_media.sh` (pdf) |
| `image` | Kind 1063 (NIP-94) | Upload IPFS |
| `cours` | Kind 30023 (NIP-23) | Articles markdown |
| `lien` | — | URL libre |

---

### Kind 4 — DM Chiffré BRO (NIP-04)

L'utilisateur envoie un DM NIP-04 au NODE (clé issue de `home_station`). Le daemon `bro_dm_daemon.sh` répond.

```json
{
  "kind": 4,
  "pubkey": "<joueur_hex>",
  "tags": [["p", "<NODE_HEX_64>"]],
  "content": "<NIP-04 ciphertext de: 'Aide BRO pour le skill devops'>"
}
```

**Commandes BRO disponibles** :
- Question libre → réponse IA (Ollama/RAG)
- `#badge <skill>` → génération image badge via ComfyUI → URL IPFS
- `#rec <skill>` → recommandations de ressources
- `#mem <note>` → mémorisation dans RAG personnel

---

## 3. Flux de Crafting MineLife

```
MULTIPASS (joueur)           NOSTR Relay             ORACLE / BRO
      │                           │                       │
      │──── fetchEvents(30500) ──►│                       │
      │◄─── permit definitions ───│                       │
      │                           │                       │
      │   [MineLife UI affiche    │                       │
      │    les crafts disponibles]│                       │
      │                           │                       │
      │──── fetchEvents(30503) ──►│                       │
      │◄─── mes certificats ──────│                       │
      │                           │                       │
      │   [checkCompositeEligibility()]                   │
      │   [slots ok/miss + glow si éligible]              │
      │                           │                       │
[si éligible]                    │                       │
      │──── publish Kind 30503 ──►│                       │
      │     (auto-signé)          │                       │
      │                           │──── ORACLE.refresh ──►│
      │                           │                       │ émet 30503 Oracle
      │                           │◄─── Kind 30503 ───────│
      │                           │                       │
[Mode Edition]                   │                       │
      │──── openCraftEditor() ───►[modale]                │
      │──── publish Kind 30500 ──►│ (nouvelle recette)    │
      │                           │                       │
[Formation]                      │                       │
      │──── fetchEvents(30504) ──►│                       │
      │◄─── ressources formation ─│                       │
      │──── openMediaBrowser() ──►[médias NOSTR joueur]   │
      │──── publish Kind 30504 ──►│ (lien média → skill)  │
      │                           │                       │
[BRO]                            │                       │
      │──── Kind 4 DM ───────────►│──────────────────────►│ bro_dm_daemon.sh
      │◄─── Kind 4 DM (réponse) ──│◄──────────────────────│ Ollama/ComfyUI
```

---

## 4. Mode Édition Collectif

Le bouton "✏️ Éditer" dans la topbar active le mode édition pour tout utilisateur MULTIPASS connecté :

- **Atelier** : bouton "Nouveau craft" + "✎ Modifier" sur chaque carte
- **Formation** : bouton "✕" sur les ressources (suppression), "Mes médias" pour browser NOSTR
- **Éditeur de craft** : modale avec ingrédients, ressources, icône, description
  - Publie un Kind 30500 (replaceble event — même `d` tag = mise à jour)
  - Le navigateur de médias charge les Kind 21/22/1063/1222/30023 du joueur

```
ÉDITEUR WYSIWYG — Clic & Drag
┌─────────────────────────────────────────────────────────────────────┐
│ ⚒ Modifier : DevOps Station (PERMIT_DEVOPS_X1)                      │
├──────────────────┬────────────────────────────────┬─────────────────┤
│   PALETTE        │        GRILLE 3×3              │   RESSOURCES    │
│   (skills)       │                                │                 │
│                  │  ┌─────────┬─────────┬───────┐ │  🎬 tuto.mp4   │
│  [🐧 linux  x1] │  │linux x1 │docker x1│bash x1│ │  📄 devops.pdf │
│  [🐋 docker x1] │  └─────────┴─────────┴───────┘ │                 │
│  [📜 bash   x1] │  ┌─────────┬─────────┬───────┐ │  [📁 Mes médias]│
│  [🐍 python x2] │  │         │         │       │ │                 │
│  [🌐 nostr  x1] │  └─────────┴─────────┴───────┘ │  ← glisser      │
│  ─── médias ───  │  ┌─────────┬─────────┬───────┐ │     médias ici  │
│  [🎬 tuto.mp4]  │  │         │         │       │ │                 │
│  [📄 guide.pdf] │  └─────────┴─────────┴───────┘ │                 │
│                  │           ↓                    │                 │
│                  │       ⚙️ DevOps                │                 │
│                  │    (résultat du craft)          │                 │
├──────────────────┴────────────────────────────────┴─────────────────┤
│                       [Annuler] [☁ Publier]                          │
└──────────────────────────────────────────────────────────────────────┘
```

**Interactions WYSIWYG** :
- **Glisser** un skill depuis la palette → slot de la grille (placement ou déplacement)
- **Double-clic** sur un slot rempli → vider le slot
- **Boutons `+`/`−`** sur un slot rempli → ajuster le niveau requis (1 à 5)
- **Glisser** un slot rempli → autre slot (échange de position)
- **Glisser** un média → zone Ressources (ajout)
- **[📁 Mes médias]** → navigateur NOSTR du joueur (Kind 21/22/1063/1222/30023)
- **[☁ Publier]** → émet `["requires", skill, level]` + `["t", skill]` + `["r", url, type]`

---

## 5. Schéma des Relations entre Kinds

```
Kind 30500 (Recette / Permit def)
  │ tags: d=PERMIT_ID,
  │       requires=ingredient1+level, requires=ingredient2+level,  ← ingrédients explicites
  │       t=ingredient1, t=ingredient2,                            ← miroir pour relay filter
  │       r=url_formation
  │
  ├── référencé par ──► Kind 30501 (Demande)
  │                        tag: l=PERMIT_ID
  │                        │
  │                        ├── validé par ──► Kind 7 (×3 Règle A) ──► Kind 30503 auto-signé
  │                        └── adoubé par ──► Kind 30502 (Règle B) ──► Kind 30503 auto-signé
  │
  ├── complété par ────► Kind 30504 (Ressource formation)
  │                        tags: t=skill, r=url_media, title=...
  │
  └── résultat ────────► Kind 30503 (Certificat)
                           Format Oracle  : pubkey=UPLANETNAME_G1, l=PERMIT_ID, p=joueur
                           Format P2P     : pubkey=joueur, d=PERMIT_ID, t=skill, level=N
                           Format Folkso  : pubkey=joueur, t=skill, level=N (sans d)

Kind 0 (MULTIPASS)
  │ content: { home_station: "IPFSNODEID:NODE_HEX_64" }
  │
  └── home_station ──► Kind 4 (DM BRO chiffré NIP-04)
                         p=NODE_HEX_64, content=NIP04_ciphertext
                         réponse du bro_dm_daemon.sh via Kind 4 retour
```

---

## 6. Analyse Protocolaire

### Correction logique de la Toile de Confiance

WoTx2 résout le problème de certification décentralisée des compétences par trois mécanismes complémentaires :

```
Mode Oracle   ──► seuil min_attestations (ORACLE.refresh.sh)
Mode P2P      ──► Règle A (3×Kind 7) ou Règle B (1×Kind 30502 X1+)
Mode Folkso   ──► auto-proclamation + tag t + level (TrocZen offline)
```

**Agnosticisme signataire** : un Kind 30503 est valide quel que soit son émetteur. La vérification suit une chaîne de priorité :
1. Oracle VC : `["l", "PERMIT_SKILL_Xm", "permit_type"]` signé par `UPLANETNAME_G1` (autorité coopérative)
2. TrocZen P2P : `pubkey == titulaire` + `["d", "PERMIT_SKILL_Xm"]`
3. Folksonomy : `pubkey == titulaire` + `["t", skill]` + `["level", N]`

Cela garantit que le système fonctionne offline (TrocZen), avec Oracle (online) ou en mode hybride, sans point de défaillance unique.

### Flux Formation → Validation → Certification

```
[Formation]          [Demande]          [Validation]          [Certification]
Kind 30504/30500      Kind 30501         Kind 7 ×3             Kind 30503
(ressources)  →→→   (auto-déclaration)  (Règle A)   →→→      (auto-signé)
                          │
                          └─→ Kind 30502 (Règle B, pair X1+) →→→ Kind 30503
                                                                   (immédiat)
```

La **session de crafting** (MineLife) constitue une forme implicite de validation composite :
- L'apprenti assemble les ingrédients (Kind 30503 existants) dans la grille
- `checkCompositeEligibility()` vérifie localement chaque `requires` contre ses certificats
- Le Kind 30503 composite est publié uniquement si **tous** les ingrédients sont satisfaits au niveau requis

### Niveau requis et progression non-linéaire

Le tag `["requires", "skill", "level"]` permet d'exprimer des prérequis à niveau variable :

```
PERMIT_SENIOR_DEVOPS_X2
  ├── requires linux 2   (pas seulement X1 !)
  ├── requires docker 2
  └── requires bash 1

PERMIT_SYSADMIN_X3
  ├── requires linux 3
  ├── requires devops 2
  └── requires nostr 1
```

Cela crée une **hiérarchie de crafts** naturelle et arbitrairement profonde, sans taxonomy centrale.

### Extensibilité domaine-agnostique

Tout tag `t` non réservé (`_META_T`) est un skill valide. Le protocole s'applique sans modification à :

| Domaine | Exemples de permits |
|---|---|
| Technique | `linux`, `docker`, `python`, `nostr`, `ipfs` |
| Artisanat | `menuiserie`, `soudure`, `maçonnerie` |
| Social | `mediation`, `facilitation`, `facilitation-graphique` |
| Environnement | `ore-verifier`, `permaculture`, `bilan-carbone` |
| Santé | `premiers-secours`, `phytotherapie` |
| Art | `musique-jazz`, `video-montage`, `illustration` |

Chaque communauté peut créer ses permits, ses recettes, ses ressources — sans permission de l'Oracle.

### Découverte N² et organisation de session

La constellation Astroport synchronise les events NOSTR entre toutes les stations via `backfill_constellation.sh` (N² sync). Chaque joueur peut ainsi voir les compétences et les crafts de l'ensemble du réseau sans annuaire central.

**Flux de montée en compétence via N² :**

```
[Découverte N²]         [Aspiration X1]         [Session]            [Certification]
                              │
 Joueur parcourt           publie                DM Kind 4 aux         Kind 7 ×3
 les crafts et skills   Kind 30501   ──────►    porteurs voisins   ──► (Règle A)   ──► Kind 30503
 de son entourage           │                   (visible dans N²)
 sur le relay local         │                        │
                            │                        └──► Kind 30502  ──► Kind 30503
                            │                             (Règle B)       (immédiat)
```

**Trois étapes :**

1. **Découverte** : MineLife charge les Kind 30500 (crafts) et Kind 30503 (certifs) depuis le relay — qui agrège l'ensemble du voisinage N² via `backfill_constellation.sh`. Le joueur voit quels skills existent et qui les détient autour de lui.

2. **Aspiration X1** : En cliquant sur un skill voulu, le joueur publie un Kind 30501. C'est le premier niveau du protocole — l'expression publique d'un désir d'apprendre. L'interface propose alors un bouton "📩 Contacter les porteurs" qui ouvre des DM Kind 4 vers les titulaires du skill dans son voisinage.

3. **Session de craft** : Les porteurs contactés organisent une session. À l'issue de la session validée par l'apprenant lui-même ET les pairs (Kind 7 ×3 ou Kind 30502 d'un pair X1+), le Kind 30503 est auto-signé. La session n'a pas besoin d'être enregistrée on-chain — les certificats des participants constituent la preuve suffisante.

**Invariant de confiance** : seul un apprenant **au niveau égal ou supérieur** peut émettre un Kind 7 de validation ou un Kind 30502. Le voisinage N² garantit que ces pairs sont réels (ils ont leur propre Kind 30503 vérifiable sur le même relay).

---

### Implémentations actives

Les points suivants sont tous implémentés dans `minelife.html` :

| Sujet | Implémentation |
|---|---|
| **Expiration P2P** | `["expiration", "<ts>"]` NIP-40 dans `publishComposite` (Kind 30503) — TTL 3 ans |
| **Credential du pair (Règle B)** | `["l", "<PERMIT_ID>", "permit_type"]` ajouté dans `publishAttestation` (Kind 30502) — auto-vérifiable |
| **Révocation** | `revokeSkill(eventId)` → Kind 5 NIP-09 — bouton "Révoquer" dans l'onglet Mes Compétences |
| **X1 aspiration → contact N²** | `showHoldersModal(skill)` après `submitRequest` — affiche les porteurs N², DM NIP-04 directement depuis l'interface |
| **Preuve de session (composite)** | Les `e` tags dans Kind 30503 composite pointent vers les Kind 30503 ingrédients (preuve de prérequis) |

---

## 7. Fichiers de référence

| Fichier | Rôle |
|---|---|
| `UPlanet/earth/minelife.html` | Interface principale MineLife WoTx2 |
| `UPlanet/earth/minelife.js` | Widget crafting (MineLife.init) |
| `UPlanet/earth/minelife.css` | Styles Minecraft-style |
| `UPlanet/earth/common.js` | NOSTR relay, fetchEvents, requireSigned |
| `UPlanet/earth/feedback.js` | Système de feedback utilisateur |
| `Astroport.ONE/tools/nostr_setup_profile.py` | Publie Kind 0 avec `home_station` |
| `Astroport.ONE/tools/oracle_init_captain_wotx2.sh` | Bootstrap Kind 30500 capitaines |
| `Astroport.ONE/RUNTIME/ORACLE.refresh.sh` | Émet Kind 30503 Oracle (cron) |
| `Astroport.ONE/IA/bro_dm_daemon.sh` | Daemon Kind 4 BRO + ComfyUI |
| `Astroport.ONE/IA/generate_image.sh` | Génération badge via ComfyUI |

---

## 8. NIPs de référence

| NIP | Utilisation |
|---|---|
| [NIP-01](01.md) | Protocole de base |
| [NIP-04](04.md) | Chiffrement DM BRO |
| [NIP-07](07.md) | Extension signer (requireSigned) |
| [NIP-33](33.md) | Parameterized replaceable events (30500, 30503, 30504) |
| [NIP-42](42.md) | Authentification relay (callAPIWithAuth) |
| [NIP-71](71.md) / Kind 21/22 | Vidéos dans le navigateur médias |
| [NIP-94](94.md) / Kind 1063 | Fichiers/images dans le navigateur médias |
| [NIP-A0](A0.md) / Kind 1222 | Messages vocaux VOCALS |
| [NIP-23](23.md) / Kind 30023 | Articles markdown comme ressources |
| [NIP-42 ext.](42-oracle-permits-extension.md) | WoTx2 Permits (30500–30504) |
| [NIP-58 ext.](58-oracle-badges-extension.md) | Badges visuels NIP-58 |
| [NIP-40](40.md) | Expiration des events (TTL inter-NODE DM) |

---

## Durée de Vie des Messages Inter-NODE (NIP-40 TTL)

Tous les messages Kind 4 (DM chiffrés NIP-44) envoyés entre stations via `nostr_node_intercom.py` portent un tag d'expiration NIP-40 (`["expiration", "<timestamp>"]`) pour garantir que les relays ne stockent pas indéfiniment des ordres opérationnels.

### TTL par canal

| Canal | TTL | Justification |
|-------|-----|---------------|
| `bro_ia` (roaming forward) | 3 600 s (1 h) | La commande BRO est traitée immédiatement ou abandonnée |
| `comfyui_job` | 7 200 s (2 h) | Fenêtre max pour qu'un Brain GPU démarre le job |
| `comfyui_result` | 3 600 s (1 h) | Le résultat doit être récupéré avant expiration |
| `udrive` | 86 400 s (24 h) | Sync fichier moins urgent |
| `zen_like` | 86 400 s (24 h) | Paiement relayé, retenter dans la journée si absent |
| Défaut `send` | 86 400 s (24 h) | Tous les canaux non listés ci-dessus |

### Utilisation

```bash
# Envoi avec TTL explicite (en secondes)
python3 tools/nostr_node_intercom.py send \
    --nsec    "$NODE_NSEC" \
    --to      "$DEST_HEX" \
    --channel "bro_ia" \
    --payload "$JSON" \
    --ttl     3600 \
    --relays  "wss://relay.copylaradio.com"

# TTL=0 → message permanent (déconseillé pour les canaux opérationnels)
```

### Comptes test déterministes

Pour valider le protocole sans utiliser les clés de production :

| Compte | Salt | Pepper | Usage |
|--------|------|--------|-------|
| `coucou` | `coucou` | `coucou` | Émetteur test |
| `toto` | `toto` | `toto` | Récepteur test |

Les tests `tests/test_intercom.sh` (section 6-8) utilisent ces comptes pour vérifier le cycle complet send→receive→decrypt avec TTL=300s, ainsi que les services Ollama et ComfyUI.
