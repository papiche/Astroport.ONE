# DNSLink OVH — Explication

> Ce document explique **pourquoi** et **comment** le DNSLink relie l'infrastructure coopérative IPFS au DNS classique via OVH.
> Pour l'installation initiale, voir `docs/tutorials/setup_dnslink_ovh.md`.
> Pour les recettes courantes, voir `docs/how-to/update_dnslink_ovh.md`.
> Pour la liste complète des variables et fonctions, voir `docs/reference/DNSLINK_OVH.md`.

---

## Le problème du contenu adressable par contenu

IPFS adresse chaque fichier ou répertoire par son **empreinte cryptographique** (CID). Un CID comme `QmXnnyC2Fk9qNi5oLe3fBZr1iMqGH3p5oFaYkJ2sSqNnE` est opaque et change à chaque publication — même si le contenu n'a changé que d'une ligne.

Le DNS, lui, est stable par nature : `astroport.one` pointe toujours vers le même serveur jusqu'à modification manuelle. Cette stabilité est précieuse pour les utilisateurs, mais incompatible avec le modèle immutable d'IPFS.

**Le DNSLink réconcilie les deux** : un enregistrement TXT `_dnslink.astroport.one` contenant `dnslink=/ipfs/<CID>` indique aux gateways IPFS quelle version du contenu est "courante" pour ce nom de domaine.

---

## Architecture du flux de publication

```
Modification de earth/
        │
        ▼
ipfs add -rq earth/
        │
        ▼  CID immuable (ex: QmEARTH...)
        │
        ├─ Stocké dans .chain (historique)
        ├─ Publié dans git (traçabilité)
        │
        └─ ovh.me.sh upsert (OVH API v1)
                │
                ├─ PUT _dnslink.astroport.one        TXT "dnslink=/ipfs/QmEARTH..."
                └─ PUT _dnslink.origin.astroport.one TXT "dnslink=/ipfs/QmEARTH..."
                        │
                        ▼
        Résolution par toute gateway IPFS :
        https://<gateway>/ipns/astroport.one  →  earth/index.html
```

Le hash cible est le CID du répertoire `earth/` uniquement — pas du dépôt UPlanet entier. Cela garantit que `https://cloudflare-ipfs.com/ipns/astroport.one/` affiche directement `index.html` sans couche intermédiaire.

---

## Le rôle des deux domaines

| Domaine | Enregistrement | Usage |
|---|---|---|
| `astroport.one` | `_dnslink.astroport.one` | Domaine public principal |
| `origin.astroport.one` | `_dnslink.origin.astroport.one` | Référence de déploiement, tests A/B, redirections |

`origin` sert de marqueur stable pour les autres stations du swarm : elles peuvent comparer leur version locale à `origin.astroport.one` pour détecter une mise à jour disponible.

---

## Pourquoi OVH API et non un autre registrar

La zone DNS `astroport.one` est hébergée chez OVH. L'API OVH v1 offre une authentification par signature HMAC-SHA1 sans OAuth2, ce qui la rend utilisable dans un script bash pur sans dépendance externe (ni Python, ni Node, ni SDK).

La signature garantit que chaque requête est :
- **Authentifiée** : seul le détenteur de `OVH_APP_SECRET` + `OVH_CONSUMER_KEY` peut signer
- **Non-rejouable** : le timestamp serveur (issu de `/auth/time`) est inclus dans la signature
- **Intègre** : method + URL + body sont tous signés

---

## Stockage des credentials dans le réseau coopératif

Les trois tokens OVH (`APP_KEY`, `APP_SECRET`, `CONSUMER_KEY`) ne sont jamais stockés en clair sur le disque ou dans git. Ils transitent uniquement via le mécanisme coopératif Kind 30800 :

```
Administrateur
    │  coop_config_set "OVH_APP_SECRET" "xxx"
    ▼
AES-256-CBC ( clé = SHA256($UPLANETNAME) )
    │
    ▼
NOSTR Kind 30800, d-tag "cooperative-config"
    │  publié sur le relay de la constellation
    │
    ├─ Station A : coop_load_env_from_config → export $OVH_APP_SECRET
    ├─ Station B : coop_load_env_from_config → export $OVH_APP_SECRET
    └─ economy.html : déchiffrement WebCrypto en mémoire (jamais localStorage)
```

Toutes les stations du swarm partagent les mêmes credentials sans jamais les stocker localement. Si les credentials sont compromis, un seul `coop_config_set` met à jour toute la constellation.

---

## DNSLink par MULTIPASS

En plus des deux enregistrements de zone principale (`_dnslink.astroport.one`), chaque MULTIPASS peut disposer de son propre sous-domaine DNSLink pointant vers son vault IPNS :

```
_dnslink.alice.astroport.one  TXT  "dnslink=/ipns/k51q..."
```

Ce record est géré par `ovh.me.sh upsert <YOUSER> /ipns/<NOSTRNS>` et mis à jour automatiquement par `make_NOSTRCARD.sh` à la création et `NOSTRCARD.refresh.sh` à chaque republication IPNS. Cela permet à n'importe quelle gateway IPFS de résoudre `alice.astroport.one` vers le vault personnel du membre.

---

## Limites et contraintes

- Le script effectue un **PUT** (mise à jour) ou un **POST** (création) — il ne supprime jamais de records.
- Si la zone DNS n'est pas hébergée chez OVH, la fonction `_dnslink_update` échoue silencieusement (`SKIP`).
- La propagation DNS après `/refresh` dépend du TTL de l'enregistrement (recommandé : 60 secondes).
- Le DNSLink n'est déclenché que si le contenu de `earth/` a changé (le script s'arrête tôt avec `No change.` sinon).
