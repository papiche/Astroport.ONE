# Référence — DNSLink OVH

> Description technique complète des variables, fonctions et endpoints utilisés par `UPlanet/microledger.me.sh` pour mettre à jour les enregistrements DNSLink sur OVH.

---

## Variables d'environnement

| Variable | Type | Défaut | Description |
|---|---|---|---|
| `OVH_APP_KEY` | string | — | Application Key OVH (identifiant public de l'application) |
| `OVH_APP_SECRET` | string | — | Application Secret OVH (signataire des requêtes) — **chiffré dans Kind 30800** |
| `OVH_CONSUMER_KEY` | string | — | Consumer Key OVH (autorise l'accès aux ressources) — **chiffré dans Kind 30800** |
| `OVH_ZONE` | string | `astroport.one` | Zone DNS OVH cible |

### Priorité de chargement

```
1. Variables déjà présentes dans l'ENV de la session courante
       ↓ (si absentes)
2. coop_config_get via cooperative_config.sh (Kind 30800, déchiffrement AES-256-CBC)
       ↓ (si UPLANETNAME non défini ou relay inaccessible)
3. Aucun DNSLink — SKIP affiché, script continue normalement
```

---

## Fonctions bash (`microledger.me.sh`)

### `_load_ovh_credentials`

```
Usage : _load_ovh_credentials
```

Charge les variables OVH depuis l'ENV ou via `cooperative_config.sh`.
Ne fait rien si `OVH_APP_KEY`, `OVH_APP_SECRET` et `OVH_CONSUMER_KEY` sont déjà définis.

### `_ovh_sign METHOD URL BODY TIMESTAMP`

```
Usage : _ovh_sign "GET" "https://eu.api.ovh.com/1.0/..." "" "1234567890"
Retour : sha1 (hex, 40 caractères)
```

Calcule la signature HMAC-SHA1 OVH API v1. La signature est construite en concaténant avec `+` les paramètres dans l'ordre :

```
SHA1( APP_SECRET + "+" + CONSUMER_KEY + "+" + METHOD + "+" + URL + "+" + BODY + "+" + TIMESTAMP )
```

Pour les requêtes sans body (GET, DELETE), `BODY` est une chaîne vide.

La signature résultante est préfixée `$1$` dans le header `X-Ovh-Signature`.

### `_ovh_api METHOD /path [body]`

```
Usage : _ovh_api GET "/domain/zone/astroport.one/record?fieldType=TXT&subDomain=_dnslink"
        _ovh_api PUT "/domain/zone/astroport.one/record/12345" '{"target":"dnslink=/ipfs/Qm..."}'
        _ovh_api POST "/domain/zone/astroport.one/refresh"
Retour : corps de la réponse JSON (erreurs comprises)
```

Effectue un appel HTTP signé vers `https://eu.api.ovh.com/1.0`. Headers envoyés :

| Header | Valeur |
|---|---|
| `X-Ovh-Application` | `$OVH_APP_KEY` |
| `X-Ovh-Consumer` | `$OVH_CONSUMER_KEY` |
| `X-Ovh-Timestamp` | timestamp issu de `/auth/time` |
| `X-Ovh-Signature` | `$1$<sha1>` |
| `Content-Type` | `application/json` |

Le flag `-f` (fail silently) est **absent** — les réponses d'erreur HTTP (401, 403, 404) sont retournées dans le body pour diagnostic.

### `_dnslink_update SUBDOMAIN ZONE CID`

```
Usage : _dnslink_update "_dnslink"        "astroport.one" "QmEARTH..."
        _dnslink_update "_dnslink.origin" "astroport.one" "QmEARTH..."
Retour : 0 (succès) / 1 (erreur)
```

Flux interne :

```
1. GET /domain/zone/{zone}/record?fieldType=TXT&subDomain={subdomain}
        │
        ├─ Réponse contient "message" → ERROR, return 1
        ├─ Tableau vide [] → POST /domain/zone/{zone}/record (création)
        └─ Tableau [id, ...] → PUT /domain/zone/{zone}/record/{id} (mise à jour)
                │
                └─ POST /domain/zone/{zone}/refresh
```

---

## Endpoints OVH API v1

Base URL : `https://eu.api.ovh.com/1.0`

| Méthode | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/auth/time` | Non | Timestamp serveur (pour la signature) |
| GET | `/domain/zone/{zone}/record?fieldType=TXT&subDomain={sub}` | Oui | Liste les IDs des records TXT |
| POST | `/domain/zone/{zone}/record` | Oui | Crée un nouveau record |
| PUT | `/domain/zone/{zone}/record/{id}` | Oui | Met à jour un record existant |
| POST | `/domain/zone/{zone}/refresh` | Oui | Déclenche la propagation de la zone |

### Corps de la requête POST (création)

```json
{
  "fieldType": "TXT",
  "subDomain": "_dnslink",
  "target": "dnslink=/ipfs/QmEARTH...",
  "ttl": 0
}
```

### Corps de la requête PUT (mise à jour)

```json
{
  "target": "dnslink=/ipfs/QmEARTH..."
}
```

---

## Codes de retour et messages d'erreur OVH

| Message OVH | Cause | Action |
|---|---|---|
| `INVALID_CREDENTIAL` | Signature incorrecte ou token révoqué | Vérifier les credentials, recréer un token |
| `FORBIDDEN_RESOURCE` | Token sans le droit requis (GET/PUT/POST) | Recréer le token avec les bons droits |
| `QUERY_TIME_OUT` | Horloge de la station décalée de plus de ±30s | `sudo ntpdate pool.ntp.org` |
| `NOT_FOUND` | Zone ou record inexistant | Vérifier le nom de zone dans OVH Manager |
| `INVALID_ZONE` | Zone non gérée par OVH | Vérifier `OVH_ZONE` |
| `[]` (tableau vide) | Record TXT absent | Création automatique par POST |

---

## Stockage coopératif (Kind 30800)

Les credentials OVH sont stockés dans le DID coopératif NOSTR :

- **Kind** : `30800`
- **d-tag** : `cooperative-config`
- **Clés JSON** : `OVH_APP_KEY`, `OVH_APP_SECRET`, `OVH_CONSUMER_KEY`, `OVH_ZONE`
- **Chiffrement** : AES-256-CBC, IV aléatoire 16 octets, clé = `SHA256($UPLANETNAME)`
- **Format stocké** : `<iv_hex>:<ciphertext_base64>`

Fonctions associées (`cooperative_config.sh`) :

| Fonction | Description |
|---|---|
| `coop_config_set "OVH_APP_SECRET" "val"` | Chiffre et publie dans Kind 30800 |
| `coop_config_get "OVH_APP_SECRET"` | Récupère et déchiffre depuis Kind 30800 |
| `coop_load_env_from_config` | Exporte toutes les vars OVH dans l'ENV |
| `coop_config_list` | Liste les clés (valeurs chiffrées masquées) |
| `coop_config_list_decrypted` | Liste les clés avec valeurs en clair |

---

## CLI `ovh.me.sh`

Outil d'administration standalone pour les records DNSLink OVH.

```
Usage : ovh.me.sh <commande> [args...]
```

| Commande | Arguments | Description |
|---|---|---|
| `list` | `[zone]` | Liste tous les records `_dnslink.*` de la zone |
| `get` | `<sub> [zone]` | Affiche le record TXT d'un subdomain |
| `create` | `<sub> <target> [zone]` | Crée un record (erreur si existant) |
| `update` | `<sub> <target> [zone]` | Met à jour (erreur si absent) |
| `upsert` | `<sub> <target> [zone]` | Crée ou met à jour (recommandé) |
| `delete` | `<sub> [zone]` | Supprime un record |

### Normalisation des sous-domaines

| Entrée | Résultat |
|---|---|
| `alice` | `_dnslink.alice` |
| `_dnslink` | `_dnslink` |
| `_dnslink.origin` | `_dnslink.origin` |

### Normalisation des targets

| Entrée | Résultat |
|---|---|
| `/ipns/k51q...` | `dnslink=/ipns/k51q...` |
| `/ipfs/Qm...` | `dnslink=/ipfs/Qm...` |
| `k51q...` | `dnslink=/ipns/k51q...` (IPNS base36 détecté) |
| `Qm...` / `bafy...` | `dnslink=/ipfs/...` |
| `dnslink=...` | inchangé |

---

## Fichiers concernés

| Fichier | Rôle |
|---|---|
| `Astroport.ONE/admin/system/ovh.me.sh` | CLI DNSLink OVH — toutes les opérations CRUD |
| `UPlanet/microledger.me.sh` | Publication IPFS — délègue le DNSLink à `ovh.me.sh` |
| `Astroport.ONE/tools/make_NOSTRCARD.sh` | Création MULTIPASS — appelle `ovh.me.sh upsert` pour `/ipns/$NOSTRNS` |
| `Astroport.ONE/RUNTIME/NOSTRCARD.refresh.sh` | Refresh MULTIPASS — republication IPNS + appel `ovh.me.sh upsert` |
| `Astroport.ONE/tools/cooperative_config.sh` | Gestion Kind 30800 — stockage/lecture credentials |
| `UPlanet/earth/coop-config.js` | Interface web Kind 30800 — section DNSLink OVH dans economy.html |
| `UPlanet/earth/economy.html` | Dashboard coopératif — inclut coop-config.js |
