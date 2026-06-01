# 🎟️ Identity Level 1 : MULTIPASS (L'Usager)

## Introduction
Le **MULTIPASS** est la porte d'entrée par défaut dans l'écosystème UPlanet. C'est une identité numérique décentralisée conçue pour l'usage quotidien, les interactions sociales et le stockage personnel léger.

## Composition Technique
Le MULTIPASS repose sur un triptyque cryptographique :
1. **Identité Nostr :** Un couple de clés (NSEC/NPUB) généré de façon déterministe.
2. **Portefeuille de Revenu (Ğ1) :** Un wallet Duniter v2s dédié aux flux courants (likes, pourboires).
3. **uDRIVE (IPFS) :** Un espace de stockage personnel de **10 Go** accessible via une interface web décentralisée.

## Services Inclus
- **Nostr Tube :** Publication et consultation de vidéos.
- **Messagerie :** Communication chiffrée et publique via Nostr.
- **AstroBot :** Interaction de base avec l'Intelligence Artificielle locale.
- **uDRIVE :** Explorateur de fichiers IPFS pour vos documents et médias.

## Modèle Économique
- **Coût :** 1 Ẑen / semaine (soit 0.1 Ğ1).
- **Prélèvement :** Automatisé par le script `NOSTRCARD.refresh.sh`.
- **Statut :** "Locataire" des ressources de la station.

## Données Natales & Kin Maya (optionnel)

Lors de la création du MULTIPASS (formulaire `/g1nostr`), l'utilisateur peut renseigner sa **date de naissance** et son **lieu de naissance** (optionnel : poids). Ces données :

- Sont conservées dans des fichiers **cachés** (`~/.zen/game/nostr/<email>/.birth_datetime`, `.birth_place`, `.birth_weight`)
- La date extraite (YYYY-MM-DD) est écrite dans **`BIRTHDATE`** — lue par `did_manager_nostr.sh` pour calculer le **Kin Maya Tzolkin** et l'inclure dans le DID (kind 30800) comme badge `{"type":"MayaKin","kin":N,"glyph":"…","tone":"…","color":"…"}`
- Ne sont **jamais** publiées sur IPFS ou les relays NOSTR (seul le numéro Kin apparaît dans le DID public)
- Le calcul utilise l'algorithme **Dreamspell** (José Argüelles, 1990) implémenté dans `tools/kin.sh`
- La date de naissance (`BIRTHDATE`) est distincte de `.birthdate` (date d'inscription = facturation hebdomadaire)

Voir aussi : [kin.html](/earth/kin.html) — page interactive Kin Maya sur UPlanet.

---

## Dérivation déterministe Salt / Pepper (ATOM4LOVE / Cabine-33)

Le MULTIPASS créé depuis l'application **ATOM4LOVE** utilise une dérivation biométrique déterministe des credentials salt et pepper. Ces données sont **immuables après la création** — elles définissent l'identité cryptographique.

### Format SALT — identité de naissance

```
"%04d%02d%02d%02d%02d_%.2f_%.2f_%d_%.1f"
   AAAA  MM  JJ  HH  MM  lat_naiss  lon_naiss  sexe  poids_naiss
```

| Champ | Description | Exemple | Obligatoire |
|---|---|---|---|
| `AAAA` | Année de naissance (4 chiffres) | `1985` | ✅ |
| `MM` | Mois (2 chiffres, zero-padded) | `04` | ✅ |
| `JJ` | Jour (2 chiffres) | `17` | ✅ |
| `HH` | Heure locale de naissance | `15` | ⚠️ défaut `12` |
| `MM` | Minute | `30` | ⚠️ défaut `00` |
| `lat_naiss` | Latitude lieu de naissance (%.2f = 2 décimales) | `48.85` | ✅ `0.00` si absent |
| `lon_naiss` | Longitude lieu de naissance | `2.35` | ✅ `0.00` si absent |
| `sexe` | Polarité biologique (0 = Φ/Lumière, 1 = Octave/Son) | `0` | ⚠️ défaut `0` |
| `poids_naiss` | Poids de naissance en kg (%.1f = 1 décimale) | `3.2` | ✅ pré-rempli aléatoire |

**Exemple salt complet :**
```
19850417153048.850002.3503.2
```

### Format PEPPER — identité de conception

```
"%04d%02d%02d%02d%02d_%.2f_%.2f_%.1f"
   c_AAAA  c_MM  c_JJ  c_HH  c_MM  lat_naiss  lon_naiss  poids_naiss
```

La date de conception est **calculée automatiquement** depuis la date de naissance et le poids :

```python
gestation_jours = 280.0 + (poids_naiss - 3.5) * 4.0
conception_unix = birth_unix - gestation_jours * 86400
```

> Exemple : poids 3.2 kg → gestation = 280 + (3.2 − 3.5) × 4 = 278.8 jours

| Champ | Description |
|---|---|
| `c_AAAA`…`c_MM` | Date et heure de conception calculée |
| `lat_naiss`, `lon_naiss` | Même coordonnées que le salt (lieu de naissance) |
| `poids_naiss` | Même poids que le salt |

**Exemple pepper complet** (pour la naissance ci-dessus) :
```
19840715030048.850002.3503.2
```

### Propriétés de sécurité

- **Déterminisme** : mêmes données → même MULTIPASS sur n'importe quelle station
- **Entropie biométrique** : 7 variables continues = espace de combinaisons > 10¹⁵
- **Opacité** : le format est un string ASCII, pas un standard connu — résistant au brute-force sans la formule
- **Le poids** est pré-rempli aléatoirement [2.5, 4.5] kg si inconnu — même sans l'exactitude parentale, chaque compte est unique
- **Non modifiable** après forge : changer le poids d'1 g change le pepper et donc les clés NOSTR/Ğ1

### Données distinctes des données ATOM4LOVE

Les champs ci-dessus **définissent le MULTIPASS**. Les données suivantes sont des **données de profil** utilisées uniquement par l'algorithme ATOM4LOVE (φ_i, ω_bio, Portail Goldberg) et peuvent être modifiées à tout moment **sans affecter les clés** :

| Donnée ATOM4LOVE | Rôle | Indépendante du MULTIPASS |
|---|---|---|
| `birth_utc_offset_h` | Correction φ_i (heure solaire vraie) | ✅ |
| `conception_unix` (manuel) | Portail Goldberg précis | ✅ |
| `conception_lat/lon` | Portail d'Origine Goldberg | ✅ |
| `height_cm` | ω_bio (fréquence biologique) | ✅ |

---

## Migration & Portabilité
Grâce à la dérivation déterministe (Salt/Pepper), vous pouvez migrer votre MULTIPASS d'une station Astroport à une autre. En cas de départ, le script `nostr_DESTROY_TW.sh` génère un backup chiffré et transfère votre solde vers votre adresse primale.