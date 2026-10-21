#!/usr/bin/env python3
"""
tool_runner — expose les générateurs de IA/generators/ comme outils déclaratifs
(Tool Calling JSON) et exécute les appels du modèle.

Source de vérité unique : manifest.json (à côté de ce fichier). Aucune
dépendance hors bibliothèque standard.

  tool_runner.py list [--format anthropic|openai|ollama|mcp]   schémas à donner au modèle
  tool_runner.py call <nom> '<json des arguments>'              exécute un outil, JSON sur stdout
  tool_runner.py validate                                       cohérence manifeste ↔ scripts

En Python :
  import tool_runner
  tools = tool_runner.get_tools("anthropic")        # → paramètre `tools` de l'API
  res = tool_runner.call_tool(name, arguments)      # → dict {ok, output, exit_code, ...}

Sécurité : jamais de shell (argv direct) ; arguments validés contre le JSON
Schema AVANT exécution ; une valeur positionnelle commençant par « - » ne peut
pas être prise pour une option ; les paramètres "x-sensitive" ne sont jamais
journalisés. Les erreurs sont retournées au modèle (ok=false + error), jamais
masquées.
"""

import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GENERATORS_DIR = os.path.dirname(HERE)
MANIFEST = os.path.join(HERE, "manifest.json")
STDERR_TAIL = 2000
URL_RE = re.compile(r"https?://\S+|/ipns?/\S+|/ipfs/\S+")


def load_manifest(include_disabled=True):
    with open(MANIFEST, encoding="utf-8") as f:
        tools = json.load(f)["tools"]
    return tools if include_disabled else [t for t in tools if t.get("enabled", True)]


def _tool(name):
    for t in load_manifest():
        if t["name"] == name:
            return t
    return None


def _public_schema(node):
    """Schéma sans les extensions internes « x-* » (x-path, x-sensitive) : certains fournisseurs les rejettent."""
    if isinstance(node, dict):
        return {k: _public_schema(v) for k, v in node.items() if not k.startswith("x-")}
    if isinstance(node, list):
        return [_public_schema(v) for v in node]
    return node


def get_tools(fmt="anthropic"):
    """Schémas prêts à l'emploi pour l'API de tool calling du fournisseur."""
    out = []
    for t in load_manifest(include_disabled=False):  # un outil "enabled": false n'est jamais proposé au modèle
        d, s = t["description"], _public_schema(t["input_schema"])
        if fmt == "anthropic":
            out.append({"name": t["name"], "description": d, "input_schema": s})
        elif fmt in ("openai", "ollama"):
            out.append({"type": "function", "function": {"name": t["name"], "description": d, "parameters": s}})
        elif fmt == "mcp":
            out.append({"name": t["name"], "description": d, "inputSchema": s})
        else:
            raise ValueError(f"format inconnu : {fmt}")
    return out


# ── Validation JSON Schema (sous-ensemble utilisé par le manifeste) ──────────

_TYPES = {"string": str, "boolean": bool, "array": list, "object": dict}


def resolve_path(p):
    """Chemin absolu : tel quel, sinon relatif au dossier courant, sinon à generators/ (ex. workflow/x.json)."""
    p = os.path.expanduser(p)
    if os.path.isabs(p):
        return p
    for base in (os.getcwd(), GENERATORS_DIR):
        if os.path.exists(os.path.join(base, p)):
            return os.path.join(base, p)
    return p


