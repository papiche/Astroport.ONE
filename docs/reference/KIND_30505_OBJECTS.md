# Kind 30505 — Objets & Ressources (WoTx² Crafting Protocol)

**Version** : 1.0 — Mai 2026  
**Statut** : Proposition stable  
**License** : AGPL-3.0

---

## Pourquoi Kind 30505 ?

Le crafting WoTx² repose sur deux piliers :

- **Skills** (Kind 30503) — ce qu'un MULTIPASS *sait faire*
- **Objets** (Kind 30505) — ce qu'un MULTIPASS *possède ou partage*

Un craft (Kind 30500) associe des skills ET des objets pour produire un nouveau skill ou un nouvel objet. Sans représentation formelle des objets, seules les compétences abstraites peuvent être attestées — impossible de modéliser un atelier, une cabane, un RPi ou du câblage.

---

## Kinds utilisés dans ce protocole

| Kind | Type NOSTR | Rôle |
|------|-----------|------|
| **30505** | Param. replaceable (NIP-33) | État courant de l'objet |
| **1505**  | Regular (append-only) | Journal de transactions (qty / durability) |
| **1500**  | Regular (append-only) | Log d'exécution de craft (session réelle) |
| **30500** | Param. replaceable | Recette de craft (enrichie : quorum, rôles) |

---

## Kind 30505 — Modèle complet

### Champs JSON (content)

```json
{
  "name":              "Nom lisible de l'objet",
  "type":              "tool | material | infrastructure | knowledge | capacity",
  "mobility":          "fixed | mobile | portable | distributed",
  "quantity":          10,
  "quantity_type":     "discrete | capacity | durability | infinite",
  "quantity_unit":     "unit | seat | liter | hour | percent | ...",
  "durability":        85,
  "repairability":     7,
  "condition":         "new | operational | degraded | maintenance-needed | retired",
  "description":       "Description lisible",
  "min_operators":     1,
  "version":           "1.0"
}
```

### Tags NOSTR obligatoires

```
["d",             "<object-id>"]          — identifiant unique (slug kebab-case)
["title",         "<nom lisible>"]
["t",             "<type>"]               — tool | material | infrastructure | ...
["t",             "<mobility>"]           — fixed | mobile | ...
["t",             "<quantity_type>"]      — discrete | capacity | durability | infinite
["quantity",      "<N>"]                  — valeur courante (string)
["quantity_unit", "<unit>"]
```

### Tags optionnels enrichis

```
["durability",           "85"]           — santé 0-100
["repairability",        "7"]            — réparabilité 0-10
["min_operators",        "2"]            — quorum MULTIPASS requis pour utilisation
["weight",               "9g"]
["size",                 "65x30x5mm"]
["model",                "RPi Zero 2W"]
["geo",                  "REGION:44:2"]  — géo publique (précision 1°)
["geo_sector",           "<nip44:...>"]  — géo secteur (0.1°), chiffrée pour PERMIT X2
["geo_umap",             "<nip44:...>"]  — géo UMAP (0.01°), chiffrée pour PERMIT X3
["requires",             "PERMIT_*_X1"]  — niveau minimum pour utiliser l'objet
["maintenance_craft",    "<craft-id>"]   — recette Kind 30500 de maintenance
["maintenance_interval", "P6M"]          — intervalle ISO 8601 entre maintenances
["evolves_to",           "<object-id>"]  — forme évoluée (lien vers Kind 30505)
["evolved_from",         "<object-id>"]  — forme précédente
["produced_by",          "<craft-id>"]   — recette qui a produit cet objet
["produced_by_pubkey",   "<hex64>"]
["collaborator",         "<hex64>", "<object-id-fourni>"]
["doc",                  "ipfs://<CID>"] — documentation, plan, notice entretien
["r",                    "<url>"]        — référence externe
["e",                    "<event-id>", "", "maintenance"]  — dernier event de maintenance
```

---

## Modèle de quantité — quatre régimes

### 1. `discrete` — stock comptable

Objets qui se consomment ou s'utilisent en nombre entier.

```json
{ "quantity": 10, "quantity_type": "discrete", "quantity_unit": "unit" }
```

- Mutation : `quantity` décrémente (consommation) ou incrémente (acquisition)
- `durability` : optionnel (si les unités peuvent se dégrader)
- Exemples : câbles XLR, composants électroniques, vis, filtres

