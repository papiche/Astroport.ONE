<!-- SPDX-License-Identifier: AGPL-3.0 -->
# Contribuer à Astroport.ONE

Astroport.ONE est un projet AGPL-3.0 géré par Fred (support@qo-op.com) pour la coopérative UPlanet.

## Prérequis

- Bash 5+, shellcheck, shellspec
- IPFS Kubo, Python 3.10+, jq, bc, curl
- Une station Astroport fonctionnelle (test local) — voir [`docs/tutorials/`](../tutorials/)

## Workflow

```bash
git checkout -b feat/ma-feature
# ... modifications ...
make check          # shellcheck (non-fatal)
make specs          # shellspec unit tests
./test.sh quick     # intégration rapide (station live requise)
git push origin feat/ma-feature
# → Pull Request sur le dépôt principal
```

## Règles de contribution

### Scripts bash
- Toujours commencer par le pattern standard :
  ```bash
  MY_PATH="`dirname \"$0\"`"; MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
  . "${MY_PATH}/tools/my.sh"
  ```
- Passer shellcheck sans erreur bloquante

### Nouveau service IA (module)
1. Ajouter une ligne dans `IA/modules.list` (format : `name|port|check|install_group|label`)
2. Créer `install/install_<group>.sh`
3. Créer `IA/<name>.me.sh` (cascade LOCAL → SSH → P2P)
4. Documenter dans `docs/how-to/ASTROSYSTEMCTL.md`
5. Mettre à jour `docs/reference/RUNTIME_SCRIPTS_OVERVIEW.md` si RUNTIME impacté

### Nouveau script RUNTIME
- Ajouter dans `20h12.process.sh` à l'étape appropriée
- Documenter dans `docs/reference/RUNTIME_SCRIPTS_OVERVIEW.md`

### Règle doc ↔ code
**Modifier un script = mettre à jour sa doc dans le même commit.**
Voir le mapping complet dans `docs/reference/RUNTIME_SCRIPTS_OVERVIEW.md`.

## Tests

```bash
make tests                          # shellcheck + shellspec
./tests/test_all_systems.sh         # tous les sous-systèmes
./tests/test_did_system.sh          # DID uniquement
pytest UPassport/                   # tests FastAPI UPassport
```

## Licence

AGPL-3.0 — toute modification distribuée doit rester open-source sous la même licence.
