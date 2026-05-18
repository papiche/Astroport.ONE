# Analytics Décentralisé — astro.js & Kind 10600

**Problème** : les plateformes d'analytics classiques (Google Analytics, Plausible hébergé) transmettent les données comportementales des utilisateurs à des tiers. Sur une station Astroport.ONE, c'est inacceptable — les données restent dans la constellation.

**Solution** : `astro.js` collecte les métriques de page et les publie sous forme d'événements NOSTR **Kind 10600**, chiffrés avec NIP-44, stockés exclusivement sur le relay local.

---

## Pourquoi ce choix d'architecture

### NIP-44 + relay local = zéro fuite

Les événements Kind 10600 sont chiffrés via `nip44.utils.getConversationKey(stationPrivkey, userPubkey)`. Sans la clé privée de la station, aucun observateur extérieur ne peut lire les métriques — même en cas d'interception du relay.

```
┌──────────────┐   NIP-44 encrypt    ┌───────────────────┐
│  astro.js    │  ────────────────►  │  Kind 10600 event  │
│  (browser)   │                     │  relay local 7777  │
└──────────────┘                     └───────────────────┘
       ↑                                       ↑
  Page events                       Accessible only with
  (view, click, scroll)             station private key
```

### Pourquoi Kind 10600 ?

Les Kinds 10000–19999 sont des événements remplaçables (*replaceable*) dans le protocole NOSTR. Pour les analytics, cela signifie que chaque session écrase la précédente — pas d'accumulation illimitée de micro-événements. L'armateur conserve un instantané de l'activité récente sans saturer le relay.

---

## Structure d'un événement Kind 10600

```json
{
  "kind": 10600,
  "content": "<NIP-44 encrypted payload>",
  "tags": [
    ["t", "analytics"],
    ["encryption", "nip44"],
    ["p", "<userPubkey>"]
  ]
}
```

Le payload chiffré contient :
```json
{
  "url": "https://ipfs.domain.tld/earth/index.html",
  "referrer": "",
  "duration": 42,
  "events": ["pageview", "click:#bro-btn"],
  "timestamp": 1716000000
}
```

---

## Implémentation dans astro.js

`astro.js` est injecté dans les pages UPlanet qui souhaitent collecter des métriques. Il :

1. Récupère `window.userPubkey` et `window.stationPrivkey` (fournis par `common.js`)
2. Construit la conversation key : `nip44.utils.getConversationKey(stationPrivkey, userPubkey)`
3. Chiffre le payload avec `nip44.encrypt(payload, conversationKey)`
4. Publie l'événement Kind 10600 sur `window.nostrRelay`

Le fichier source : [`WWW/js/astro.js`](../../WWW/js/astro.js)

---

## Lecture des métriques

Pour consulter vos métriques :

```bash
# Lire les derniers events Kind 10600 depuis le relay local
cd ~/.zen/strfry && ./strfry scan '{"kinds":[10600]}' | jq '.content' | head -20

# Ou via la console NOSTR
firefox http://localhost:12345/nostr_console.html
```

Puisque les events sont chiffrés, la lecture nécessite la clé privée de la station (disponible localement dans `~/.zen/game/players/.current/`).

---

## Comparaison avec les alternatives

| Solution | Hébergement | Vie privée | NOSTR-natif |
|---------|-------------|-----------|-------------|
| Google Analytics | GAFAM | ❌ | ❌ |
| Plausible (cloud) | Tiers | ⚠️ | ❌ |
| Plausible (self-hosted) | Vous | ✅ | ❌ |
| **astro.js + Kind 10600** | **Relay local** | **✅** | **✅** |

L'avantage distinctif d'astro.js : les métriques font partie du graphe social NOSTR de la station. Elles peuvent être corrélées avec les événements de contenu (Kind 1, Kind 30023) pour comprendre quels articles génèrent de l'engagement — sans jamais quitter la constellation.

---

## Voir aussi

- [Référence Kind 10600](../reference/Analytics.README.md) — spécification technique complète
- [NOSTR Events Reference](../reference/NOSTR_EVENTS_REFERENCE.md) — tous les kinds utilisés dans UPlanet
- [feedback.js](../../WWW/js/feedback.js) — système de remontée de bugs (NIP-07 + GitHub)
