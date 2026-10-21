"""Conformité manifeste ↔ scripts de IA/generators/ et exécuteur d'outils (sans GPU)."""
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "generators", "tools"))
import tool_runner  # noqa: E402


def test_manifest_matches_scripts():
    assert tool_runner.validate_manifest() == []


def test_schemas_are_provider_clean():
    for fmt in ("anthropic", "openai", "ollama", "mcp"):
        assert "x-path" not in json.dumps(tool_runner.get_tools(fmt))


def test_argv_building():
    t = tool_runner._tool("generate_minimax")
    argv, err = tool_runner.build_argv(t, {"prompt": "-x", "reference_images": ["a", "b"], "duration": 8})
    assert err is None and argv[1:] == ["-R", "a", "-R", "b", "-d", "8", " -x"]
    t = tool_runner._tool("generate_badge_image")
    argv, _ = tool_runner.build_argv(t, {"badge_id": "b", "permit_name": "n", "permit_description": "d", "label": "L"})
    assert argv[1:] == ["b", "n", "d", "", "L"]  # trou comblé par ""


def test_invalid_calls_are_reported():
    assert tool_runner.call_tool("nope")["ok"] is False
    r = tool_runner.call_tool("generate_speech", {"text": "x", "voice": "bob"})
    assert not r["ok"] and r["error"] == "arguments invalides"
    r = tool_runner.call_tool("generate_image", {"prompt": "x", "extra": 1})
    assert "args.extra : paramètre inconnu" in r["details"]


def test_check_storyboard_real_call():
    ex = os.path.join(tool_runner.GENERATORS_DIR, "storyboard.example.json")
    r = tool_runner.call_tool("check_storyboard", {"storyboard_path": ex})
    assert r["ok"] and r["exit_meaning"] == "storyboard valide"