### 2. `capacity` — slots simultanés

Objets qui accueillent N utilisateurs simultanés sans se "vider".

```json
{ "quantity": 8, "quantity_type": "capacity", "quantity_unit": "seat" }
```

- `quantity` = capacité maximale (inchangée sauf rénovation)
- `durability` = santé structurelle (ce qui se dégrade)
- Mutation classique : `durability` décroît ; la capacité reste stable
- Exemples : cabane (8 places), studio d'enregistrement (2 postes), serveur (N slots)

### 3. `durability` — objet unique qui se dégrade

Objet singulier (qty = 1 logiquement) dont seule la santé évolue.

```json
{ "quantity": 1, "quantity_type": "durability", "quantity_unit": "unit", "durability": 72 }
```

- `quantity` reste à 1 (sauf destruction → 0 ou évolution → remplacé)
- `durability` : 100 (neuf) → 0 (hors service)
- Exemples : RPi Zero 2W, vélo, outil de précision, instrument

### 4. `infinite` — commons immatériels

Connaissances, recettes, code : partagés sans dépletion.

```json
{ "quantity": null, "quantity_type": "infinite", "quantity_unit": null }
```

- Aucune mutation de stock possible
- `durability` représente la *pertinence* (peut décroître si obsolète)
- Exemples : documentation, algorithme, recette culinaire, partition musicale

---

## Quorum d'opérateurs (`min_operators`)

Certaines opérations requièrent plusieurs MULTIPASS présents simultanément.

Sur **Kind 30505** : `min_operators` = nombre minimum de détenteurs du PERMIT requis pour *utiliser* l'objet.

Sur **Kind 30500** (craft) : chaque rôle d'opérateur est déclaré explicitement :

```
["min_operators",   "3"]
["operator_role",   "0", "PERMIT_SOUND_SPOT_INSTALL_X2", "Technicien principal"]
["operator_role",   "1", "PERMIT_BASH_X1",               "Assistant (tient la pièce)"]
["operator_role",   "2", "PERMIT_AUDIO_ENGINEERING_X1",  "Ingénieur son (validation)"]
```

Ce modèle crée le **crafting social** : certains crafts ne peuvent se déclencher que si le quorum est réuni. TrocZen mobile gère le scan simultané de N MULTIPASS.

---

## Modèle de durabilité — trois drivers universels

`durability` (0–100) s'applique à **tous les types d'objet** avec la même logique,
seuls les paramètres varient selon la nature de l'objet.

### Seuils d'action collective

```
80–100  ✅ Optimal       — usage libre, pas d'alerte
60– 79  🟡 Bon           — maintenance légère recommandée
40– 59  🟠 Dégradé       — maintenance requise, capacité réduite de 25 %
20– 39  🔴 Urgent        — quorum min_operators × 2, usage restreint
 0– 19  ⛔ Hors service  — seul un craft d'évolution ou refondation autorisé
```

---

### Driver 1 — Usure par usage (Kind 1500 → Kind 1505 t=degradation)

Déclenché à chaque session (Kind 1500). Le delta est calculé par l'opérateur et publié en Kind 1505 juste après la session.

```
Δdur_usage = -(occupants / capacity) × (hours / 24) × (1 / repairability)
```

Pour un objet `discrete` (pas de notion de capacité) :
```
Δdur_usage = -(units_consumed / total_stock_reference) × (1 / repairability)
```

Pour un objet `infinite` (knowledge) : aucune usure par usage — au contraire,
chaque citation dans un Kind 1500 (`uses_doc` tag) ajoute +0.1 de pertinence.

**Exemples numériques :**

| Objet | rep | capacity | Session | Δdur/session |
|-------|-----|---------|---------|-------------|
| Cabane bois | 9 | 8 places | 4p × 4h | −0.009 % |
| Studio son | 7 | 2 postes | 2p × 3h | −0.089 % |
| RPi Zero 2W | 7 | 1 (usage continu) | 1p × 8h | −0.048 % |
| Câble XLR | 3 | — | −1 unité sur 10 | −0.033 % |
| Documentation | ∞ | — | citation | +0.1 % |

---

### Driver 2 — Dégradation passive (temps + environnement)

Indépendante de l'usage : intempéries, humidité, obsolescence, vieillissement.
Calculée et publiée lors de chaque event Kind 1505 `t=degradation` ou lors d'une maintenance.

