# WoTx2 — Toiles de Confiance Décentralisées

**Version** : 2.1 — Architecture Duale Oracle + P2P + MineLife Interface  
**Mise à jour** : Mai 2026  
**Statut** : Production  
**License** : AGPL-3.0

> Pour la description complète des kinds NOSTR, clés, schémas et flows, voir **[MINELIFE.md](MINELIFE.md)**.

---

## Architecture Duale

WoTx2 fonctionne en deux modes complémentaires :

- **Mode Oracle** : Kind 30503 signé par `UPLANETNAME_G1` — émis par `ORACLE.refresh.sh`
- **Mode P2P** : Kind 30503 auto-signé par le titulaire — calculé localement (TrocZen, MineLife)

Les deux modes coexistent sur le même relay NOSTR. Voir [MINELIFE.md §2](MINELIFE.md) pour le format exact de chaque Kind.

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

## Références

- **[MINELIFE.md](MINELIFE.md)** — Schémas complets, kinds, clés, flows
- `Astroport.ONE/tools/oracle_init_captain_wotx2.sh` — Bootstrap capitaines
- `Astroport.ONE/RUNTIME/ORACLE.refresh.sh` — Oracle quotidien
- `TrocZen/docs/WOTX2_SYSTEM.md` — Architecture P2P TrocZen v3.6
- `nostr-nips/42-oracle-permits-extension.md` — Spec NOSTR permits
