# Tests UPlanet / Astroport.ONE

Suite de tests complète pour valider tous les sous-systèmes UPlanet.

## Lancer les tests

```bash
# Depuis la racine du dépôt
./tests/test_all_systems.sh                     # statiques uniquement (CI-safe)
./tests/test_all_systems.sh --verbose           # avec sortie détaillée
./tests/test_all_systems.sh --live              # + intégration réseau (relay + IPFS)
./tests/test_all_systems.sh --ai                # + Ollama / ComfyUI
./tests/test_all_systems.sh --demo              # + scénarios (crée des données réelles)
./tests/test_all_systems.sh --system multipass  # un seul test ciblé
```

## Catalogue complet

### Tiers 1 — STATIQUE (sans infra, CI-safe)

| Script | `--system` | Ce qui est testé |
|--------|-----------|-----------------|
| `test_multipass_zencard.sh` | `multipass` | SALT/PEPPER, `_diceware()`, `_alert_captain()`, NOMAIL, g1.sh JSON, Connect_PLAYER retiré, identity.py `_DISCO_RAND` |
| `test_did_system.sh` | `did` | Documents DID, résolution (NOSTR/IPFS/cache), mises à jour, UMAP DID, conformité W3C DID Core 1.1 |
| `test_oracle_system.sh` | `oracle` | Définition permis (kind 30500), demande (30501), attestation (30502), credential (30503), badge (30009/8), filtre IPFSNODEID |
| `test_wotx2_system.sh` | `wotx2` | Permis WoTx2 (PERMIT_*_X1), auto-progression X1→X2→X3, PERMIT_DRAGON, NIP-42, filtre IPFSNODEID |
| `test_ore_system.sh` | `ore` | UMAP DID (kind 30800), contrat ORE, Meeting Space (30312), Verification Meeting (30313), badge ORE |
| `test_badge_system.sh` | `badge` | Définition (kind 30009), award (kind 8), profil badges (30008), génération image, synchronisation |
| `test_g1_tools.sh` | `g1tools` | G1balance.sh, G1check.sh, G1history.sh, G1primal.sh, PAYforSURE.sh, gcli CLI, duniter_getnode.sh |
| `test_primal_control.sh` | `primal` | `primal_wallet_control.sh` : `get_intrusion_pubkey()` SS58, seuils, garde-fous DRAIN |
| `test_ss58_integration.sh` | `ss58` | Conversion v1↔SS58, `normalize_pubkey()` natools.py, PAYforSURE DRAIN, NaCl encrypt/box round-trip |
| `test_astrosystemctl.sh` | `astrosystemctl` | Fonctions pures, parsing `modules.list`, `_local_check` profils, résolution scripts `cmd_local install`, gestion erreurs |
| `test_destroy_restore.sh` | `destroy` | Backup `secret.june` numéroté, chiffrement/déchiffrement clé UPlanet, structure backup, RESTORE : détection CID + restauration |

> `test_destroy_restore.sh --offline` ignore les tests IPFS/relay (défaut en mode `test_all_systems.sh`).

---

### Tiers 2 — INTÉGRATION (`--live`, relay NOSTR + IPFS requis)

| Script | `--system` | Ce qui est testé |
|--------|-----------|-----------------|
| `test_intercom.sh` | `intercom` | Imports Python `nostr_node_intercom.py`, payload zen_like, daemon `bro_dm_daemon.sh`, loopback coucou→toto (TTL 300s), `bro_ia #IA`, ComfyUI job |
| `test_multipass_create.sh` | `create` | Chaîne complète MULTIPASS : keygen→NOSTR→ẐEN pour 3 comptes déterministes, vérif Kind 0 relay, solde G1 |

> `--quick` disponible sur ces deux tests pour n'exécuter que les assertions réseau-free.
>
> ```bash
> bash tests/test_intercom.sh --quick
> bash tests/test_multipass_create.sh --quick
> ```

---

