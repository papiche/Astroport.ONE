# Format d'adressage hexagonal ATOM4LOVE — a4l:

**Type :** Référence technique\
**Scope :** ATOM4LOVE / Cabine-33 / UPlanet\
**Statut :** Stable (v1)

***

## Résumé

Le format `a4l:` est un système d'adressage géospatial **propriétaire** qui identifie les cellules hexagonales et les portails pentagonaux du Polyèdre de Goldberg terrestre dans les événements NOSTR.

Les valeurs sont **opaques** pour les clients NOSTR tiers : sans les tables de décodage ATOM4LOVE et la constante d'offset (32 768), les coordonnées sont inexploitables.

***

## Contexte — Le Polyèdre de Goldberg terrestre

La Terre est modélisée comme une sphère de Goldberg **GpII(1,1)** :

| Forme                     | Quantité       | Rôle                                           |
| ------------------------- | -------------- | ---------------------------------------------- |
| **Hexagones** (\~3 990)   | ≈ 1 km² chacun | Cellules du terrain de jeu                     |
| **Pentagones (Portails)** | 12             | Nœuds singuliers, points de résonance cosmique |

Les coordonnées hexagonales utilisent le **système de coordonnées cube** (q, r, s) avec `s = −q − r`.

***

## Format `a4l:`

### Syntaxe

```
a4l:P<XX>              ← niveau Portail (zone ~6 000 km)
a4l:P<XX>H<QQQQ><RRRR> ← niveau Hexagone (~1 km²)
```

| Composant | Longueur | Plage         | Description                          |
| --------- | -------- | ------------- | ------------------------------------ |
| `a4l:`    | 4 chars  | fixe          | Namespace ATOM4LOVE                  |
| `P`       | 1 char   | fixe          | Préfixe Pentagon                     |
| `<XX>`    | 2 chars  | `00`–`11`     | ID du portail Goldberg (zero-padded) |
| `H`       | 1 char   | fixe          | Préfixe Hex                          |
| `<QQQQ>`  | 4 chars  | `0000`–`FFFF` | Coordonnée q encodée (base 16)       |
| `<RRRR>`  | 4 chars  | `0000`–`FFFF` | Coordonnée r encodée (base 16)       |

**Longueur totale :** 7 chars (portail) ou 16 chars (hexagone)

### Algorithme d'encodage

```
q_enc = format((q + 32768) & 0xFFFF, '04X')
r_enc = format((r + 32768) & 0xFFFF, '04X')
hex_tag = f"a4l:P{pentagon_id:02d}H{q_enc}{r_enc}"
```

L'offset **32 768** rend les coordonnées signées positives sur 16 bits.\
Plage supportée : q, r ∈ \[−32 768, +32 767].

### Algorithme de décodage

```
body   = tag_value[5:]           # "02H820B7F6C"
h_idx  = body.index('H')
pid    = int(body[:h_idx])       # 2
q      = int(body[h_idx+1:h_idx+5], 16) - 32768   # 523
r      = int(body[h_idx+5:h_idx+9], 16) - 32768   # -148
```

***

## Les 12 Portails Goldberg

| ID  | Nom astronomique | Coordonnées (lat°, lon°) | Wikipedia                                               |
| --- | ---------------- | ------------------------ | ------------------------------------------------------- |
| P00 | Pôle Nord        | +90.0, 0.0               | https://fr.wikipedia.org/wiki/P%C3%B4le\_Nord           |
| P01 | Pôle Sud         | −90.0, 0.0               | https://fr.wikipedia.org/wiki/P%C3%B4le\_Sud            |
| P02 | Orion            | +26.56, 0.0              | https://fr.wikipedia.org/wiki/N%C3%A9buleuse\_d%27Orion |
| P03 | Aldébaran        | +26.56, +72.0            | https://fr.wikipedia.org/wiki/Ald%C3%A9baran            |
| P04 | Sirius           | +26.56, +144.0           | https://fr.wikipedia.org/wiki/Sirius                    |
| P05 | Véga             | +26.56, −72.0            | https://fr.wikipedia.org/wiki/V%C3%A9ga                 |
| P06 | Antarès          | +26.56, −144.0           | https://fr.wikipedia.org/wiki/Antar%C3%A8s              |
| P07 | Fomalhaut        | −26.56, +36.0            | https://fr.wikipedia.org/wiki/Fomalhaut                 |
| P08 | Achernar         | −26.56, +108.0           | https://fr.wikipedia.org/wiki/Achernar                  |
| P09 | Rigel            | −26.56, +180.0           | https://fr.wikipedia.org/wiki/Rigel                     |
| P10 | Capella          | −26.56, −36.0            | https://fr.wikipedia.org/wiki/Capella\_(%C3%A9toile)    |
| P11 | Deneb            | −26.56, −108.0           | https://fr.wikipedia.org/wiki/Deneb                     |

