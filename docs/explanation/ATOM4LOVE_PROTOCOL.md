# ATOM4LOVE — Le Jeu comme Protocole

## Philosophie : transformer la physique quantique en protocole social

Le système ATOM4LOVE repose sur une idée centrale : les paramètres physiques d'une personne —
date, heure et lieu de naissance, poids, polarité biologique — peuvent être traduits en une
**signature vibratoire** unique, objectivement calculable, et intégrable dans un protocole
décentralisé via NOSTR.

Ce n'est pas de l'ésotérisme : c'est de la cryptographie douce. La "phase personnelle" φ est
une valeur déterministe en radians, calculée par le moteur `Phi2X` (synchronisé entre
`phi2x.js`, `phi2x.py`, et `Phi2X_Math.gd`). Le "taux de cohérence k" entre deux personnes
est une mesure mathématique de l'alignement de leurs ondes.

---

## Niveaux d'intégration

```
┌─────────────────────────────────────────────────────────────────────┐
│  WoT Level 0 — Visiteur Atomique (avant MULTIPASS)                  │
│                                                                      │
│  atomic.html → calcule φ, ω → publie Kind 30078 d=atom4love         │
│  30078.sh → valide a4l_proof + plages → add_to_amis_of_amis()       │
│                                                                      │
│  ↓ bootstrap WoT sans email, sans compte, juste une clé NOSTR       │
└─────────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  WoT Level 1 — MULTIPASS (après inscription)                        │
│                                                                      │
│  g1nostr → make_NOSTRCARD.sh → DID Kind 30800 → amisOfAmis.txt      │
│                                                                      │
│  φ + ω stockés dans DID → lecture par cabine-33 + atomic.html       │
└─────────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  WoT Level 2 — Résonance physique (cabine-33)                       │
│                                                                      │
│  BLE/WiFi scan A4L-* → k ≥ 0.85 → Kind 30508 (Match vibratoire)    │
│  k ≥ 0.95 → Atom4Peace.check_bonds_status() → Kind 30502           │
│  Rituel de Phase (33s) → Kind 30503 skill x1 géolocalisé            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Formules canoniques (cohérentes entre les 3 implémentations)

### Phase personnelle φ_i

```
φ_i = ((t_ann + t_day + penta_offset) × WAVE_STRETCH) mod 2π

où :
  t_ann  = (birthUnix mod ORBITAL_YEAR_S) / ORBITAL_YEAR_S × 2π
  t_day  = ((birthUnix + lon/360 × 86400) mod 86400) / 86400 × 2π
  penta  = atan2(Σ sin(i/12×2π)×exp(-d/1500), Σ cos(i/12×2π)×exp(-d/1500))
  WAVE_STRETCH = F_PHI / F_2 = 33.17 / 31.32 ≈ 1.059
```

φ_i ∈ [0, 2π) ≈ [0, 6.28) — toujours < 7 (condition du filtre strfry)

### Fréquence biologique ω_bio

```
ω_bio = F_WATER × (weight_kg × water_ratio / 70)

où :
  F_WATER    = 429.62 Hz
  water_ratio = 0.65 (polarité Φ/Homme) | 0.60 (polarité ♪/Femme)
  weight_kg   = poids de naissance (0.5–6 kg)

→ ω_bio ∈ (0.1, 50) — plage valide pour le certificat
```

### Taux de cohérence k

```
k = 1 / (1 + |sin(φ_i - φ_j)|) ∈ [0.5, 1.0]
```

| k | Interprétation |
|---|----------------|
| 0.5 | Asymétrie totale |
| > 0.75 | Interférence constructive |
| > 0.85 | Super-cohérence (cabine-33 publie Kind 30508) |
| > 0.95 | Singularité — lien covalent (Kind 30502) |
| 1.0 | Miroirs parfaits |

---

## Protocole du Certificat d'Incarnation (Kind 30078)

### Qui publie

| Contexte | Client | Mécanisme |
|----------|--------|-----------|
| Web (avant MULTIPASS) | `atomic.html` | Extension NIP-07 (Alby, nos2x, Flamingo) |
| Mobile (après MULTIPASS) | `cabine-33` | `Nostr_Identity.gd` au premier lancement |

### Structure de l'événement

```json
{
  "kind": 30078,
  "tags": [
    ["d", "atom4love"],
    ["app", "atom4love"],
    ["a4l_proof", "<SHA256(pubkey_hex:ATOM4LOVE_v1)>"]
  ],
  "content": "{\"personal_phase\": <0–6.28>, \"omega_bio\": <0.1–49.9>}"
}
```

### Validation côté relay (`30078.sh`)

1. `a4l_proof` = `SHA256(pubkey + ":" + app_id)` vérifié contre `AUTHORIZED_APPS` (Kind 30800)
2. `personal_phase ∈ [0, 7)` et `omega_bio ∈ (0.1, 50)`
3. En cas de succès : `add_to_amis_of_amis(pubkey)` → WoT Level 0

### Anti-fraude

Le `a4l_proof` est :
- **Déterministe** : dépend uniquement du pubkey + constante de version
- **Public** : pas de secret côté client
- **Lié à l'app** : changer de salt = nouvelle version incompatible

Le relay vérifie la liste `AUTHORIZED_APPS` depuis la config coopérative (Kind 30800, propagée
constellation-wide via `backfill_constellation.sh`).

---

## Cycle de vie d'une version d'app

```bash
# Déployer une nouvelle version
coop_app_add "ATOM4LOVE_v2"          # Ajouter le nouveau salt
# ... attendre migration des clients ...
coop_app_remove "ATOM4LOVE_v1"       # Retirer l'ancien

