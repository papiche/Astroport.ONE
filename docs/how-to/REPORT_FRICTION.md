# Comment déclarer une friction et suivre la médiation

Ce guide couvre le cycle complet depuis la déclaration d'un désaccord jusqu'à la résolution (amiable ou arbitrage formel).

---

## Pré-requis

- Vous êtes **MULTIPASS** (identité vérifiée)
- La partie adverse est également **MULTIPASS**
- Vous avez accès à un client NOSTR (coracle, Snort, Amethyst…) ou à la CLI station

---

## Étape 1 — Déclarer la friction (Kind 1984)

### Via l'interface web (minelife.html)

1. Ouvrez **minelife.html** → onglet **Justice**
2. Cliquez sur **Déclarer une friction**
3. Remplissez :
   - **Partie adverse** : npub ou nom de l'utilisateur
   - **Raison** : description courte du désaccord
   - **Objet impliqué** (optionnel) : sélectionner dans votre liste Kind 30505
   - **Compétence requise** (optionnel) : ex. `permis-conduire-vehicule:x2`
   - **Montant demandé** : en ẐEN (détermine automatiquement le circuit N1 ou N2)

### Via la CLI station

```bash
# Depuis la station du plaignant
nostr_node_intercom.py send \
  --kind 1984 \
  --tags '[
    ["report-type", "friction"],
    ["p", "<HEX_DEFENDEUR>"],
    ["reason", "Usage voiture sans permis x2 validé"],
    ["object", "voiture-partagee-5-places-jean"],
    ["skill", "permis-conduire-vehicule:x2"],
    ["friction-amount", "5"]
  ]' \
  --content "Jean a utilisé la voiture partagée sans disposer du permis WoT x2 requis."
```

### Structure de l'event

```json
{
  "kind": 1984,
  "tags": [
    ["report-type", "friction"],
    ["p", "<defendeur_hex>"],
    ["reason", "Usage d'un objet partagé sans niveau WoT requis"],
    ["object", "<dtag_du_kind_30505>"],
    ["skill", "permis-conduire-vehicule:x2"],
    ["friction-amount", "5"]
  ],
  "content": "Description narrative du désaccord"
}
```

---

## Étape 2 — Ouverture automatique du dossier

Le relay **1984.sh** détecte le tag `report-type=friction` et :

1. Journalise le cas dans `~/.zen/tmp/justice_cases.log`
2. Déclenche `ASTROBOT/N1Mediation.sh` (asynchrone)

`N1Mediation.sh` crée automatiquement un **Kind 30506** (dossier de médiation) :

```json
{
  "kind": 30506,
  "tags": [
    ["d", "friction-<plaignant6>-<défendeur6>-<timestamp>"],
    ["t", "friction"],
    ["status", "N1_ouvert"],
    ["p", "<plaignant_hex>", "role:plaignant"],
    ["p", "<défendeur_hex>", "role:défendeur"],
    ["reparation", "5"]
  ]
}
```

Vous recevrez une notification (Kind 1 ou DM) avec l'identifiant du dossier.

---

## Étape 3 — Médiation N1 (cercle direct)

Vos contacts communs avec la partie adverse reçoivent une notification. Chaque médiateur peut voter via un **Kind 1506** :

```json
{
  "kind": 1506,
  "tags": [
    ["d", "friction-<case_id>"],
    ["t", "vote_amiable"]
  ],
  "content": "{\"action\":\"vote_amiable\",\"vote\":\"+1\",\"note\":\"Accord sur 5 ẐEN\"}"
}
```

- `+1` : pour l'indemnisation du plaignant
- `-1` : contre (désaccord sur la responsabilité)

**Règle de résolution N1** : majorité simple des votes exprimés dans les 72h.

### Suivre les votes

```bash
# Via le dashboard CLI
./admin/dashboard.JUSTICE.manager.sh list-acts friction-<case_id>

# Via strfry query directe
cd ~/.zen/strfry && ./strfry scan \
  '{"kinds":[1506],"#d":["friction-<case_id>"]}' | jq .
```

---

## Étape 4a — Résolution N1

Si majorité de votes `+1` et montant ≤ 10 ẐEN :

1. L'oracle publie un **Kind 1506** `action=resolution`
2. Un **Kind 7** (`+5`) est émis vers le wallet du plaignant depuis la TRÉSORERIE station
3. Le dossier **Kind 30506** est mis à jour : `status=N1_résolu`

Vous recevez une notification de résolution et le ẐEN est crédité dans les minutes suivantes.

---

## Étape 4b — Escalade N2 (> 10 ẐEN ou désaccord N1)

Si le montant dépasse 10 ẐEN ou si la médiation N1 échoue :

1. Un **Kind 1506** `action=escalade_N2` est publié
2. Le dossier passe à `status=N2_ouvert`
3. Cinq membres titrés (PERMIT X2+) sont sélectionnés depuis `amisOfAmis.txt`
4. Une fenêtre d'arbitrage de **7 jours** s'ouvre

Le panel N2 peut demander des preuves supplémentaires (IPFS CID de photos, logs, témoignages). Les membres votent individuellement via Kind 1506 `action=verdict`.

---

## Étape 5 — Verdict N2

Après délibération, le panel publie le verdict :

```json
{
  "kind": 1506,
  "content": "{\"action\":\"verdict\",\"vote\":\"+1\",\"note\":\"Présomption de faute retenue (permis x2 requis, non détenu). Indemnisation: 15 ẐEN.\",\"reparation_zen\":15}"
}
```

- Si verdict positif : réparation exécutée (Kind 7), dossier → `N2_résolu`
- Si verdict négatif : dossier → `classé` (sans indemnisation)

---

## Consulter l'historique d'un dossier

```bash
# État courant du dossier
./admin/dashboard.JUSTICE.manager.sh show friction-<case_id>

# Journal complet des actes
./admin/dashboard.JUSTICE.manager.sh list-acts friction-<case_id>

# Tous les dossiers ouverts
./admin/dashboard.JUSTICE.manager.sh list-open

# Tableau de bord général
./admin/dashboard.JUSTICE.manager.sh stats
```

---

## Objets avec `skill_required`

Si l'objet impliqué porte le tag `["skill_required", "skill:niveau"]`, ce tag **pèse dans la médiation** :

- En N1 : les médiateurs voient le tag et pondèrent leur vote en conséquence
- En N2 : créé une présomption de faute si le défendeur ne possède pas le niveau requis

Vous pouvez vérifier les exigences d'un objet :

```bash
# Via relay query
cd ~/.zen/strfry && ./strfry scan \
  '{"kinds":[30505],"#d":["<object-id>"]}' | jq '.tags[] | select(.[0]=="skill_required")'
```

---

## Références

- **[explanation/WOTX2_MEDIATION.md](../explanation/WOTX2_MEDIATION.md)** — Philosophie du système
- **[reference/KIND_30506_JUSTICE.md](../reference/KIND_30506_JUSTICE.md)** — Spec technique
- **[reference/KIND_30505_OBJECTS.md](../reference/KIND_30505_OBJECTS.md)** — Tag `skill_required`
- `admin/dashboard.JUSTICE.manager.sh` — CLI admin médiation
- `nostr-nips/56-friction-mediation-extension.md` — Extension protocole NIP-56