def _check(value, schema, path, errors):
    t = schema.get("type")
    if t == "integer":
        ok = isinstance(value, int) and not isinstance(value, bool)
    elif t == "number":
        ok = isinstance(value, (int, float)) and not isinstance(value, bool)
    elif t in _TYPES:
        ok = isinstance(value, _TYPES[t])
    else:
        ok = True
    if not ok:
        errors.append(f"{path} : type {t} attendu")
        return
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path} : doit valoir l'un de {schema['enum']}")
    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            errors.append(f"{path} : ne peut pas être vide")
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errors.append(f"{path} : format invalide (attendu {schema['pattern']})")
        kind = schema.get("x-path")
        if kind == "file" and not os.path.isfile(resolve_path(value)):
            errors.append(f"{path} : fichier introuvable ({value})")
        if kind == "dir" and not os.path.isdir(resolve_path(value)):
            errors.append(f"{path} : dossier introuvable ({value})")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path} : minimum {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path} : maximum {schema['maximum']}")
        if "exclusiveMinimum" in schema and value <= schema["exclusiveMinimum"]:
            errors.append(f"{path} : doit être > {schema['exclusiveMinimum']}")
    if isinstance(value, list):
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{path} : {schema['maxItems']} éléments max")
        for i, v in enumerate(value):
            _check(v, schema.get("items", {}), f"{path}[{i}]", errors)
    if isinstance(value, dict):
        props = schema.get("properties", {})
        for r in schema.get("required", []):
            if r not in value:
                errors.append(f"{path}.{r} : obligatoire")
        for k, v in value.items():
            if k in props:
                _check(v, props[k], f"{path}.{k}", errors)
            elif schema.get("additionalProperties") is False:
                errors.append(f"{path}.{k} : paramètre inconnu")


def validate_args(tool, arguments):
    errors = []
    if not isinstance(arguments, dict):
        return ["arguments : objet JSON attendu"]
    _check(arguments, tool["input_schema"], "args", errors)
    return errors


# ── Construction de la ligne de commande ─────────────────────────────────────

def _interpreter(env_name):
    """python d'un venv désigné par lib/env.sh (ex. QWEN3TTS_PY), ou None."""
    if os.environ.get(env_name):
        return os.environ[env_name]
    r = subprocess.run(["bash", "-c", f'. "{GENERATORS_DIR}/lib/env.sh" >/dev/null 2>&1; printf %s "${env_name}"'],
                       capture_output=True, text=True)
    return r.stdout.strip() or None


def _str(v):
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    return str(v)


def _safe_positional(v):
    # les scripts utilisent getopts : un texte commençant par « - » serait lu comme option
    v = _str(v)
    return " " + v if v.startswith("-") else v


def build_argv(tool, arguments):
    """Retourne (argv, None) ou (None, erreur)."""
    ex = tool["exec"]
    script = os.path.join(GENERATORS_DIR, ex["script"])
    if not os.path.isfile(script):
        return None, f"script introuvable : {ex['script']}"
    if "interpreter" in ex:
        py = _interpreter(ex["interpreter"])
        if not py or not os.access(py, os.X_OK):
            return None, f"interpréteur {ex['interpreter']} indisponible (voir lib/env.sh, install/install_qwen3_tts.sh)"
        argv = [py, script]
    else:
        argv = [script]
    options, positionals = [], []
    for a in ex["args"]:
        if "only_if" in a and a["only_if"] not in arguments:
            continue
        if "literal" in a:  # "" = positionnel vide qui comble un trou ; sinon option fixe (--check)
            (positionals if a["literal"] == "" else options).append(a["literal"])
            continue
        v = arguments.get(a.get("param") or a.get("positional"))
        if "flag" in a:
            if v is None or v is False:
                continue
            if a.get("boolean"):
                options.append(a["flag"])
            else:
                for item in (v if a.get("repeat") else [v]):
                    options += [a["flag"], _str(item)]
        else:
            positionals.append(None if v is None else _safe_positional(v))
    # les trous au milieu deviennent "" ; les positionnels optionnels finaux sont supprimés
    while positionals and positionals[-1] is None:
        positionals.pop()
    positionals = ["" if p is None else p for p in positionals]
    return argv + options + positionals, None


def _parse_output(kind, stdout):
    text = stdout.strip()
    lines = [l for l in text.splitlines() if l.strip()]
    if kind in ("json", "text_or_json"):
        try:
            return json.loads(text)
        except ValueError:
            if kind == "json":
                return text
    if kind == "last_line":
        return lines[-1].strip() if lines else ""
    return text


