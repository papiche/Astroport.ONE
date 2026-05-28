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

## Migration & Portabilité
Grâce à la dérivation déterministe (Salt/Pepper), vous pouvez migrer votre MULTIPASS d'une station Astroport à une autre. En cas de départ, le script `nostr_DESTROY_TW.sh` génère un backup chiffré et transfère votre solde vers votre adresse primale.