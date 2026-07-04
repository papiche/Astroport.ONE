# bro_watch_core.py

Bibliothèque Python partagée (~2300 lignes) qui constitue le cerveau de **BRO**, le clone numérique personnel de chaque sociétaire MULTIPASS. Elle est importée par tous les scrapers cookie et par le daemon `bro_dm_daemon.sh`.

BRO n'est pas une identité séparée : il signe et chiffre toujours avec la propre clé MULTIPASS du propriétaire. Les messages apparaissent comme des notes personnelles dans son historique NOSTR, déchiffrables uniquement par lui.

---

## Architecture en cinq axes

### 1. Surveillance passive — `process_watch_digest()`

Point d'entrée quotidien des scrapers (Mastodon, Discourse, YouTube…).

```
scraper DOMAIN.sh [owner_email] [cookie_file]
  → items : [{username, text, url}, ...]
    → process_watch_digest(owner_email, account, channel, items, own_posts)
        ├─ resolve_pending_feedback()       ← rétroaction de la veille
        ├─ learn_from_message()             ← si learn_from configuré
        ├─ matches_keywords()               ← exact puis sémantique Qdrant
        ├─ generate_suggestion()            ← Ollama via question.py
        ├─ _record_pending_suggestion()     ← pour la prochaine rétroaction
        ├─ send_dm_to_owner()               ← DM kind 4 NIP-44
        └─ store_log()                      ← log chiffré G1 + pin IPFS
```

### 2. Commandes entrantes — `process_incoming_commands()`

Boucle principale, appelée par `bro_dm_daemon.sh` à chaque nouveau DM. Récupère les kind 4 self-DM depuis le relay (websockets async, tous relais) depuis le dernier `last_check`, puis pour chaque event :

```
_fetch_self_dms_since(since_ts)
  → _decrypt_self_dm()                 ← nostr_node_intercom.py decrypt
  → _claim_event_id()                  ← dédup atomique O_CREAT|O_EXCL
  → filtre BOT_REPLY_MARKERS + tag ["client","bro"]  ← anti-boucle
  → _handle_command_text(text)
      ├─ #arbor → _trigger_arbor_self_improve()    ← capitaine seulement
      ├─ #image/#video/#plant/… → _handle_ia_responder_tags()
      ├─ match_intent() → _execute_system_tag()    ← #mem #rec #reset #help…
      ├─ _interpret_natural_command()              ← Ollama qwen2.5-coder:14b
      │     → _sanity_check_action()              ← garde-fou lexical
      │     → _execute_interpreted_action()
      ├─ _handle_hashtag_command()                 ← fallback syntaxe directe
      ├─ _try_registered_tools()                   ← outils Arbor activés
      └─ _conversational_reply()                   ← mémoire slot 13 + LLM
  → send_dm_to_owner()                 ← réponse
  → _remember_exchange()               ← persist slot 13
  → check_proactive_alerts()           ← détecteurs (solde G1…)
```

### 3. Apprentissage des mots-clés

`learn_from_message()` : quand `learn_from = "@quelqu'un"`, les posts de cette personne alimentent un LLM qui extrait 5-10 mots-clés thématiques (`learned_keywords`). Fenêtre glissante de 20 messages. Ne déclenche jamais d'alerte directe.

`matches_keywords()` : teste d'abord les mots-clés exacts (manuel + appris), puis en repli `semantic_match()` via Qdrant (collection `bro_watch_topics`, nomic-embed-text, seuil 0.70).

### 4. Boucle de rétroaction

`resolve_pending_feedback()` compare via similarité cosinus Qdrant les suggestions en attente avec les vraies réponses publiées ensuite par le propriétaire (`own_posts`). Trois issues : `used`, `used_modified`, `ignored` (fenêtre 5 jours). Les exemples `used`/`used_modified` enrichissent le few-shot de `generate_suggestion()` (appel `get_good_examples()`).

### 5. Routage d'intention sémantique — `match_intent()`

Deux collections Qdrant :
- `bro_watch_topics` — mots-clés de surveillance par canal
- `bro_intent_routing` — corpus figé de commandes système + négatifs partagés

Décision par **marge** (meilleur score positif − meilleur score négatif partagé, seuil 0.05) plutôt que par seuil absolu — calibré après un incident prod où "#reset" et "#météo" scoraient à 0.007 d'écart sur seuil fixe.

---

## Fonctions publiques