### Tiers 3 — IA (`--ai`, Ollama/ComfyUI requis)

| Script | `--system` | Ce qui est testé |
|--------|-----------|-----------------|
| `test_ollama.sh` | `ollama` | Connexion `ollama.me.sh` (local→SSH→IPFS P2P), `/api/tags`, génération texte (`question.py`), multilingue, vision (moondream/llava), canal DM `bro_ia` |
| `test_comfyui.sh` | `comfyui` | Connexion `comfyui.me.sh`, `/system_stats`, queue depth, VRAM, workflow `FluxImage.json`, génération image, CID IPFS, canal DM `comfyui_job` |

---

### Tiers 4 — SCÉNARIOS (`--demo`, crée des données réelles)

| Script | `--system` | Ce qui est testé |
|--------|-----------|-----------------|
| `test_knowledge_demo.sh` | `knowledge` | Publication Kind 30504 sur relay NOSTR, indexation Qdrant collection "knowledge", recherche sémantique par skill |
| `test_minelife_captain.sh` | `minelife` | Scénario MineLife complet : coucou+jean+toto → Capitaine obtient "analytics-uplanet" |
| `test_wotx2_demo.sh` | `wotx2demo` | Dataset démo WoTx2 (Skills+Craft) : 3 comptes déterministes, toutes les fonctions `minelife.html` |
| `test_umap_cities.sh` | `umap` | Activation UMAP sur grandes villes françaises, récup opportunités G1+Leboncoin, articles Kind 30023 |
| `test_captain_validation.sh` | `captain` | Validation Capitaine complète : PERMIT_X1, requête, attestation, credential, badge, contrat ORE, boucle UPlanet |

> **Avertissement** : ces scénarios publient des événements NOSTR réels et écrivent dans `~/.zen/`. Nettoyer avec `cleanup_test_events.sh`.

---

## Utilitaires

| Fichier | Rôle |
|---------|------|
| `test_common.sh` | Bibliothèque partagée : `assert_*`, `test_log_*`, couleurs |
| `run_tests.sh` | Lance tous les `test_*.sh` sans filtrage (glob simple) |
| `cleanup_test_events.sh` | Supprime les événements NOSTR créés par les scénarios |
| `test_ss58_integration.py` | Tests unitaires Python NaCl/duniterpy (complémentaire à `test_ss58_integration.sh`) |
| `fixtures/` | Données de référence pour les tests |

---

## Prérequis

### Variables d'environnement
Chargées par `tools/my.sh` (sourcé automatiquement si station démarrée) :
```bash
CAPTAINEMAIL      # email du capitaine
IPFSNODEID        # identifiant du nœud IPFS
UPLANETNAME_G1    # clé d'autorité G1 UPlanet
UPLANETNAME       # nom UPlanet
myRELAY           # URL relay NOSTR (ex: ws://localhost:7777)
```

### Fichiers requis (tests live/scénario)
```
~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
~/.zen/game/uplanet.G1.nostr
```

### Services requis selon le tiers
| Tiers | Services |
|-------|---------|
| Statique | aucun |
| Intégration | strfry (port 7777) + IPFS daemon |
| IA | Ollama (11434) et/ou ComfyUI (8188) + tunnel P2P si distant |
| Scénario | strfry + IPFS + station UPlanet complète |

---

## Résultats

Les logs sont écrits dans `~/.zen/tmp/tests/<nom>_<timestamp>.log`.

| Symbole | Signification |
|---------|--------------|
| ✅ | Test réussi |
| ❌ | Test échoué (exit 1) |
| ⊘  | Test ignoré (skip, infra absente) |
| ⚠️  | Avertissement non-bloquant |

---

## CI/CD

```bash
# Pipeline CI (statique uniquement)
./tests/test_all_systems.sh --verbose
exit $?

# Pipeline complet (station live)
./tests/test_all_systems.sh --live --verbose
```

## Licence

AGPL-3.0 — même licence qu'Astroport.ONE.
