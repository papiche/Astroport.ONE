# 🎟️ Identity Level 1 : MULTIPASS (L'Usager)

## Introduction

Le **MULTIPASS** est la porte d'entrée par défaut dans l'écosystème UPlanet. C'est une identité numérique décentralisée conçue pour l'usage quotidien, les interactions sociales et le stockage personnel léger.

## Composition Technique

Le MULTIPASS repose sur un triptyque cryptographique :

1. **Identité Nostr :** Un couple de clés (NSEC/NPUB) généré de façon déterministe.
2. **Portefeuille de Revenu (Ğ1) :** Un wallet Duniter v2s dédié aux flux courants (likes, pourboires).
3. **uDRIVE (IPFS) :** Un espace de stockage personnel de **10 Go** accessible via une interface web décentralisée.

## Services Inclus

* **Nostr Tube :** Publication et consultation de vidéos.
* **Messagerie :** Communication chiffrée et publique via Nostr.
* **AstroBot :** Interaction de base avec l'Intelligence Artificielle locale.
* **uDRIVE :** Explorateur de fichiers IPFS pour vos documents et médias.

## Modèle Économique

* **Coût :** 1 Ẑen / semaine (soit 0.1 Ğ1).
* **Prélèvement :** Automatisé par le script `NOSTRCARD.refresh.sh`.
* **Statut :** "Locataire" des ressources de la station.

## Données Natales & Kin Maya (optionnel)

Lors de la création du MULTIPASS (formulaire `/g1nostr`), l'utilisateur peut renseigner sa **date de naissance** et son **lieu de naissance** (optionnel : poids). Ces données :