def call_tool(name, arguments=None, timeout=None):
    """Exécute un outil. Toujours un dict : ok, output, exit_code, [error, stderr_tail, url]."""
    arguments = arguments or {}
    tool = _tool(name)
    if tool is not None and not tool.get("enabled", True):
        return {"ok": False, "error": f"outil désactivé : {tool.get('disabled_reason', 'indisponible')}"}
    if tool is None:
        return {"ok": False, "error": f"outil inconnu : {name}", "available": [t["name"] for t in load_manifest(include_disabled=False)]}
    errors = validate_args(tool, arguments)
    if errors:
        return {"ok": False, "error": "arguments invalides", "details": errors}
    props = tool["input_schema"]["properties"]
    arguments = {k: resolve_path(v) if props[k].get("x-path") else v for k, v in arguments.items()}
    argv, err = build_argv(tool, arguments)
    if err:
        return {"ok": False, "error": err}
    limit = timeout or tool.get("timeout_sec", 600)
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=limit, cwd=GENERATORS_DIR)
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"timeout après {limit}s", "exit_code": None}
    out = {"ok": r.returncode == 0, "exit_code": r.returncode}
    meaning = tool.get("exit_codes", {}).get(str(r.returncode))
    if meaning:
        out["exit_meaning"] = meaning
    out["output"] = _parse_output(tool.get("output", "text"), r.stdout)
    if isinstance(out["output"], str):
        m = URL_RE.search(out["output"])
        if m:
            out["url"] = m.group(0)
    if r.returncode != 0 or r.stderr.strip():
        out["stderr_tail"] = r.stderr.strip()[-STDERR_TAIL:]
    if r.returncode != 0:
        out["error"] = meaning or f"le script a échoué (code {r.returncode})"
        if re.search(r"ERROR:\S+:gpu_busy", r.stderr):  # refus du garde-fou VRAM (IA/gpu_headroom.py)
            out["error"] = "gpu_busy : pas assez de VRAM libre (GPU partagé Ollama/ComfyUI)"
            out["retryable"] = True
    return out


def validate_manifest():
    """Contrôle de conformité manifeste ↔ code : retourne la liste des écarts."""
    problems, names = [], set()
    tools = load_manifest()
    for t in tools:
        n = t["name"]
        if n in names:
            problems.append(f"{n} : nom dupliqué")
        names.add(n)
        if not os.path.isfile(os.path.join(GENERATORS_DIR, t["exec"]["script"])):
            problems.append(f"{n} : script {t['exec']['script']} introuvable")
        props = t["input_schema"].get("properties", {})
        used = {a.get("param") or a.get("positional") for a in t["exec"]["args"]} - {None}
        for u in used - set(props):
            problems.append(f"{n} : l'exec référence « {u} » absent du schéma")
        for p in set(props) - used:
            problems.append(f"{n} : paramètre « {p} » du schéma jamais transmis au script")
        for r in t["input_schema"].get("required", []):
            if r not in props:
                problems.append(f"{n} : required « {r} » absent des properties")
    # un générateur sans outil doit être exclu explicitement (voir $comment du manifeste)
    covered = {t["exec"]["script"] for t in tools}
    allowed_missing = {"generate_storyboard.sh", "image_to_3dscene.py"}
    for f in sorted(os.listdir(GENERATORS_DIR)):
        if (f.startswith(("generate_", "image_to_", "apply_", "video_", "faceid")) and f.endswith((".sh", ".py"))
                and f not in covered | allowed_missing):
            problems.append(f"{f} : aucun outil déclaré dans manifest.json")
    return problems


def main(argv):
    if len(argv) >= 2 and argv[1] == "list":
        fmt = argv[argv.index("--format") + 1] if "--format" in argv else "anthropic"
        print(json.dumps(get_tools(fmt), ensure_ascii=False, indent=2))
        return 0
    if len(argv) >= 3 and argv[1] == "call":
        try:
            args = json.loads(argv[3]) if len(argv) > 3 else {}
        except ValueError as e:
            print(json.dumps({"ok": False, "error": f"JSON invalide : {e}"}, ensure_ascii=False))
            return 2
        res = call_tool(argv[2], args)
        print(json.dumps(res, ensure_ascii=False))
        return 0 if res["ok"] else 1
    if len(argv) >= 2 and argv[1] == "validate":
        problems = validate_manifest()
        for p in problems:
            print(f"ERROR:tools:{p}", file=sys.stderr)
        print(f"{len(load_manifest())} outils, {len(problems)} écart(s)")
        return 1 if problems else 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
