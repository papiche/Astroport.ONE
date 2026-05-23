#!/bin/bash
########################################################################
# well_known_libs.sh — Bibliothèques tierces à exclure des contextes LLM
#
# Sourcé par cpscript et cpcode via --well-known.
# Ces fichiers sont volumineux, stables et déjà connus des LLM —
# les inclure dans le contexte consomme des tokens inutilement.
#
# Pour mettre à jour : ajouter le basename ou un fragment de nom
# suffisamment discriminant (sans chemin ni extension).
#
# Adapter selon les assets servis par UPlanet (UPlanet/earth/*.min.js)
# et UPassport (UPassport/static/ le cas échéant).
########################################################################

# ── Générique (CDN / npm, indépendants du projet) ─────────────────────
# jQuery (toutes versions : jquery-1.7.2.min.js, jquery-3.6.3.min.js,
#         jquery-ui.min.js, jquery-ui.0.min.js, jquery.earth-3d.js…)
# Bootstrap (bootstrap.bundle.min.js, bootstrap.min.css,
#            bootstrap-icons.css — dossier fonts/ compris)
# Leaflet + clusters (leaflet.js, MarkerCluster.css…)
# axios, html2canvas, jsmediatags
WELL_KNOWN_LIBS=(
    # ── jQuery ──────────────────────────────────────────────────────
    jquery

    # ── Bootstrap ───────────────────────────────────────────────────
    bootstrap

    # ── Cartographie ────────────────────────────────────────────────
    leaflet MarkerCluster

    # ── Utilitaires réseau / DOM ─────────────────────────────────────
    axios html2canvas jsmediatags

    # ── Cryptographie — UPlanet/earth ───────────────────────────────
    # nacl-fast.min.js  nacl.min.js  sha256.min.js
    # scrypt.min.js  scrypt-async.min.js  bip39-libs
    "nacl" "sha256.min"
    scrypt "bip39-libs"

    # ── Blake2b (portefeuille G1) ────────────────────────────────────
    "blake2b.js" blake2b_browser blake2b_combined

    # ── p5.js (canvas / son) ────────────────────────────────────────
    "p5.min" "p5.sound"

    # ── NOSTR bundle ─────────────────────────────────────────────────
    # nostr.bundle.js (~200 Ko) — SDK NOSTR complet, connu des LLM
    "nostr.bundle"

    # ── Rendu markdown / diagrammes ──────────────────────────────────
    "marked.min" "mermaid.min"

    # ── 3D / globe — UPlanet/earth ───────────────────────────────────
    # sphere-hacked.js  world.js  model-viewer.min.js
    # astronomy.browser.min.js  requestanimationframe.polyfill.js
    sphere-hacked "world.js"
    "model-viewer.min"
    "astronomy.browser"
    "requestanimationframe.polyfill"

    # ── Calendrier lunaire ───────────────────────────────────────────
    lunar-calendar

    # ── Helia (IPFS en JS) ───────────────────────────────────────────
    "helia@"

    # ── Autre ────────────────────────────────────────────────────────
    "awesome.css"
)