| Fonction | Rôle |
|---|---|
| `process_watch_digest(owner_email, account, channel, items, ...)` | Point d'entrée scrapers — filtre, suggère, DM |
| `process_incoming_commands(owner_email)` | Boucle principale commandes self-DM |
| `send_dm_to_owner(owner_email, message, ttl_days)` | DM kind 4 NIP-44 self-DM |
| `matches_keywords(entry, text, ...)` | Match exact + repli Qdrant |
| `semantic_match(owner_email, account, channel, entry, text)` | Similarité Qdrant/Ollama |
| `learn_from_message(owner_email, entry, account, channel, text)` | Apprentissage mots-clés LLM |
| `generate_suggestion(context_label, username, text, examples)` | Suggestion réponse via Ollama |
| `resolve_pending_feedback(owner_email, account, own_posts)` | Rétroaction suggestions |
| `get_good_examples(owner_email, account, limit)` | Few-shot : dernières suggestions utilisées |
| `match_intent(text)` | Route vers commande système (marge Qdrant) |
| `interpret_command_with_context(text, context_summary, ...)` | Parse intention via LLM (testable sans I/O) |
| `format_context_entries(entries)` | Formate le contexte pour le prompt LLM (pure, testable) |
| `load_watch_data(owner_email, account)` | Lit config surveillance d'un domaine |
| `save_watch_data(owner_email, account, data)` | Persiste config |
| `get_watch_entry(owner_email, account, channel)` | Entrée d'un canal |
| `ensure_watch_entry(owner_email, account, channel, **defaults)` | Crée canal si absent (onboarding) |
| `update_watch_entry(owner_email, account, channel, **fields)` | Met à jour un canal |
| `is_scraper_enabled(owner_email, account)` | Scraper actif ? |
| `set_scraper_enabled(owner_email, account, enabled)` | Active/désactive |
| `store_log(owner_email, account, log_text)` | Chiffre log + pin IPFS + manifest |
| `get_log(owner_email, account)` | Déchiffre dernier log IPFS |
| `check_proactive_alerts(owner_email)` | Alertes automatiques (solde G1…) |
| `activate_tool(module_name, description)` | Active outil Arbor généré |
| `deactivate_tool(module_name)` | Désactive outil Arbor |
| `list_active_tools()` | Outils Arbor activés |

---

## Format du manifest

Fichier unique par sociétaire : `~/.zen/game/nostr/EMAIL/.cookie_manifest.json`  
Publié en NOSTR **kind 31903** `d=cookies` à chaque écriture (même fichier que `cookie_store.py`).

```json
{
  "mastodon.social": {
    "cid": "Qm...",
    "uploaded_at": "2026-07-01T12:00:00Z",
    "size": 919,
    "enabled": true,
    "params": {
      "channels": [
        {
          "channel": "notifications",
          "keywords": ["jardin", "permaculture"],
          "learned_keywords": ["compost", "légumes anciens"],
          "learn_from": "alice",
          "learn_messages": ["msg1", "msg2"],
          "always_alert": false,
          "pending_feedback": [
            {
              "channel": "notifications",
              "url": "https://mastodon.social/@bob/123",
              "original_text": "Découvert ce super guide…",
              "original_username": "@bob",
              "suggestion": "Bonne idée !",
              "created_at": "2026-07-03T10:00:00+00:00",
              "resolved": true,
              "outcome": "used_modified",
              "actual_text": "Excellente piste, merci !",
              "match_score": 0.891
            }
          ]
        }
      ]
    },
    "log_cid": "Qm..."
  },
  "_bro_commands": {
    "last_check": 1751634201
  }
}
```

**Clés `_` (underscore)** : métadonnées internes, pas des domaines. Filtrées partout (`startswith("_")`).

---

## Intégrations externes

