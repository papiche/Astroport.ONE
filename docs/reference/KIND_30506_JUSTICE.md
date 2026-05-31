# Kind 30506 / 1506 — Protocole Justice & Assurance WoTx2

## Introduction

Le protocole Justice UPlanet repose sur les **Bourgades de Confiance** : le cercle N1 (jusqu'à ~100 contacts directs, défini par Kind 3) assure la médiation amiable, et le cercle N2 (~10 000 amis des amis via `~/.zen/strfry/amisOfAmis.txt`) intervient pour l'arbitrage formel. Ce modèle remplace l'assurance centralisée par une **assurance mutualiste** fondée sur la WoT (Web of Trust).

```
Kind 1984 (report-type=friction)
  │
  ▼
relay 1984.sh → log + notification N1
  │
  ▼
Kind 30506 créé (status=N1_ouvert, signé oracle)
  │
  ├─► N1 notifié (contacts communs dans amisOfAmis.txt)
  │     └─► médiateurs publient Kind 1506 (vote_amiable)
  │
  ├─► [résolution] Kind 30506 mis à jour (status=N1_résolu)
  │
  └─► [escalade]  Kind 30506 mis à jour (status=N2_ouvert)
                  └─► 5 membres N2 titrés → Kind 1506 (verdict)
```

---

## Nouveaux kinds

| Kind | Type NIP-33 | Rôle |
|------|-------------|------|
| **30506** | Parameterized replaceable (NIP-33) | Dossier de médiation — état courant |
| **1506**  | Regular (append-only) | Journal du dossier — actes, votes, escalades |

---

## Kind 30506 — Dossier de Médiation

### Content JSON (obligatoire)

```json
{
  "title": "Friction: usage véhicule partagé",
  "status": "N1_ouvert",
  "level": "N1",
  "description": "Désaccord sur les conditions d'utilisation d'un véhicule partagé",
  "resolution": null,
  "reparation_zen": 0,
  "created_at": "2026-05-31T12:00:00Z"
}
```

**Valeurs du champ `status`** :

| Valeur | Signification |
|--------|---------------|
| `N1_ouvert` | Médiation amiable en cours (cercle direct) |
| `N1_résolu` | Résolution amiable obtenue en N1 |
| `N2_ouvert` | Escalade vers arbitrage formel (cercle élargi) |
| `N2_résolu` | Verdict formel rendu en N2 |
| `classé` | Dossier clôturé sans suite |

**Valeurs du champ `level`** : `N1` | `N2`

### Tags obligatoires

| Tag | Valeur | Description |
|-----|--------|-------------|
| `d` | slug unique | `case_id` — identifiant du dossier (ex: `friction-voiture-2026-05-31-abc`) |
| `t` | `friction` | Marqueur de type |
| `status` | valeur courante | Copie du status pour filtrage relay |
| `p` | pubkey + `role:plaignant` | Partie plaignante |
| `p` | pubkey + `role:défendeur` | Partie défenderesse |
| `e` | event_id | Kind 1984 d'origine déclencheur |

### Tags optionnels

| Tag | Valeur | Description |
|-----|--------|-------------|
| `object` | dtag Kind 30505 | Objet impliqué dans la friction |
| `skill` | `skill_id:niveau` | Compétence requise non détenue |
| `reparation` | montant ẐEN | Montant de réparation demandé ou accordé |

### Exemple complet

```json
{
  "kind": 30506,
  "pubkey": "<oracle_hex>",
  "tags": [
    ["d", "friction-voiture-2026-05-31-abc"],
    ["t", "friction"],
    ["status", "N1_ouvert"],
    ["p", "<coucou_hex>", "role:plaignant"],
    ["p", "<jean_hex>",   "role:défendeur"],
    ["e", "<event_id_1984>"],
    ["object", "voiture-partagee-5-places-jean"],
    ["skill", "permis-conduire-vehicule:x2"],
    ["reparation", "5"]
  ],
  "content": "{\"title\":\"Friction: usage véhicule partagé\",\"status\":\"N1_ouvert\",\"level\":\"N1\",\"description\":\"Utilisation voiture partagée sans permis x2 WoT validé\",\"resolution\":null,\"reparation_zen\":0,\"created_at\":\"2026-05-31T12:00:00Z\"}"
}
```

---

## Kind 1506 — Journal d'Acte

### Content JSON

```json
{
  "action": "vote_amiable",
  "arbitre": "<npub64>",
  "vote": "+1",
  "note": "Accord sur 5 ẐEN de dédommagement",
  "reparation_zen": 5
}
```

**Valeurs du champ `action`** :

| Valeur | Signification |
|--------|---------------|
| `N1_ouvert` | Acte d'ouverture du dossier N1 |
| `vote_amiable` | Vote d'un médiateur N1 |
| `escalade_N2` | Décision d'escalade vers N2 |
| `resolution` | Clôture amiable N1 |
| `verdict` | Verdict formel N2 |

### Tags

| Tag | Valeur | Description |
|-----|--------|-------------|
| `d` | case_id | Référence au dossier 30506 |
| `e` | event_id 30506 | Référence à l'état courant du dossier |
| `p` | pubkey plaignant | Partie plaignante |
| `p` | pubkey défendeur | Partie défenderesse |
| `t` | valeur action | Copie du champ action pour filtrage |

### Exemple — vote amiable

```json
{
  "kind": 1506,
  "pubkey": "<mediateur_hex>",
  "tags": [
    ["d",  "friction-voiture-2026-05-31-abc"],
    ["e",  "<event_id_30506>"],
    ["p",  "<coucou_hex>"],
    ["p",  "<jean_hex>"],
    ["t",  "vote_amiable"]
  ],
  "content": "{\"action\":\"vote_amiable\",\"arbitre\":\"<npub64_mediateur>\",\"vote\":\"+1\",\"note\":\"Accord sur 5 ẐEN de dédommagement\",\"reparation_zen\":5}"
}
```

---

## Flux de médiation complet

```
1. Utilisateur publie Kind 1984 (report-type=friction)
   └─► relay 1984.sh détecte le tag report-type=friction
       ├─► Log dans ~/.zen/tmp/justice_cases.log
       └─► (futur) Déclenche ASTROBOT/N1Mediation.sh

2. Oracle crée Kind 30506 (status=N1_ouvert)
   └─► d-tag = "friction-<slug>-<date>-<hash4>"

3. Cercle N1 notifié
   └─► contacts communs plaignant+défendeur dans amisOfAmis.txt
   └─► médiateurs publient Kind 1506 (vote_amiable)

4a. Résolution N1 (≤ 10 ẐEN)
    ├─► Majorité votes_amiable positifs
    ├─► Paiement réparation depuis pool de solidarité (Kind 7 +N)
    └─► Kind 30506 mis à jour (status=N1_résolu)

4b. Escalade N2 (> 10 ẐEN ou désaccord N1)
    ├─► Kind 1506 (action=escalade_N2) publié
    ├─► Kind 30506 mis à jour (status=N2_ouvert, level=N2)
    ├─► 5 membres N2 titrés sélectionnés depuis amisOfAmis.txt
    └─► Délai arbitrage : 7 jours

5. Verdict N2
   ├─► Kind 1506 (action=verdict) publié par panel N2
   ├─► Paiement réparation si verdict positif
   └─► Kind 30506 mis à jour (status=N2_résolu)
```

---

## Modèle d'assurance mutualiste

### Pool de solidarité

Le pool de solidarité est alimenté par la fraction **TRÉSORERIE** du PAF (1/3 selon la règle 3×1/3 dans `ZEN.ECONOMY.sh`). Il n'existe pas d'assureur centralisé.

### Seuils de réparation

| Montant (ẐEN) | Circuit | Quorum |
|---------------|---------|--------|
| ≤ 10 ẐEN | N1 seul (amiable + vote) | Majorité contacts communs |
| > 10 ẐEN | Passage obligatoire N2 (arbitrage formel) | 5 membres N2 |
| > 50 ẐEN | Vote étendu constellation | Assemblée constellation |

### Paiements de réparation

Les réparations sont effectuées via Kind 7 (`+N`) sur le wallet du plaignant, financées depuis le wallet TRÉSORERIE de la station. La trace est enregistrée dans Kind 1506 (action=resolution ou verdict).

---

## Cas d'usage — "Permis de Conduire" WoTx2

### Skill `permis-conduire-vehicule`

| Niveau | Code | Signification |
|--------|------|---------------|
| x1 | Auto-proclamé | Déclaration sur l'honneur (Kind 30503 auto-signé) |
| x2 | Validé par 12 pairs WoT | Équivalent "permis d'exercer" — 12 attestations Kind 30503 peer |
| x3 | Instructeur | Peut attester le niveau x2 pour d'autres utilisateurs |

Le niveau x2 correspond exactement aux **12 attestations WoT** décrites dans l'article "Réinventer la société avec la monnaie libre et la WoT" comme conditions du "permis d'exercer".

### Tag `skill_required` sur Kind 30505

Les objets de transport peuvent exiger un niveau de compétence validé :

```json
["skill_required", "permis-conduire-vehicule:x1"]
```

| Objet | skill_required |
|-------|----------------|
| `voiture-partagee` | `permis-conduire-vehicule:x1` |
| `moto-125cc` | `permis-conduire-vehicule:x1` |
| `voiture-electrique-5places` | `permis-conduire-vehicule:x2` (recommandé pour usage collectif) |

Ce tag est **indicatif** en N1 (médiation amiable) et **contraignant** en N2 (arbitrage formel).

### Friction de démo

- **Plaignant** : coucou — déclare que jean a utilisé la voiture partagée sans `permis-conduire-vehicule:x2` validé
- **Défendeur** : jean — possède `permis-conduire-vehicule:x1` (auto-proclamé) mais pas encore 12 attestations WoT
- **Issue attendue** : médiation N1, accord sur 5 ẐEN de contribution au fonds formation + incitation à valider x2

---

## Intégration NIP-101 (relay 1984.sh)

### Mise à jour de `~/.zen/strfry/filter/1984.sh`

Détecter le tag `report-type=friction` dans les Kind 1984 entrants :

```bash
# Dans 1984.sh — bloc de détection friction
_report_type=$(echo "$EVENT" | jq -r '.tags[] | select(.[0]=="report-type") | .[1]' 2>/dev/null)

if [[ "$_report_type" == "friction" ]]; then
    _plaignant=$(echo "$EVENT" | jq -r '.pubkey')
    _defendeur=$(echo "$EVENT" | jq -r '.tags[] | select(.[0]=="p") | .[1]' | head -1)
    _skill=$(echo "$EVENT" | jq -r '.tags[] | select(.[0]=="skill") | .[1]' 2>/dev/null || echo "")
    _now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    _case_id="friction-${_plaignant:0:8}-$(date +%Y%m%d)-$(echo "$EVENT" | sha256sum | cut -c1-4)"

    # 1. Logger le cas
    echo "${_now}|${_case_id}|${_plaignant}|${_defendeur}|${_skill}" \
        >> ~/.zen/tmp/justice_cases.log

    # 2. (futur) Déclencher N1Mediation si les 2 parties sont MULTIPASS
    # [[ -x "${MY_PATH}/../ASTROBOT/N1Mediation.sh" ]] && \
    #     "${MY_PATH}/../ASTROBOT/N1Mediation.sh" "$_case_id" "$_plaignant" "$_defendeur" &
fi
```

### Futur script `ASTROBOT/N1Mediation.sh`

Ce script (à créer) sera déclenché par `1984.sh` lorsque les deux parties sont des MULTIPASS enregistrés. Il :
1. Vérifie que les deux pubkeys sont dans `~/.zen/game/players/`
2. Crée le Kind 30506 (signé par l'oracle de la station)
3. Identifie les contacts communs dans `amisOfAmis.txt` pour constituer le cercle N1
4. Notifie les médiateurs potentiels via Kind 1 (message de la station)

---

## Synchronisation constellation

Les dossiers de médiation actifs doivent être synchronisés entre les stations impliquées :

```
# Ajouter dans backfill_constellation.sh :
JUSTICE: 30506, 1506
```

Les dossiers `classé` ou `N2_résolu` de plus de 90 jours peuvent être archivés (non synchronisés activement).

---

## Références

- `NIP-101/relay.writePolicy.plugin/filter/1984.sh` — Filtre Kind 1984 (plaintes/reports)
- `~/.zen/strfry/amisOfAmis.txt` — Cercle N2 (amis des amis)
- `Astroport.ONE/RUNTIME/ZEN.ECONOMY.sh` — Règle 3×1/3, pool trésorerie
- `Astroport.ONE/docs/reference/KIND_30505_OBJECTS.md` — Tag `skill_required`
- `Astroport.ONE/docs/reference/NOSTR_EVENTS_REFERENCE.md` — Vue d'ensemble kinds
- NIP-56 (Kind 1984) — Reporting protocol