```
Δdur_passive/mois = -(50 / repairability) / 12  ×  attention_multiplier
```

| repairability | Passive/an | Durée de vie sans maintenance |
|--------------|-----------|-------------------------------|
| 0 (jetable) | −∞ % | usage unique |
| 1 | −50 %/an | 2 ans |
| 3 (câble) | −17 %/an | 6 ans |
| 5 (enceinte) | −10 %/an | 10 ans |
| 7 (RPi, vélo) | −7 %/an | 14 ans |
| 9 (cabane bois) | −5.5 %/an | 18 ans |
| 10 (pierre, métal) | −5 %/an | 20 ans |

Pour `infinite` (knowledge), la passive simule l'**obsolescence** :
```
Δdur_passive/an = -2 %  (documentation technique)
Δdur_passive/an = -0.5 % (principes fondamentaux)
```
Remonte quand quelqu'un le met à jour (Kind 30505 re-publié avec explication).

---

### Driver 3 — Attention bonus (l'usage actif protège)

**Principe clé pour les communs** : un bien utilisé régulièrement est surveillé.
Les petits problèmes sont repérés et réparés avant de devenir graves.
Un bien abandonné se dégrade PLUS vite que s'il était utilisé.

```
attention_multiplier =
  1.5   si aucun Kind 1500 dans les 3 derniers mois  (bien abandonné → accélère la dégradation)
  1.0   si usage normal (1+ session/mois)
  0.7   si usage fréquent (4+ sessions/mois, surveillance active → ralentit la dégradation)
```

**Effet sur la cabane-33** (rep=9) :
- Abandonnée hiver : −5.5 % × 1.5 = **−8.3 %/an** passive
- Utilisée 1×/mois : −5.5 % × 1.0 = **−5.5 %/an** passive
- Atelier actif (4×/mois) : −5.5 % × 0.7 = **−3.9 %/an** passive

→ L'usage régulier est une forme de **contribution aux communs**. La gouvernance
émerge de la physique du modèle : délaisser un bien commun accélère sa perte.

---

### Récupération — Maintenance et évolution

```
Δdur_maintenance = +(maintenance_intensity × repairability) / 10
```

| maintenance_intensity | Exemple | Gain cabane rep=9 | Gain RPi rep=7 |
|----------------------|---------|-------------------|----------------|
| 2 | Inspection visuelle | +1.8 % | +1.4 % |
| 5 | Petite réparation | +4.5 % | +3.5 % |
| 8 | Travaux sérieux | +7.2 % | +5.6 % |
| 10 | Remise à neuf complète | +9.0 % | +7.0 % |

Un objet à rep=9 récupère beaucoup mieux qu'un objet à rep=3 (max +3 % par
maintenance) — réparabilité élevée = commons résilient.

Le niveau de PERMIT de l'opérateur conditionne l'`intensity` maximale accessible :
- X1 → intensity max 3 (inspection, nettoyage)
- X2 → intensity max 6 (réparation technique)
- X3 → intensity max 10 (refonte, évolution)

**Évolution** : quand un craft produit une nouvelle forme de l'objet (Kind 30505 `evolved_from`),
`durability` repart à 100 pour le nouvel objet.

---

### Application par type d'objet

