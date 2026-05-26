# WoTx2 — Toiles de Confiance Décentralisées

**Version** : 2.1 — Architecture Duale Oracle + P2P + MineLife Interface  
**Mise à jour** : Mai 2026  
**Statut** : Production  
**License** : AGPL-3.0

> Pour la description complète des kinds NOSTR, clés, schémas et flows, voir **[MINELIFE.md](../how-to/MINELIFE.md)**.

---

## Architecture Duale

WoTx2 fonctionne en deux modes complémentaires :

- **Mode Oracle** : Kind 30503 signé par `UPLANETNAME_G1` — émis par `ORACLE.refresh.sh`
- **Mode P2P** : Kind 30503 auto-signé par le titulaire — calculé localement (TrocZen, MineLife)

Les deux modes coexistent sur le même relay NOSTR. Voir [MINELIFE.md §2](../how-to/MINELIFE.md) pour le format exact de chaque Kind.

---

## Compétences Capitaines (Seeds)

Initialisées par `oracle_init_captain_wotx2.sh` (appelé depuis `install.sh`) :

| Skill Tag | Permit X1 |
|-----------|-----------|
| `astroport` | `PERMIT_ASTROPORT_X1` |
| `linux` | `PERMIT_LINUX_X1` |
| `bash` | `PERMIT_BASH_X1` |
| `python` | `PERMIT_PYTHON_X1` |
| `docker` | `PERMIT_DOCKER_X1` |
| `dart` | `PERMIT_DART_X1` |
| `flutter` | `PERMIT_FLUTTER_X1` |
| `nostr` | `PERMIT_NOSTR_X1` |
| `ipfs` | `PERMIT_IPFS_X1` |
| `git` | `PERMIT_GIT_X1` |

---

## Règles de Progression

- **Règle A** : 3 réactions Kind 7 `+` distinctes → auto-signer Kind 30503
- **Règle B** : 1 Kind 30502 d'un pair niveau X1+ → montée directe
- **Règle C** (Oracle) : `ORACLE.refresh.sh` émet Kind 30503 Oracle quand seuil `min_attestations` atteint

---

## Agnosticisme sur les Clés

Un Kind 30503 est valide quel que soit son signataire (Oracle, auto-signé, capitaine). Vérification dans l'ordre :

```
Attester valide pour PERMIT_SKILL_Xn ?
  ├─ Oracle VC  : tag ["l", "PERMIT_SKILL_Xm", "permit_type"] (m ≥ n)
  ├─ TrocZen P2P: pubkey = attester + tag ["d", "PERMIT_SKILL_Xm"] (m ≥ n)
  └─ Folksonomie: pubkey = attester + tag ["t", skill] + tag ["level"] ≥ n
```

---

## Bootstrap Capitaine

À la fin de `install.sh`, `oracle_init_captain_wotx2.sh` :
1. Crée les Kind 30500 des compétences capitaines prédéfinies
2. Propose au capitaine ses compétences initiales
3. Oriente vers `minelife.html`

---

## Interface

| Interface | Fichier | Description |
|-----------|---------|-------------|
| **MineLife** | `earth/minelife.html` | Dashboard principal — crafting + formation + BRO |
| **TrocZen** | Flutter app | Mobile P2P — Règle A/B, synthèse, WoTx2 offline |

---

## Kind 30504 — Ressource de formation

Spec complète dans [NOSTR_EVENTS_REFERENCE.md](NOSTR_EVENTS_REFERENCE.md).

**Tags obligatoires :** `d` (identifiant), `t` (skill), `r` (CID IPFS + type).

**Payload Qdrant (collection `knowledge`) :**

```json
{
  "cid":        "QmXxx...",
  "title":      "Guide Docker",
  "skill":      "docker",
  "author_hex": "<pubkey_hex_64>",
  "event_id":   "<event_hex_64>",
  "kind":       30504,
  "created_at": 1748000000
}
```

**Structure Nextcloud pour l'indexation (`--index-dir`) :**

```
~/nextcloud/Astroport/
├── linux/          ← skill = "linux"
│   ├── guide.md
│   └── debian.pdf
├── docker/         ← skill = "docker"
│   └── compose.md
└── ipfs/           ← skill = "ipfs"
    └── kubo.pdf
```

Le nom du sous-dossier est la valeur du tag `t` dans le Kind 30504 généré.

---

## Modèles Ollama — Embedding vs Génération

| Rôle | Modèle | Taille |
|------|--------|--------|
| **Embedding** (indexation Qdrant) | `nomic-embed-text` | ~274 Mo |
| **Génération BRO skill** | `gemma3:latest` | ~3.3 Go |
| **Génération code** | `qwen2.5-coder:14b` | ~9 Go |

---

## TTL inter-NODE (NIP-40) — canaux `nostr_node_intercom.py`

| Canal | TTL | Raison |
|-------|-----|--------|
| `bro_ia` | 3 600 s | Commande traitée immédiatement ou abandonnée |
| `comfyui_job` | 7 200 s | Fenêtre GPU max |
| `comfyui_result` | 3 600 s | Récupération avant expiration |
| `udrive` | 86 400 s | Sync fichier moins urgent |
| `zen_like` | 86 400 s | Paiement relayé dans la journée |

---

## Références

- **[NOSTR_EVENTS_REFERENCE.md](NOSTR_EVENTS_REFERENCE.md)** — Spec complète Kind 30500–30504
- **[how-to/MINELIFE.md](../how-to/MINELIFE.md)** — Utiliser l'interface
- **[how-to/KNOWLEDGE_EMBEDDINGS.md](../how-to/KNOWLEDGE_EMBEDDINGS.md)** — Indexer les ressources
- **[explanation/minelife_wikipedia_wot.md](../explanation/minelife_wikipedia_wot.md)** — Philosophie WoT
- `Astroport.ONE/tools/oracle_init_captain_wotx2.sh` — Bootstrap capitaines
- `Astroport.ONE/RUNTIME/ORACLE.refresh.sh` — Oracle quotidien
- `TrocZen/docs/WOTX2_SYSTEM.md` — Architecture P2P TrocZen v3.6
- `nostr-nips/42-oracle-permits-extension.md` — Spec NOSTR permits