> Les positions sont calculées dynamiquement avec la précession des équinoxes via `Phi2X_Math.get_dynamic_pentagons(unix_ts)`.

***

## Usage NOSTR

### Tags sur les événements publiés

Chaque événement ATOM4LOVE publié depuis une Cabine-33 porte **deux tags `#l`** pour permettre l'abonnement à deux granularités :

```json
{
  "kind": 1,
  "content": "Pensée déposée dans la Spacememory",
  "tags": [
    ["l", "a4l:P02",           "atom4love"],
    ["l", "a4l:P02H820B7F6C", "atom4love"],
    ["t", "atom4love"],
    ["t", "cabine33"]
  ]
}
```

| Tag                | Granularité    | Zone couverte                  |
| ------------------ | -------------- | ------------------------------ |
| `a4l:P02`          | Portail Orion  | \~6 000 km (Europe de l'Ouest) |
| `a4l:P02H820B7F6C` | Hexagone Paris | \~1 km²                        |

### Filtres d'abonnement REQ

```json
// Abonnement hexagone local (après rituel Cabine-33)
{ "kinds": [1], "#l": ["a4l:P02H820B7F6C"], "limit": 33 }

// Abonnement portail régional (dernières 24h)
{ "kinds": [1], "#l": ["a4l:P02"], "limit": 12, "since": <timestamp_24h_avant> }
```

***

## API GDScript — `Phi2X_Math`

### `geo_tags(lat, lon, unix_ts) → Array`

Retourne deux tags NOSTR prêts à être ajoutés à un événement.

```gdscript
var tags := Phi2X_Math.geo_tags(43.6050, 1.4440, Time.get_unix_time_from_system())
# → [
#     ["l", "a4l:P02",           "atom4love"],  # portail
#     ["l", "a4l:P02H820B7F6C", "atom4love"],  # hexagone
#   ]
```

| Paramètre | Type    | Description                                                   |
| --------- | ------- | ------------------------------------------------------------- |
| `lat`     | `float` | Latitude (degrés décimaux)                                    |
| `lon`     | `float` | Longitude (degrés décimaux)                                   |
| `unix_ts` | `float` | Timestamp Unix pour la précession (0 = positions fixes J2000) |

### `decode_geo_tag(tag_value) → Dictionary`

Décode un tag `a4l:` en composants.

```gdscript
var d := Phi2X_Math.decode_geo_tag("a4l:P02H820B7F6C")
# → { "pentagon_id": 2, "q": 523, "r": -148 }

var d2 := Phi2X_Math.decode_geo_tag("a4l:P07")
# → { "pentagon_id": 7 }
```

***

## Exemples concrets

| Lieu                               | Portail       | Tag hexagone       |
| ---------------------------------- | ------------- | ------------------ |
| Paris (48.85°N, 2.35°E)            | P02 Orion     | `a4l:P02H820B7F6C` |
| Fort-de-France (14.60°N, −61.07°E) | P07 Fomalhaut | `a4l:P07H7C5F7FBB` |
| Sydney (−33.87°S, 151.21°E)        | P09 Rigel     | `a4l:P09H7E097A97` |
| Équateur/Méridien 0°               | P00 Pôle Nord | `a4l:P00H80008000` |

***

## Opacité et sécurité

Le format est conçu pour être **opaque** aux clients NOSTR standard :

* `820B7F6C` ne révèle aucune information géographique directe
* Sans la constante d'offset (32 768) et les tables hexagonales ATOM4LOVE, le décodage est impossible
* Les portails ne correspondent pas à des pays ou régions géopolitiques reconnaissables
* Le nom astronomique (Orion, Sirius…) ne trahit pas la position

Les relays Astroport filtrent par ces tags via NIP-01 (`#l`), sans avoir besoin de décoder les coordonnées.

***

## Implémentation de référence

* **GDScript** : `autoloads/Phi2X_Math.gd` — `geo_tags()`, `decode_geo_tag()`
* **Publication** : `scripts/Main_UI.gd` — `_on_send_thought_inline()`
* **Abonnement** : `scripts/Main_UI.gd` — `_subscribe_spacememory()`
* **Affichage 3D** : `scripts/World_3D.gd` — `_spawn_thought_bubble()`

***

## Voir aussi

* [`NOSTR_EVENTS_REFERENCE.md`](NOSTR_EVENTS_REFERENCE.md) — Référence centrale des kinds NOSTR UPlanet
* [`IDENTITY_MULTIPASS.md`](IDENTITY_MULTIPASS.md) — Structure du MULTIPASS (salt/pepper)
* [Cabine-33 README](https://github.com/papiche/Astroport.ONE/blob/master/cabine-33/README.md) — Documentation de l'application mobile
