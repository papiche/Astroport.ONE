# Outils déclaratifs (Tool Calling) — IA/generators/

Les générateurs sont décrits **une seule fois** dans [`manifest.json`](manifest.json) : nom, description lue par le modèle, `input_schema` (JSON Schema) et correspondance paramètres → arguments du script. [`tool_runner.py`](tool_runner.py) en tire les schémas pour le modèle et exécute ses appels.

## Utilisation

```bash
./tool_runner.py list --format anthropic   # ou openai | ollama | mcp
./tool_runner.py call generate_image '{"prompt":"un chat sur une chaise"}'
./tool_runner.py validate                  # manifeste ↔ scripts (aucun écart toléré)
```

```python
import tool_runner
tools = tool_runner.get_tools("anthropic")       # paramètre `tools` de l'API Messages
res = tool_runner.call_tool(block.name, block.input)   # → contenu du tool_result (json.dumps)
```

Résultat : `{ok, exit_code, output, url?, exit_meaning?, stderr_tail?, error?}`. `ok=false` est toujours accompagné d'une cause lisible par le modèle (`error`, `details`) — rien n'est avalé.

## Ajouter ou modifier un générateur

1. Éditer `manifest.json` (un objet par outil). Arguments : `{"flag":"-d","param":"duration"}`, `{"positional":"prompt"}`, `"boolean":true`, `"repeat":true`, `{"literal":"--check"}`.
2. `./tool_runner.py validate` : détecte un script sans outil, un paramètre du schéma jamais transmis, ou un `exec` qui référence un paramètre inconnu. Même discipline code↔doc que `modules.list`.
3. `python3 -m pytest IA/tests/test_generators_tools.py`.

Un script volontairement non exposé doit être listé dans `allowed_missing` (`validate_manifest`) : aujourd'hui `generate_storyboard.sh` (conversation interactive) et `image_to_3dscene.py` (appelé par `generate_3dscene.sh`).

## Garanties

- Pas de shell : argv direct, jamais d'interpolation.
- Arguments validés contre le schéma avant exécution (types, `enum`, bornes, `additionalProperties:false`, existence des fichiers/dossiers `x-path`).
- Un texte commençant par `-` est préfixé d'un espace pour ne pas être lu comme option par `getopts`.
- Les extensions `x-*` du schéma restent internes : elles ne sont pas envoyées au fournisseur.
- Chemins relatifs résolus depuis le dossier courant, puis depuis `generators/` (ex. `workflow/…json`).

## À savoir

- **GPU partagé** : le garde-fou VRAM (`lib/gpu_room.sh` → `IA/gpu_headroom.py`) est appelé par les scripts eux-mêmes, donc par le runner. Un refus remonte `error: gpu_busy…` avec `retryable: true` : le modèle doit patienter, pas insister. Le garde-fou vérifie la place, il ne met pas les jobs en file : enchaîner les outils lourds (`gpu` dans `tags`, `timeout_sec` jusqu'à 6 h) un par un. `generate_voice` est désactivé (`"enabled": false`) tant que l'intégration Qwen3-TTS sur la station GPU n'est pas finie : absent de `list`, refusé par `call`. Le retirer du manifeste quand elle l'est, et lui ajouter le garde-fou. `generate_speech` n'est pas gardé non plus.
- `faceid` renvoie des embeddings biométriques et accepte une clé de déchiffrement (`x-sensitive`) : ne pas la journaliser ni republier les embeddings.
- `generate_scene` : appeler `check_storyboard` d'abord.
- Pas encore branché sur `bro_tools.py` / `bro/tools.py` : le registre BRO (`#tags`, niveaux d'accès) n'a pas de schéma de paramètres. Une passerelle `manifest.json → bro_tools.Tool` est possible, mais les outils GPU y exigeraient une décision d'accès (`min_access`) que je n'ai pas tranchée.