| Système | Usage | Dégradation |
|---|---|---|
| **NOSTR kind 4** (NIP-44) | DM chiffré self-DM (envoi + écoute) | silencieuse |
| **NOSTR kind 31903** | Manifest cookie (publie à chaque écriture) | silencieuse |
| **strfry** ws://127.0.0.1:7777 | Relay local NOSTR | fallback relay public |
| **IPFS** | Pin logs chiffrés, récupère manifest | disk fallback |
| **natools.py seal** | Chiffrement logs avec clé G1 du propriétaire | log non stocké |
| **Qdrant** localhost:6333 | Embeddings mots-clés + routage intentions + mémoire | pas de match sémantique |
| **Ollama** (nomic-embed-text) | Vecteurs 768 dims | pas de match sémantique |
| **Ollama** (qwen2.5-coder:14b) | Interprétation commandes en LN (`--format-json`) | fallback hashtag |
| **question.py** | Suggestions réponse, apprentissage, conversation | message d'erreur |
| **G1wallet_v2.sh** | Solde Ğ1 (alertes proactives) | pas d'alerte |
| **nostr_send_secure_dm.py** | Signature + publication DM NIP-44 | DM non envoyé |
| **nostr_node_intercom.py** | Déchiffrement DM reçus | event ignoré |
| **generators/** | ComfyUI image, vidéo, musique, speech | réponse textuelle |

---

## Seuils calibrés

| Constante | Valeur | Usage |
|---|---|---|
| `SEMANTIC_THRESHOLD` | 0.70 | Match sémantique mots-clés (nomic-embed-text) |
| `INTENT_MARGIN_THRESHOLD` | 0.05 | Marge pos−négatif pour commandes système |
| `MEMORY_RECALL_THRESHOLD` | 0.72 | Rappel souvenirs slot 13 |
| `TOOL_MATCH_THRESHOLD` | 0.63 | Routage outils Arbor |
| `FEEDBACK_MATCH_THRESHOLD` | 0.75 | Résolution suggestion (used/used_modified) |
| `FEEDBACK_VERBATIM_THRESHOLD` | 0.90 | `used` vs `used_modified` |
| `LOW_G1_BALANCE_THRESHOLD_CENTIMES` | 100 | Alerte solde Ğ1 bas |
| `DM_TTL_DAYS` | 7 | TTL NIP-40 des DMs envoyés |
| `FEEDBACK_WINDOW_DAYS` | 5 | Expiration suggestion → `ignored` |

---

## Garanties anti-boucle

BRO lit et écrit sur le même canal. Trois couches de protection :

1. **Tag structurel** `["client", "bro"]` sur tous les events émis par BRO — filtré en premier dans `_fetch_self_dms_since`.
2. **`BOT_REPLY_MARKERS`** `("📋", "✅", "🤔", "💬", "🔔")` — repli pour les events anciens ou émis par un chemin qui omettrait le tag. `💬` est critique : un message conversationnel libre (`_conversational_reply`) commençant par `💬` qui ne serait pas filtré générerait une réponse à sa propre réponse, indéfiniment (boucle constatée en prod : des centaines de DMs en quelques minutes).
3. **Dédup atomique par event ID** — marqueur `O_CREAT|O_EXCL` dans `~/.zen/tmp/bro_command_dedup/` — corrige un second incident (2026-07-04) où deux processus traitaient le même event simultanément malgré le flock bash. Un JSON read-modify-write ne suffit pas : deux processus peuvent lire avant que l'un n'écrive.

---

## Outils Arbor

Outils générés dynamiquement par `arbor_tool_forge.py`, stockés dans `IA/tools_generated/*.py`. Contrat : `def run(query: str) -> str`.

Activation explicite par le capitaine seulement (jamais automatique) :
```python
activate_tool("my_weather_tool", "Récupère la météo locale")
deactivate_tool("my_weather_tool")
```

Registre runtime : `~/.zen/flashmem/bro_active_tools.json` (hors dépôt git).

Routage via `match_tool(text)` (Qdrant, seuil 0.63). Les demandes non matchées sont loggées dans `~/.zen/flashmem/bro_tool_requests.jsonl` et minées par `arbor_self_improve.py --mine-requests` pour détecter des besoins récurrents.

---

## Mémoire épisodique

Slot **13** dans Qdrant (slots 0-12 réservés aux mémoires société). Persiste les échanges self-DM (texte + réponse), rappel sémantique au prochain message (seuil 0.72), effacement via `#oublie`. Compression cyclique via le mécanisme de RÊVE existant.

---

## Appel depuis un scraper (exemple minimal)

```python
from bro_watch_core import process_watch_digest, ensure_watch_entry

owner_email = "alice@example.com"
account = "mastodon.social"
channel = "notifications"

# Onboarding automatique si premiere fois
ensure_watch_entry(owner_email, account, channel, always_alert=True)

# Items récupérés par le scraper cookie
items = [
    {"username": "@bob", "text": "Super article sur le compost !", "url": "https://..."},
]
own_posts = [
    {"text": "Merci pour ce partage bob !"}
]

process_watch_digest(owner_email, account, channel, items, own_posts=own_posts)
```

---

## Fichiers liés

| Fichier | Rôle |
|---|---|
| `IA/bro_dm_daemon.sh` | Daemon inotify — appelle `process_incoming_commands()` |
| `IA/question.py` | Interface Ollama (suggestions, interprétation, conversation) |
| `IA/nostr_node_intercom.py` | Déchiffrement DM NIP-44 |
| `IA/memory_manager.py` | Gestion slots mémoire Qdrant |
| `IA/arbor_self_improve.py` | Auto-amélioration prompt interprétation (capitaine) |
| `IA/arbor_tool_forge.py` | Génération outils Web2 sur demande |
| `IA/tools_generated/` | Outils Arbor activables (`.py`, `def run(query)`) |
| `IA/tests/bro_watch_command_eval.json` | Harnais d'évaluation `interpret_command_with_context` |
| `tools/nostr_send_secure_dm.py` | Publication DM kind 4 NIP-44 |
| `tools/natools.py` | Chiffrement seal box (clé G1) |
| `UPassport/services/cookie_store.py` | Même manifest, même kind 31903 |
| `docs/how-to/BRO_HELP_COMMANDS.md` | Source de vérité des commandes BRO (#help, #mem, etc.) |
