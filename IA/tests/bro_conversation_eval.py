#!/usr/bin/env python3
"""
bro_conversation_eval.py — Évaluation du routage vers les outils et de
l'anti-hallucination des capacités de BRO (canal self-DM conversationnel).

Complète eval_command_interpretation.py (qui couvre l'interprétation des
commandes structurées) avec deux volets supplémentaires, issus d'un incident
réel constaté en production le 2026-07-03 :

  1. Routage outils (match_tool) — un outil actif doit être appelé pour une
     vraie requête le concernant, et JAMAIS pour une question méta sur les
     capacités de BRO (ex: "à quels outils as-tu accès ?" matchait à tort
     l'outil météo à 0.67, le mot "outils" recoupant toute description).
     Déterministe, sans appel réseau à l'API de l'outil (teste juste le
     matching sémantique — voir bro_watch_core.match_tool).

  2. Anti-hallucination conversationnelle (_conversational_reply) — BRO ne
     doit jamais inventer de commande/tag qui n'existe pas (incident réel :
     "/activate_source", "/désactiver_source" etc. inventés de toutes
     pièces). Ce volet appelle un vrai LLM (non-déterministe) — utiliser
     --repeat N pour détecter une hallucination intermittente.

Contexte et registre d'outils actifs FIGÉS (bro_conversation_eval_cases.json)
pour reproductibilité — le registre réel de la station n'est jamais lu ni
modifié par ce harnais (list_active_tools est monkeypatché le temps du run).

Usage :
    python3 bro_conversation_eval.py [--verbose] [--repeat 3] [--skip-llm]
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

EVAL_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bro_conversation_eval_cases.json")
TEST_EMAIL = "eval-test@astroport.local"  # n'existe pas réellement — voir monkeypatchs


def _load_cases():
    with open(EVAL_FILE, encoding="utf-8") as f:
        return json.load(f)


def _patch_fixed_context(data):
    """Monkeypatch list_active_tools et _watch_context_summary pour un
    contexte figé et reproductible, et désactive _log_tool_request pour ne
    JAMAIS polluer le vrai corpus de mining (~/.zen/flashmem/bro_tool_requests.jsonl)
    avec des messages de test — restaure les originaux à l'appelant."""
    orig_tools = bwc.list_active_tools
    orig_summary = bwc._watch_context_summary
    orig_is_captain = bwc._is_captain
    orig_log = bwc._log_tool_request

    context_summary = bwc.format_context_entries(data["context"])
    bwc.list_active_tools = lambda: data["active_tools"]
    bwc._watch_context_summary = lambda owner_email: context_summary
    bwc._is_captain = lambda owner_email: False  # cas capitaine hors périmètre de ce harnais
    bwc._log_tool_request = lambda owner_email, text, reply: None

    def _restore():
        bwc.list_active_tools = orig_tools
        bwc._watch_context_summary = orig_summary
        bwc._is_captain = orig_is_captain
        bwc._log_tool_request = orig_log

    return _restore


def run_tool_routing(cases, verbose=False):
    print("\n── Routage outils (match_tool, déterministe) ──────────────────")
    passed = 0
    for case in cases:
        result = bwc.match_tool(case["text"])
        got_tool = result[0] if result else None
        ok = got_tool == case["expected_tool"]
        passed += int(ok)
        status = "✅" if ok else "❌"
        if verbose or not ok:
            score_info = f" (score {result[1]:.2f})" if result else ""
            print(f"{status} {case['text']!r}")
            print(f"    attendu: {case['expected_tool']!r}  obtenu: {got_tool!r}{score_info}")
            if not ok and case.get("origin"):
                print(f"    ⚠️  régression : {case['origin']}")
    score = passed / len(cases) if cases else 1.0
    print(f"Score routage : {passed}/{len(cases)} ({score:.0%})")
    return score


def run_hallucination_checks(cases, repeat=1, verbose=False):
    print(f"\n── Anti-hallucination conversationnelle (LLM, x{repeat}) ───────")
    total_runs, passed_runs = 0, 0
    for case in cases:
        forbidden = [t.lower() for t in case["forbidden_terms"]]
        case_passed = 0
        for i in range(repeat):
            answer = bwc._conversational_reply(TEST_EMAIL, case["text"])
            lowered = answer.lower()
            hit = [t for t in forbidden if t in lowered]
            ok = not hit
            case_passed += int(ok)
            total_runs += 1
            passed_runs += int(ok)
            if verbose or not ok:
                status = "✅" if ok else "❌"
                print(f"{status} [{i+1}/{repeat}] {case['text']!r}")
                if hit:
                    print(f"    ⚠️  termes interdits trouvés : {hit}")
                    if case.get("origin"):
                        print(f"    régression : {case['origin']}")
                print(f"    réponse : {answer[:200]}")
        print(f"  → {case['text']!r} : {case_passed}/{repeat} run(s) sans terme interdit")
    score = passed_runs / total_runs if total_runs else 1.0
    print(f"Score anti-hallucination : {passed_runs}/{total_runs} run(s) ({score:.0%})")
    return score


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verbose", action="store_true", help="Affiche tous les cas, pas seulement les échecs")
    parser.add_argument("--repeat", type=int, default=1,
                         help="Répétitions par cas d'hallucination (détecte l'intermittence LLM)")
    parser.add_argument("--skip-llm", action="store_true",
                         help="Ne fait que le routage outils (déterministe, rapide) — saute les appels LLM")
    args = parser.parse_args()

    data = _load_cases()
    restore = _patch_fixed_context(data)
    try:
        routing_score = run_tool_routing(data["tool_routing_cases"], verbose=args.verbose)
        halluc_score = 1.0
        if not args.skip_llm:
            halluc_score = run_hallucination_checks(data["hallucination_cases"], repeat=args.repeat, verbose=args.verbose)
    finally:
        restore()

    print(f"\n══ Score global : routage {routing_score:.0%}"
          + (f" · anti-hallucination {halluc_score:.0%}" if not args.skip_llm else " (LLM sauté)"))
    sys.exit(0 if (routing_score == 1.0 and halluc_score == 1.0) else 1)


if __name__ == "__main__":
    main()