* Sont conservées dans des fichiers **cachés** (`~/.zen/game/nostr/<email>/.birth_datetime`, `.birth_place`, `.birth_weight`)
* La date extraite (YYYY-MM-DD) est écrite dans **`BIRTHDATE`** — lue par `did_manager_nostr.sh` pour calculer le **Kin Maya Tzolkin** et l'inclure dans le DID (kind 30800) comme badge `{"type":"MayaKin","kin":N,"glyph":"…","tone":"…","color":"…"}`
* Ne sont **jamais** publiées sur IPFS ou les relays NOSTR (seul le numéro Kin apparaît dans le DID public)
* Le calcul utilise l'algorithme **Dreamspell** (José Argüelles, 1990) implémenté dans `tools/kin.sh`
* La date de naissance (`.BIRTHDATE`) est distincte de `.account_created` (date d'inscription = facturation hebdomadaire)

Voir aussi : [kin.html](https://github.com/papiche/Astroport.ONE/blob/master/earth/kin.html) — page interactive Kin Maya sur UPlanet.

***

## Génération des clés MULTIPASS (SALT / PEPPER)

Le MULTIPASS reçoit son SALT/PEPPER dans `tools/make_NOSTRCARD.sh` — **toujours un secret aléatoire côté serveur**, indépendant de toute donnée de naissance. Même si le client (ATOM4LOVE, Cabine-33) envoie un SALT/PEPPER dérivé des données de naissance en même temps que `BIRTH_DATETIME`, le script détecte ce contexte (`_A4L_BIRTH_CONTEXT`, `tools/make_NOSTRCARD.sh:100-110`) et l'écrase systématiquement :

```bash
# tools/make_NOSTRCARD.sh:211-214
if [[ "$_A4L_BIRTH_CONTEXT" == "yes" ]]; then
    echo "🌱 Contexte birth-derived détecté — SALT/PEPPER fournis réservés à la clé LOVE, identité MULTIPASS forcée en aléatoire"
    SALT=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w${_DISCO_RAND} | head -n1)
    PEPPER=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w${_DISCO_RAND} | head -n1)
```

Les identifiants NSEC/NPUB du MULTIPASS ne dépendent donc **jamais** de la date/heure de naissance, du lieu, du poids ou de la polarité — ces champs, quand ils sont fournis, sont réservés à la clé LOVE (`.secret.love`, voir ci-dessous).

Cas distinct : si le client fournit un SALT/PEPPER personnalisé (mode "GAFAM", ≤ 56 caractères) **sans** contexte de naissance détecté, il est conservé tel quel et devient le SALT/PEPPER déterministe du MULTIPASS (`tools/make_NOSTRCARD.sh:215-217`) — même EMAIL+SALT+PEPPER ⇒ mêmes clés, reproductibles sur n'importe quelle station. C'est ce mécanisme générique (non birth-derived) que documente `tools/MULTIPASS_SYSTEM.md`.

## Clé LOVE (`.secret.love`) — dérivation biométrique déterministe

La dérivation birth-derived immuable ne concerne pas le MULTIPASS mais la clé NOSTR dédiée au canal social **ATOM4LOVE**. Elle est calculée et écrite par `tools/atom4love_publish.py`, **distincte** de l'identité principale (`.secret.nostr`) :

> « Cette clé est DISTINCTE de la clé NOSTR principale du MULTIPASS (.secret.nostr) — elle sert uniquement à signer/chiffrer le canal DM "LOVE" avec BRO et à publier le profil de résonance Phi² (kind 30078), jamais à des paiements ẐEN. » — `tools/atom4love_publish.py:12-14`

### Comment `.secret.love` est dérivée

1. **Correction d'heure solaire** : l'heure locale de naissance (et de conception) est convertie en UTC via la longitude + l'équation du temps — `tools/atom4love_publish.py:60-77` (`_equation_of_time`, `local_solar_to_utc`).
2. **Date de conception** : par défaut `naissance − 280 jours` (gestation fixe) — `tools/atom4love_publish.py:210`. Un `CONCEPTION_DATETIME` fourni en argument n'affecte aujourd'hui que le badge Kin Maya de conception (`kin_c`/`glyph_c`/`tone_c`), pas la clé — `tools/atom4love_publish.py:264-274`. *(Une formule de gestation ajustée au poids, `280.0 + (poids − 3.5) × 4.0`, existe dans `tools/phi2x.py:343-350` mais n'est pas appelée par `atom4love_publish.py`.)*
3. **Chaînes brutes** :
   ```python
   # tools/atom4love_publish.py:80-88
   salt_raw   = f"{birth_dt_utc}_{lat:.2f}_{lon:.2f}_{polarity}_{poids:.1f}_{H_NAISS}_{H_ACTUELLE}"
   pepper_raw = f"{conception_dt_utc}_{lat:.2f}_{lon:.2f}_{poids:.1f}_{H_NAISS}"
   ```
   `H_NAISS` (50) et `H_ACTUELLE` (170) sont des constantes fixes, non collectées côté serveur — `tools/atom4love_publish.py:54-55`.
4. **Stretching** : PBKDF2-HMAC-SHA256 (domaine `uplanet-a4l-v1`, 600 000 itérations) — `tools/atom4love_publish.py:52-53,91-94`.
5. **Dérivation NOSTR** : `keygen -t nostr` à partir des deux chaînes étirées, même mécanisme que `make_NOSTRCARD.sh` — `tools/atom4love_publish.py:99-120`.
6. **Écriture** : `~/.zen/game/nostr/<email>/.secret.love` (format `NSEC=...; NPUB=...; HEX=...;`) — `tools/atom4love_publish.py:151-163`.

### Propriétés

* **Déterminisme** : mêmes données de naissance/conception ⇒ même clé LOVE, reproductible sur n'importe quelle station.
* **Immuabilité** : changer un seul paramètre (poids, heure, lieu, polarité) change entièrement le SALT/PEPPER, donc la clé.
* **Opacité** : le format n'est pas un standard connu — résistant au brute-force sans connaître naissance + conception + poids + polarité + coordonnées.

## `NODE_NSEC` vs `.secret.love` — qui signe quoi

| Clé | Définition | Rôle |
| --- | --- | --- |
| `NODE_NSEC` | Clé NOSTR de la station (capitaine), chargée depuis `secret.nostr` — `IA/bro/bro_dm_daemon.sh:191` | Signature par défaut de toutes les réponses IA "BRO" |
| `.secret.love` | Clé LOVE birth-derived du compte destinataire (voir ci-dessus) | Utilisée à la place de `NODE_NSEC` uniquement quand `_LOVE_REPLY_AS` est positionnée à l'email du destinataire — `IA/bro/bro_dm_daemon.sh:66,79-84` |

Quand un DM arrive sur le canal LOVE, le daemon signe la réponse avec `.secret.love` du destinataire plutôt qu'avec `NODE_NSEC`, afin que l'IA "Astria" du canal LOVE réponde authentiquement en tant que la clé LOVE de l'utilisateur, et non en tant que la station (`IA/bro/bro_dm_daemon.sh:1419-1455`).

***

## Migration & Portabilité

Grâce à la dérivation déterministe (Salt/Pepper), vous pouvez migrer votre MULTIPASS d'une station Astroport à une autre. En cas de départ, le script `nostr_DESTROY_TW.sh` génère un backup chiffré et transfère votre solde vers votre adresse primale.
