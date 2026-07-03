#!/usr/bin/env python3
"""
eval_command_interpretation.py — Évaluation objective du prompt d'interprétation
des commandes bro_watch_core (discipline façon Arbor : jeu tenu à l'écart,
score reproductible, comparaison avant/après tout changement de prompt/modèle).

Deux jeux de cas, dans le même esprit qu'un split dev/held-out d'entraînement :
  - bro_watch_command_eval_dev.json      : utilisé pour itérer (visible pendant
                                            le tuning du prompt/modèle).
  - bro_watch_command_eval_heldout.json  : jamais consulté pendant l'itération,
                                            réservé à la validation finale d'une
                                            hypothèse déjà gagnante sur dev (voir
                                            arbor_self_improve.py).

Usage :
    python3 eval_command_interpretation.py [--verbose] [--model MODEL] [--split dev|heldout]
"""

# Auto-reinvocation dans le venv ~/.astro/ si dépendances absentes
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import sys
import os
import json
import argparse

sys.path.insert(0, os.path.expanduser("~/.zen/Astroport.ONE/IA"))
import bro_watch_core as bwc

TESTS_DIR = os.path.dirname(os.path.abspath(__file__))
EVAL_FILES = {
    "dev": os.path.join(TESTS_DIR, "bro_watch_command_eval_dev.json"),
    "heldout": os.path.join(TESTS_DIR, "bro_watch_command_eval_heldout.json"),
}


def fields_match(expected, actual):
    for key, value in expected.items():
        if actual.get(key) != value:
            return False
    return True


def run_eval(verbose=False, model=None, split="dev"):
    with open(EVAL_FILES[split], encoding="utf-8") as f:
        data = json.load(f)

    context_summary = bwc.format_context_entries(data["context"])
    total = len(data["cases"])
    passed = 0
    results = []

    for case in data["cases"]:
        text = case["text"]
        expected_action = case["expected_action"]
        expected_fields = case.get("expected_fields", {})

        action = bwc.interpret_command_with_context(text, context_summary, model=model) or {"action": "none"}
        action_ok = action.get("action") == expected_action
        fields_ok = fields_match(expected_fields, action) if action_ok else False
        sanity_ok = True
        if action_ok and expected_action not in ("none",):
            sanity_ok = bwc._sanity_check_action(text, action)

        case_pass = action_ok and fields_ok and sanity_ok
        passed += int(case_pass)
        results.append({
            "text": text, "expected": expected_action, "got": action.get("action"),
            "fields_ok": fields_ok, "sanity_ok": sanity_ok, "pass": case_pass, "raw": action,
        })

        if verbose or not case_pass:
            status = "✅" if case_pass else "❌"
            print(f"{status} {text!r}")
            print(f"    attendu: {expected_action} {expected_fields}")
            print(f"    obtenu : {action}")

    score = passed / total if total else 0.0
    label = model or bwc.COMMAND_INTERPRETATION_MODEL
    print(f"\nScore [{label}/{split}] : {passed}/{total} ({score:.0%})")
    return score, results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verbose", action="store_true", help="Affiche tous les cas, pas seulement les échecs")
    parser.add_argument("--model", type=str, default=None,
                         help="Modèle Ollama à tester (défaut: bwc.COMMAND_INTERPRETATION_MODEL)")
    parser.add_argument("--split", choices=["dev", "heldout"], default="dev")
    args = parser.parse_args()
    score, _ = run_eval(verbose=args.verbose, model=args.model, split=args.split)
    sys.exit(0 if score == 1.0 else 1)
