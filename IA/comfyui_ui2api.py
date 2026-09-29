#!/usr/bin/env python3
"""
comfyui_ui2api.py — Convertit un workflow ComfyUI au format UI vers le format API.

Les fichiers de IA/generators/workflow/ sont de deux natures :
  • format API (déjà `{"<node_id>": {"class_type":…, "inputs":…}}`) — directement
    postable sur /prompt. Ex: FluxImage.json, video_wan2_2_5B_ti2v.json.
  • format UI  (`{"nodes":[…], "links":[…]}`, ce que produit « Enregistrer » dans
    l'interface ComfyUI) — REFUSÉ par /prompt. Ex: « Face Detect Embeddings
    JSON.json ».

Le format UI ne nomme pas ses widgets : il les stocke dans un tableau ordonné
`widgets_values`. Les vrais noms d'entrée ne sont connus que du serveur, via
/object_info/<class_type> → input_order.required. On les récupère donc AU
RUNTIME plutôt que de les deviner — c'est ce qui rend ce script fiable pour des
custom nodes (InsightFaceAnalysisLoader, FaceDetectEmbeddingsToJSON…) dont les
signatures varient d'une installation à l'autre.

Usage :
    comfyui_ui2api.py <workflow.json> [--url http://127.0.0.1:8188] [--set NODE.input=valeur]…
Sortie : le workflow au format API sur stdout (JSON compact).
Exit : 0 = ok, 1 = erreur (message sur stderr).

Exemple :
    comfyui_ui2api.py "workflow/Face Detect Embeddings JSON.json" --set 1.image=photo.jpg
"""

import sys
import json
import argparse
import urllib.parse
import urllib.request


def _object_info(url: str, class_type: str) -> dict:
    """input_order.required d'un node, depuis /object_info/<class_type>."""
    try:
        with urllib.request.urlopen(f"{url}/object_info/{urllib.parse.quote(class_type)}",
                                    timeout=10) as resp:
            data = json.loads(resp.read().decode())
    except Exception as exc:
        raise RuntimeError(f"/object_info/{class_type} injoignable : {exc}") from exc
    info = data.get(class_type)
    if not info:
        raise RuntimeError(
            f"Le node '{class_type}' n'est pas installé sur ce ComfyUI "
            f"(/object_info/{class_type} vide) — workflow non exécutable ici")
    return info


def _consume_dynamic(spec, prefix: str, value, values, inputs: dict) -> None:
    """Menu dynamique (COMFY_DYNAMICCOMBO_V3) : l'UI range juste après sa valeur
    les sous-widgets de l'option choisie ; l'API les attend en « nom.sous_nom »
    (récursif : format → format.codec → format.codec.encoding)."""
    if not (isinstance(spec, list) and spec and spec[0] == "COMFY_DYNAMICCOMBO_V3"):
        return
    option = next((o for o in spec[1].get("options", []) if o.get("key") == value), None)
    if not option:
        return
    sub = {**option.get("inputs", {}).get("required", {}), **option.get("inputs", {}).get("optional", {})}
    for sub_name, sub_spec in sub.items():
        sub_value = next(values, None)
        if sub_value is None:
            return
        inputs[f"{prefix}.{sub_name}"] = sub_value
        _consume_dynamic(sub_spec, f"{prefix}.{sub_name}", sub_value, values, inputs)


def ui_to_api(workflow: dict, url: str) -> dict:
    """Convertit un workflow format UI en format API."""
    if "nodes" not in workflow:
        return workflow  # déjà au format API

    # link_id → (origin_node_id, origin_slot)
    links = {}
    for link in workflow.get("links") or []:
        if isinstance(link, list) and len(link) >= 4:
            links[link[0]] = (link[1], link[2])

    api = {}
    for node in workflow["nodes"]:
        # mode 2 = muted, mode 4 = bypassed — ces nodes ne sont pas exécutés
        if node.get("mode") in (2, 4):
            continue
        node_id = str(node["id"])
        class_type = node["type"]
        inputs = {}

        # 1) entrées reliées à un autre node
        linked_names = []
        # widgets convertis en entrée : l'UI actuelle garde leur valeur dans widgets_values
        linked_widgets = set()
        for inp in node.get("inputs") or []:
            link_id = inp.get("link")
            if link_id is not None and link_id in links:
                origin_id, origin_slot = links[link_id]
                inputs[inp["name"]] = [str(origin_id), origin_slot]
                linked_names.append(inp["name"])
                if inp.get("widget"):
                    linked_widgets.add(inp["name"])

        # 2) widgets : positionnels côté UI, il faut leurs vrais noms côté API
        widgets = node.get("widgets_values") or []
        if isinstance(widgets, list) and widgets:
            info = _object_info(url, class_type)
            order = info.get("input_order", {}).get("required", []) \
                + info.get("input_order", {}).get("optional", [])
            specs = {**info.get("input", {}).get("optional", {}), **info.get("input", {}).get("required", {})}
            # Une entrée reliée ne consomme de widget que si l'UI l'a gardé (clé "widget")
            widget_names = [n for n in order if n not in linked_names or n in linked_widgets]
            values = iter(widgets)
            for name in widget_names:
                value = next(values, None)
                if value is None and name not in inputs:
                    break
                if name not in linked_names:
                    inputs[name] = value
                spec = specs.get(name)
                _consume_dynamic(spec, name, value, values, inputs)
                # seed / noise_seed : l'UI range ensuite « fixed » / « randomize »
                if isinstance(spec, list) and len(spec) > 1 and isinstance(spec[1], dict) \
                        and spec[1].get("control_after_generate"):
                    next(values, None)

        api[node_id] = {"class_type": class_type, "inputs": inputs}

    return api


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("workflow", help="Fichier workflow JSON (format UI ou API)")
    parser.add_argument("--url", default="http://127.0.0.1:8188",
                        help="URL HTTP de ComfyUI (défaut: http://127.0.0.1:8188)")
    parser.add_argument("--set", action="append", default=[], metavar="NODE.INPUT=VALEUR",
                        help="Écrase une entrée après conversion (répétable)")
    args = parser.parse_args()

    try:
        with open(args.workflow, "r", encoding="utf-8") as fh:
            workflow = json.load(fh)
    except Exception as exc:
        print(f"ERROR: workflow illisible : {exc}", file=sys.stderr)
        return 1

    try:
        api = ui_to_api(workflow, args.url)
    except Exception as exc:
        print(f"ERROR: conversion UI→API échouée : {exc}", file=sys.stderr)
        return 1

    for assignment in args.set:
        try:
            path, value = assignment.split("=", 1)
            node_id, input_name = path.split(".", 1)
        except ValueError:
            print(f"ERROR: --set attend NODE.INPUT=VALEUR (reçu: {assignment})", file=sys.stderr)
            return 1
        if node_id not in api:
            print(f"ERROR: node '{node_id}' absent du workflow", file=sys.stderr)
            return 1
        api[node_id]["inputs"][input_name] = value

    print(json.dumps(api, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
