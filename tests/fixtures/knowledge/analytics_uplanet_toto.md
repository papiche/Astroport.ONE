# Analytics UPlanet — Guide Praticien

**Auteur** : toto (support+toto@qo-op.com)
**Skill** : analytics-uplanet
**Niveau** : X1 — Fondamentaux

---

## Présentation du système (`astro.js`)

Le système Analytics UPlanet (`astro.js`) collecte les usages de l'écosystème via
deux canaux complémentaires :

1. **HTTP `/ping`** — POST REST vers l'API UPassport (Web2, fallback)
2. **NOSTR Kind 10600** — Événements signés sur relays (Web3, recommandé)

> ⚠️ Kind 10000 est réservé par NIP-51 (mute lists).
> UPlanet Analytics utilise le Kind **10600** (pas 10000).

---

## Les 3 modes d'opération

### Mode 1 : Standalone (`astro.js` seul)

Envoie via HTTP POST à l'endpoint `/ping` de UPassport (port 54321).
Aucune dépendance. Idéal pour sites Web2 sans extension NOSTR.

```javascript
uPlanetAnalytics.send({ type: 'page_view', source: 'email', email: 'user@ex.com' });
uPlanetAnalytics.sendWithContext({ type: 'multipass_card_usage' });
uPlanetAnalytics.autoSend({ type: 'page_view', source: 'web' });
```

Limitations : stockage centralisé, pas de vérification cryptographique.

### Mode 2 : avec `common.js` (NOSTR non-chiffré)

Publie un Kind 10600 signé par l'utilisateur sur le relay NOSTR.
Stockage décentralisé, vérifiable, interrogeable via filtres NOSTR standards.

```javascript
uPlanetAnalytics.sendAsNostrEvent({ type: 'button_click', button_id: 'monBouton' });
uPlanetAnalytics.smartSend({ type: 'page_view', source: 'web' }, true, true, false);
```

### Mode 3 : avec `common.js` + `nostr.bundle.js` (Chiffré NIP-44)

Chiffre les données sensibles avec NIP-44 (ChaCha20-Poly1305).
Seul l'utilisateur peut déchiffrer ses propres analytics (clé privée requise).

```javascript
uPlanetAnalytics.sendEncryptedAsNostrEvent({ type: 'navigation_history', source: 'web' });
// Variante IPFS (données > 50 Ko) :
uPlanetAnalytics.sendEncryptedAsNostrEventWithIPFS({ type: 'navigation_history' });
```

---

## Structure d'un événement Kind 10600

```json
{
  "kind": 10600,
  "content": "{\"type\":\"page_view\",\"source\":\"email\",\"timestamp\":\"2024-...\"}",
  "tags": [
    ["t", "analytics"],
    ["t", "page_view"],
    ["source", "email"],
    ["email", "user@example.com"]
  ],
  "created_at": 1704110400,
  "pubkey": "<pubkey_hex>",
  "id": "<event_id_hex>",
  "sig": "<signature>"
}
```

Les données sensibles (email, URL) vont dans `content` (chiffré en Mode 3).
Les métadonnées publiques (type, source) vont dans `tags`.

---

## Transformations d'URL automatiques (`getUSPOTBaseURL`)

| Origine (fenêtre browser) | Destination uSPOT |
|---------------------------|-------------------|
| `https://ipfs.mondomaine.tld` | `https://u.mondomaine.tld` |
| `https://u.mondomaine.tld` | `https://u.mondomaine.tld` (inchangé) |
| `http://127.0.0.1:8080` | `http://127.0.0.1:54321` |
| `http://localhost:8080` | `http://localhost:54321` |

La fonction `getUSPOTBaseURL()` calcule automatiquement l'URL correcte
à partir de `window.location.href`.

---

## Fonction `smartSend` — Sélection automatique

```javascript
smartSend(data, includeContext, preferNostr, preferEncrypted, preferIPFS)
```

Ordre de priorité automatique :
1. **NOSTR chiffré** (si `nostr.bundle.js` chargé + clé privée dispo)
2. **NOSTR non-chiffré** (si `common.js` + relay connecté)
3. **HTTP `/ping`** (fallback universel)

Erreurs : toutes silencieuses (`console.debug`), l'UI n'est jamais bloquée.

---

## Données de contexte automatiques (`getPageContext`)

```json
{
  "timestamp": "2024-01-01T12:00:00.000Z",
  "current_url": "https://ipfs.mondomaine.tld/...",
  "user_agent": "Mozilla/5.0 ...",
  "viewport": { "width": 1920, "height": 1080 },
  "referer": "https://...",
  "uspot_url": "https://u.mondomaine.tld"
}
```

---

## Comparatif des modes

| Fonctionnalité | Mode 1 | Mode 2 | Mode 3 |
|----------------|--------|--------|--------|
| HTTP `/ping` | ✅ | ✅ | ✅ |
| NOSTR Kind 10600 | ❌ | ✅ | ✅ |
| Chiffrement NIP-44 | ❌ | ❌ | ✅ |
| Stockage décentralisé | ❌ | ✅ | ✅ |
| Confidentialité | ❌ | ❌ | ✅ |
| Dépendances | aucune | `common.js` | `common.js` + `nostr.bundle.js` |

---

## Questions clés pour l'examen BRO

**Q1** : Quel Kind NOSTR est utilisé par UPlanet Analytics ?
→ **Kind 10600** (pas 10000 qui est réservé par NIP-51)

**Q2** : Que fait `smartSend` si NOSTR n'est pas disponible ?
→ **Fallback HTTP POST vers /ping** (UPassport port 54321)

**Q3** : Quelle URL correspond au browser `ipfs.mondomaine.tld` pour l'API ?
→ **u.mondomaine.tld** (port 54321)

**Q4** : Quel algorithme de chiffrement est utilisé en Mode 3 ?
→ **NIP-44 (ChaCha20-Poly1305)**

**Q5** : Pourquoi préférer le Mode 2/3 au Mode 1 pour un nouveau projet ?
→ **Décentralisation, vérifiabilité cryptographique, pas de point de défaillance unique**

**Q6** : Où vont les données sensibles dans un événement Kind 10600 chiffré ?
→ **Dans `content` (chiffré), les métadonnées publiques dans `tags`**
