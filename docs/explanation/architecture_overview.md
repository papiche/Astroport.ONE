# Architecture d'ensemble — Vue synthétique

> Ce document explique **pourquoi** Astroport.ONE est construit comme il l'est.
> Pour les endpoints et formats exacts, consultez `docs/reference/`.
> Pour les guides d'installation, consultez `docs/tutorials/`.

---

## Les trois couches fondamentales

Astroport.ONE repose sur la convergence de trois protocoles indépendants, chacun souverain dans son domaine :

```
┌─────────────────────────────────────────────┐
│  NOSTR  ─  Signalisation & Identité         │
│  Qui je suis, ce que je publie, qui m'aime  │
├─────────────────────────────────────────────┤
│  IPFS   ─  Stockage & Transport             │
│  Où vivent mes fichiers, comment y accéder  │
├─────────────────────────────────────────────┤
│  Ğ1 (Duniter v2s)  ─  Économie & Confiance  │
│  Ce que ça vaut, qui l'a gagné, comment     │
└─────────────────────────────────────────────┘
```

Ces trois couches ne se remplacent pas — elles se complètent. Aucun composant central n'est nécessaire : chaque station est un nœud complet.

---

## La Station : unité de base

Une **Station** (ou nœud Astroport.ONE) est un ordinateur qui fait tourner simultanément :

- **IPFS Kubo** — stockage distribué, adressage par contenu (CID)
- **strfry** — relay NOSTR officiel (port 7777), filtres NIP-101 en Bash
- **UPassport FastAPI** (port 54321) — API centrale de création d'identité et de gestion ẐEN
- **Astroport `_12345.sh`** (port 12345) — cartographie de la station, publication JSON sur IPNS

La station publie son état (`12345.json`) en permanence sur `/ipns/$IPFSNODEID`, accessible à toutes les autres stations du swarm.

---

## L'Identité : MULTIPASS et ZenCard

L'identité dans UPlanet est **déterministe et sans serveur central** :

```
email + géoloc  →  keygen  →  clé Ğ1 (Ed25519)
                           →  clé NOSTR (Ed25519)
                           →  PeerID IPFS
```

Les trois clés sont mathématiquement liées mais indépendantes. Ensemble, elles forment le **MULTIPASS** (niveau 1 — usager).

La **ZenCard** (niveau 2 — sociétaire) ajoute une couche de propriété : 128 Go NextCloud, droits de vote coopératif, accès au swarm ẐEN privé.

La clé privée maître est fractionnée en 3 parts (SSSS 2/3) : le réseau en garde une, la station en garde une, l'utilisateur en garde une. Aucun acteur seul ne peut reconstituer la clé.

---

## L'Économie : le modèle 3×1/3

Chaque ẐEN entrant dans le système est distribué automatiquement par le code :

```
Ẑen reçu  →  1/3 Trésorerie coopérative (CASH)
              1/3 R&D open-source
              1/3 Actifs communs (terres, forêts, infra)
```

Les paiements hebdomadaires aux Armateurs (14 Ẑ) et aux Capitaines (28 Ẑ) sont calculés et exécutés par `ZEN.ECONOMY.sh` sans intervention humaine. Les transactions sont visibles sur la blockchain Ğ1 (Duniter v2s).

Pour la spec complète : [ZEN.ECONOMY.v3.md](ZEN.ECONOMY.v3.md).

---

## Le Swarm : constellation N²

Les stations se découvrent via IPFS (DHT + swarm.key pour le swarm ẐEN privé). Chaque station lit les `12345.json` de ses pairs et maintient une carte locale du swarm dans `~/.zen/tmp/swarm/`.

La synchronisation N² des événements NOSTR entre tous les relays de la constellation est assurée par `NIP-101/backfill_constellation.sh`.

---

## Flux de données principal

```
Utilisateur  →  MULTIPASS (keygen)
             →  UPassport /g1nostr  →  profil NOSTR kind 0 publié
             →  uDRIVE IPFS  →  fichiers adressés par CID, publiés via IPNS
             →  Relay strfry  →  événements NOSTR (likes, articles, vidéos)
             →  Ğ1 blockchain  →  transactions transparentes (paiements ẐEN)
```

---

## Voir aussi

- [ROLES.md](ROLES.md) — qui fait quoi (Armateur, Capitaine, DRAGON)
- [DID_IMPLEMENTATION.md](DID_IMPLEMENTATION.md) — détail technique de l'identité W3C DID
- [ZEN.ECONOMY.v3.md](ZEN.ECONOMY.v3.md) — modèle économique complet
- [../reference/NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md) — tous les kinds NOSTR