| quantity_type | qty mute ? | dur mute ? | Driver principal | Attention bonus |
|--------------|-----------|-----------|-----------------|----------------|
| `discrete` | ✅ (consommation) | ✅ (qualité restante) | Usage (qty−) | Faible |
| `capacity` | ❌ (fixe) | ✅ (usure structurelle) | Passif + usage | ✅ Fort |
| `durability` | ❌ (logiquement 1) | ✅ (santé de l'unique) | Usage + passif | ✅ Fort |
| `infinite` | ❌ | ✅ (pertinence) | Obsolescence passée | Inversé : usage +dur |

---

### Paramètres à déclarer dans Kind 30505

```
["repairability",         "9"]     — 0-10
["lifespan_ref",          "P18Y"]  — durée de vie de référence ISO 8601
["passive_rate",          "5.5"]   — % décroissance/an sans usage ni maintenance
["usage_rate_formula",    "occupants_capacity_hours"]  — formule applicable
["attention_threshold",   "P3M"]   — délai après lequel le bien est considéré abandonné
```

Ces paramètres permettent à tout client (TrocZen, MineLife, cabine-33) de **calculer localement**
le delta à publier dans le prochain Kind 1505, sans dépendre d'un oracle centralisé.

---

`repairability` (0–10) — référence :

| Score | Signification | Exemple |
|-------|--------------|---------|
| 0 | Jetable, non réparable | Pile alcaline |
| 3 | Remplacement partiel possible | Câble USB |
| 5 | Réparable par quelqu'un de compétent | Enceinte BT |
| 7 | Bien réparable, pièces accessibles | Vélo, RPi |
| 9 | Très réparable, matériaux locaux | Cabane bois |
| 10 | Totalement réparable / upgradable | Structure pierre, maison |

La `maintenance_craft` pointe vers une recette Kind 30500 dédiée à la maintenance :
- Input : l'objet à durability X + matériaux consommables
- Output : même objet à durability Y (tendance 100)

---

## Kind 1505 — Journal de transactions

Kind régulier (append-only) — toutes les versions sont conservées.

```json
{
  "kind": 1505,
  "content": "{\"delta_quantity\":-2,\"delta_durability\":-5,\"quantity_after\":8,\"durability_after\":80,\"reason\":\"craft sound-spot-dj session 2026-05-30\",\"operators\":[\"PUBKEY_TOTO\",\"PUBKEY_JEAN\"]}",
  "tags": [
    ["d",                "xlr-cables-jean"],
    ["e",                "<30505-event-id>", "", "object"],
    ["p",                "<craft-initiator-pubkey>"],
    ["t",                "consumption"],
    ["delta_quantity",   "-2"],
    ["delta_durability", "-5"],
    ["quantity_after",   "8"],
    ["durability_after", "80"],
    ["operator",         "PUBKEY_TOTO"],
    ["operator",         "PUBKEY_JEAN"]
  ]
}
```

### Types de transaction (`t` tag)

| Valeur | Sens |
|--------|------|
| `acquisition`  | Stock augmente (achat, don, fabrication) |
| `consumption`  | Stock diminue (usage dans un craft) |
| `transfer`     | Changement de détenteur |
| `maintenance`  | Durability augmente (réparation, entretien) |
| `degradation`  | Durability diminue (usure constatée) |
| `creation`     | Premier event — objet produit par un craft |
| `evolution`    | L'objet devient une forme plus avancée |
| `retirement`   | qty → 0 ou durability → 0, objet retiré |

### Requêtes relay

```
// État courant (1 event par objet) — O(1)
REQ { "kinds": [30505], "authors": ["<pubkey>"], "#d": ["<object-id>"] }

// Historique complet (toutes mutations)
REQ { "kinds": [1505], "#d": ["<object-id>"] }

// Toutes les transactions d'un opérateur
REQ { "kinds": [1505], "#p": ["<pubkey>"] }
```

---

## Kind 1500 — Log d'exécution de craft

Enregistre une session de craft réelle (durée mesurée, opérateurs présents, résultats).

```json
{
  "kind": 1500,
  "content": "{\"craft_id\":\"sound-spot-basic\",\"duration_actual\":\"PT5H30M\",\"duration_estimated\":\"PT4H\",\"success\":true,\"notes\":\"Canal WiFi a nécessité ajustement manuel\",\"iteration\":2}",
  "tags": [
    ["d",         "sound-spot-basic-exec-20260530"],
    ["e",         "<30500-craft-event-id>", "", "recipe"],
    ["t",         "craft-execution"],
    ["craft",     "sound-spot-basic"],
    ["operator",  "PUBKEY_TOTO", "PERMIT_SOUND_SPOT_INSTALL_X1"],
    ["operator",  "PUBKEY_COUCOU", "PERMIT_RASPBERRY_PI_X1"],
    ["consumed",  "rpi-zero2w-zicmama", "PUBKEY_TOTO", "0"],
    ["consumed",  "bt-speaker-zicmama",  "PUBKEY_TOTO", "0"],
    ["produced",  "PERMIT_SOUND_SPOT_INSTALL_X1", "PUBKEY_TOTO"],
    ["duration",  "PT5H30M"],
    ["iteration", "2"]
  ]
}
```

Les logs Kind 1500 permettent d'**optimiser les recettes** : en agrégeant les durées réelles sur N exécutions, le système calcule une durée médiane et peut suggérer des améliorations de process.

---

## Kind 30500 enrichi — Quorum + Rôles + Maintenance

```
["d",                 "<craft-id>"]
["title",             "<nom lisible>"]
["t",                 "craft | maintenance | evolution"]
["min_operators",     "2"]
["operator_role",     "0", "PERMIT_X", "Rôle principal"]
["operator_role",     "1", "PERMIT_Y", "Rôle support"]
["requires_skill",    "PERMIT_*_Xn"]
["requires_object",   "<object-id>", "<pubkey-owner>"]
["produces_permit",   "PERMIT_*_Xn"]     — optionnel
["produces_object",   "<object-id>", "<type>", "<mobility>", "<qty>", "<qty_type>"]  — optionnel
["consumes_object",   "<object-id>", "<qty-consumed>"]   — matériaux consommés
["estimated_time",    "PT4H"]            — ISO 8601 duration
["step",              "1", "Description étape 1"]
["step",              "2", "Description étape 2"]
```

---

## Géo-révélation progressive (trust-gated)

Les coordonnées précises d'un objet fixe sont révélées progressivement.

```
["geo",        "REGION:44:2"]               — public (1° ≈ 100km)
["geo_sector", "<nip44-encrypted:44.0:2.0>"] — PERMIT X2 requis (0.1° ≈ 10km)
["geo_umap",   "<nip44-encrypted:44.02:2.03>"] — PERMIT X3 requis (0.01° ≈ 1km)
```

Le chiffrement NIP-44 cible la clé publique NOSTR du détenteur du PERMIT correspondant (ou du groupe). Seul le client qui a le PERMIT peut déchiffrer le tag.

---

## Exemple complet — Son-spot + Cabane-33

### Objet : Cabane en bois (capacity, repairability=9)

```json
{
  "kind": 30505,
  "content": "{\"name\":\"Cabane 33 — Atelier collectif\",\"type\":\"capacity\",\"mobility\":\"fixed\",\"quantity\":8,\"quantity_type\":\"capacity\",\"quantity_unit\":\"seat\",\"durability\":80,\"repairability\":9,\"condition\":\"operational\",\"min_operators\":1,\"description\":\"Espace de fabrication et de rencontre. 8 postes de travail. Charpente bois, réparable localement.\"}",
  "tags": [
    ["d",                    "cabane-33"],
    ["title",                "Cabane 33 — Atelier collectif"],
    ["t",                    "capacity"], ["t", "fixed"], ["t", "infrastructure"],
    ["quantity",             "8"],
    ["quantity_unit",        "seat"],
    ["durability",           "80"],
    ["repairability",        "9"],
    ["min_operators",        "1"],
    ["geo",                  "REGION:44:2"],
    ["geo_sector",           "<nip44:PERMIT_CABANE33_X2:44.0:2.0>"],
    ["geo_umap",             "<nip44:PERMIT_CABANE33_X3:44.02:2.03>"],
    ["requires",             "PERMIT_CABANE33_X1"],
    ["maintenance_craft",    "cabane-33-maintenance"],
    ["maintenance_interval", "P1Y"],
    ["evolves_to",           "cabane-33-v2-isolation"],
    ["doc",                  "ipfs://QmCabane33Plans"]
  ]
}
```

### Craft de maintenance : cabane-33-maintenance

```json
{
  "kind": 30500,
  "content": "{\"name\":\"Maintenance Cabane 33\",\"description\":\"Inspection charpente + traitement bois + vérification toiture. Remet durability à 90+.\",\"estimated_time\":\"PT6H\",\"difficulty\":2}",
  "tags": [
    ["d",               "cabane-33-maintenance"],
    ["title",           "Maintenance Cabane 33"],
    ["t",               "maintenance"],
    ["min_operators",   "2"],
    ["operator_role",   "0", "PERMIT_CABANE33_X2", "Charpentier référent"],
    ["operator_role",   "1", "PERMIT_CABANE33_X1", "Assistant"],
    ["requires_skill",  "PERMIT_CABANE33_X2"],
    ["requires_object", "cabane-33", "PUBKEY_OWNER"],
    ["consumes_object", "bois-traitement", "2"],
    ["consumes_object", "huile-saturateur", "1"],
    ["produces_object", "cabane-33", "capacity", "fixed", "8", "capacity"],
    ["estimated_time",  "PT6H"],
    ["step", "1", "Inspection visuelle charpente et toiture"],
    ["step", "2", "Traitement bois anti-humidité (consomme 2 litres huile)"],
    ["step", "3", "Vérification joints et étanchéité"],
    ["step", "4", "Rapport durability → Kind 1505 t=maintenance"]
  ]
}
```

### Craft d'évolution : isolation thermique

```json
{
  "kind": 30500,
  "content": "{\"name\":\"Isolation Cabane 33\",\"description\":\"Upgrade isolation thermique. Transforme Cabane 33 en Cabane 33 v2 (durability reset à 100, capacité inchangée, confort hivernal).\",\"estimated_time\":\"P2D\",\"difficulty\":3}",
  "tags": [
    ["d",               "cabane-33-isolation"],
    ["title",           "Isolation thermique Cabane 33"],
    ["t",               "evolution"],
    ["min_operators",   "3"],
    ["operator_role",   "0", "PERMIT_CABANE33_X3", "Maître d'œuvre"],
    ["operator_role",   "1", "PERMIT_CABANE33_X2", "Second"],
    ["operator_role",   "2", "PERMIT_CABANE33_X1", "Manœuvre"],
    ["requires_skill",  "PERMIT_CABANE33_X3"],
    ["requires_object", "cabane-33", "PUBKEY_OWNER"],
    ["consumes_object", "laine-de-bois", "50"],
    ["consumes_object", "pare-vapeur",   "30"],
    ["produces_object", "cabane-33-v2-isolation", "capacity", "fixed", "8", "capacity"],
    ["estimated_time",  "P2D"],
    ["step", "1", "Dépose bardage intérieur"],
    ["step", "2", "Pose laine de bois 100mm entre montants"],
    ["step", "3", "Pose pare-vapeur agrafé"],
    ["step", "4", "Repose bardage"],
    ["step", "5", "Émettre Kind 30505 cabane-33-v2-isolation (evolved_from: cabane-33)"]
  ]
}
```

---

## Exemple complet — sound-spot avec mutations

### RPi Zero 2W — durability = 1 objet unique

```json
{
  "kind": 30505,
  "content": "{\"name\":\"Station ZICMAMA — RPi Zero 2W\",\"type\":\"infrastructure\",\"mobility\":\"fixed\",\"quantity\":1,\"quantity_type\":\"durability\",\"quantity_unit\":\"unit\",\"durability\":92,\"repairability\":7,\"condition\":\"operational\",\"min_operators\":1,\"description\":\"Nœud maître sound-spot. Réparable : carte SD interchangeable, alimentation remplaçable.\"}",
  "tags": [
    ["d",                    "rpi-zero2w-zicmama"],
    ["title",                "Station ZICMAMA — RPi Zero 2W"],
    ["t",                    "infrastructure"], ["t", "fixed"], ["t", "durability"],
    ["quantity",             "1"],
    ["quantity_unit",        "unit"],
    ["durability",           "92"],
    ["repairability",        "7"],
    ["min_operators",        "1"],
    ["geo",                  "REGION:44:2"],
    ["geo_sector",           "<nip44:PERMIT_SOUND_SPOT_INSTALL_X2:44.0:2.0>"],
    ["geo_umap",             "<nip44:PERMIT_SOUND_SPOT_INSTALL_X3:44.02:2.03>"],
    ["requires",             "PERMIT_SOUND_SPOT_INSTALL_X1"],
    ["maintenance_craft",    "rpi-zero2w-maintenance"],
    ["maintenance_interval", "P1Y"],
    ["evolves_to",           "rpi-5-zicmama"],
    ["model",                "Raspberry Pi Zero 2W"],
    ["weight",               "9g"],
    ["size",                 "65x30x5mm"],
    ["doc",                  "ipfs://QmRPiZero2WSpecs"]
  ]
}
```

### Câbles XLR — discrete = consommables

```json
{
  "kind": 30505,
  "content": "{\"name\":\"Câbles audio XLR 3m\",\"type\":\"material\",\"mobility\":\"mobile\",\"quantity\":10,\"quantity_type\":\"discrete\",\"quantity_unit\":\"unit\",\"durability\":100,\"repairability\":3,\"condition\":\"new\",\"min_operators\":1}",
  "tags": [
    ["d",            "xlr-cables-jean"],
    ["title",        "Câbles audio XLR 3m"],
    ["t",            "material"], ["t", "mobile"], ["t", "discrete"], ["t", "consumable"],
    ["quantity",     "10"],
    ["quantity_unit","unit"],
    ["durability",   "100"],
    ["repairability","3"],
    ["weight",       "200g"],
    ["size",         "3m"]
  ]
}
```

### Transaction Kind 1505 — après un craft DJ (−2 câbles utilisés, durability −3)

```json
{
  "kind": 1505,
  "content": "{\"delta_quantity\":-2,\"delta_durability\":-3,\"quantity_after\":8,\"durability_after\":97,\"reason\":\"craft sound-spot-dj session 2026-05-30\"}",
  "tags": [
    ["d",                "xlr-cables-jean"],
    ["e",                "<30505-event-id-xlr>", "", "object"],
    ["e",                "<1500-exec-event-id>", "", "session"],
    ["t",                "consumption"],
    ["delta_quantity",   "-2"],
    ["delta_durability", "-3"],
    ["quantity_after",   "8"],
    ["durability_after", "97"],
    ["operator",         "PUBKEY_JEAN"],
    ["operator",         "PUBKEY_TOTO"]
  ]
}
```

---

## Résumé — Vue d'ensemble du cycle de vie

```
ACQUISITION          UTILISATION           MAINTENANCE           ÉVOLUTION
    │                    │                     │                    │
Kind 30505          Kind 1505             Kind 1505            Kind 30500
(qty=10, dur=100)   t=consumption         t=maintenance        t=evolution
                    (qty=8, dur=97)       (dur: 40→75)
                         │                                          │
                    Kind 1500                                  Kind 30505
                    (log session)                              (evolved_from)
                         │
                    Kind 30505 MIS À JOUR
                    (qty=8, dur=97)
                    [replaceable → 1 seul event relay]
```

**Performance relay** :
- État courant : `REQ {kinds:[30505]}` → 1 event par objet (O(1), parameterized replaceable)
- Historique : `REQ {kinds:[1505], "#d":["<id>"]}` → tous les deltas (append-only)
- Sessions : `REQ {kinds:[1500], "#e":["<30500-id>"]}` → toutes les exécutions d'une recette

---

## Intégration dans le protocole WoTx²

```
MULTIPASS A                    MULTIPASS B                    MULTIPASS C
────────────────────           ────────────────────           ────────────────────
Kind 30503 (skills)            Kind 30503 (skills)            Kind 30503 (skills)
  PERMIT_BASH_X1                 PERMIT_RASPBERRY_PI_X1         PERMIT_MIXXX_X1

Kind 30505 (objects)           Kind 30505 (objects)           Kind 30505 (objects)
  rpi-zero2w (dur=92)            wifi-dongle (qty=1)            mixxx-station
  bt-speaker (qty=2)                                            xlr-cables (qty=10)
          │                              │                              │
          └──────────────────────────────┴──────────────────────────────┘
                                         │
                              Kind 30500 (craft recipe)
                              sound-spot-master
                              min_operators: 3
                              requires_skill: PERMIT_*_X1 ×3
                              requires_object: rpi + wifi + mixxx
                              consumes_object: xlr-cables −2
                                         │
                              Kind 1500 (session log)
                              operators: [A, B, C]
                              duration_actual: PT5H30M
                                         │
                              Kind 30505 produit
                              sound-spot-node-zicmama
                              (produced_by: A, collaborators: B, C)
                                         │
                              Kind 30503 produit
                              PERMIT_SOUND_SPOT_INSTALL_X3
                              (pour chaque opérateur)
```

---

## Références

- `Astroport.ONE/tools/emit_skill.sh` — Émet Kind 30503 (modèle à suivre pour emit_object.sh)
- `NOSTR_EVENTS_REFERENCE.md` — Table exhaustive des kinds UPlanet
- `WOTX2_SYSTEM.md` — Architecture WoTx² (rules A/B/C, Oracle, P2P)
- `how-to/MINELIFE.md` — Interface craft utilisateur
- `sound-spot/` — Projet de référence (infrastructure sound-spot comme cas d'usage)
- `cabine-33/` — Projet Godot utilisant les objets WoTx² (atelier collectif)