# Même mécanique pour une nouvelle app tierce
coop_app_add "ZELKOVA_v1"
```

---

## Correspondance jeu ↔ protocole

| Mécanique (cabine-33) | Événement NOSTR | Effet WoTx² |
|-----------------------|-----------------|-------------|
| Premier lancement + profil valide | Kind 30078 `d=atom4love` | Entrée amisOfAmis (WoT L0) |
| Rencontre physique BLE/WiFi (k ≥ 0.85) | Kind 30508 | Log de match, visibilité dans Radar |
| Lien covalent (k ≥ 0.95) | Kind 30502 | Attestation WoTx² (Règle B) |
| Rituel de Phase (33s en Cabine) | Kind 30503 x1 géo | Compétence liée à l'hexagone |
| Vote de résonance | Kind 7 `t=wotx-review` | Contribue Règle A (3 votes → +niveau) |

---

## Radar — Découverte vibratoire

`atomic.html` onglet RADAR (implémenté) :
1. Requête relay `{kinds:[30078], "#d":["atom4love"], limit:50}`
2. Pour chaque profil reçu : calcul k = 1/(1+|sin(φ_i − φ_j)|) vs phase utilisateur
3. Affichage top-5 profils les plus résonants avec lien `minelife.html?npub=...`

L'onglet s'active via le listener `shown.bs.tab` → `loadRadar()` / `_queryRelayFilter()`.
Les niveaux de résonance affichés : k ≥ 0.95 = 🔮 Singularité, k ≥ 0.85 = ✨ Super-cohérence,
k ≥ 0.75 = 💫 Cohérence, k < 0.75 = 〰 Interférence.

Cette fonctionnalité est la passerelle web vers le réseau de résonance construit
par cabine-33 dans le monde physique.

---

## Références

- [atomic.html](../../../../UPlanet/earth/atomic.html) — Interface web : PROFIL, Match, Théorie, Radar (Kind 30078)
- [phi2x.js](../../../../UPlanet/earth/phi2x.js) — Moteur Phi2X canonique (JS)
- [minelife.tuto.html](../../../../UPlanet/earth/minelife.tuto.html) — Affiche φ/ω des comptes via Kind 30078
- [NIP-101/filter/30078.sh](../../../../NIP-101/relay.writePolicy.plugin/filter/30078.sh) — Validation Certificat d'Incarnation
- [NIP-101/filter/30508.sh](../../../../NIP-101/relay.writePolicy.plugin/filter/30508.sh) — Validation Match vibratoire (k ≥ 0.85)
- [cabine-33/CLAUDE.md](../../../../cabine-33/CLAUDE.md) — Architecture app mobile Godot (producteur Kind 30508)
- [Astroport.ONE/tools/emit_skill.sh](../../../../Astroport.ONE/tools/emit_skill.sh) — Kind 30503 avec expiration Tzolkin (260/780/2600 j)
- [Astroport.ONE/tools/cooperative_config.sh](../../../../Astroport.ONE/tools/cooperative_config.sh) — Gestion AUTHORIZED_APPS
- [NIP-101/backfill_constellation.sh](../../../../NIP-101/backfill_constellation.sh) — Synchronise Kind 30078 + 30508 inter-relays
- [WOTX2_SYSTEM.md](../reference/WOTX2_SYSTEM.md) — Architecture WoTx²
- [KIND_30506_JUSTICE.md](../reference/KIND_30506_JUSTICE.md) — Médiation
