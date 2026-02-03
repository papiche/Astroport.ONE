# Conformity Analysis: Code vs COLLABORATIVE_COMMONS_SYSTEM.md

This document analyses the alignment between the implementation (umap_index.html, NOSTR.UMAP.refresh.sh, collaborative-editor.html) and the documentation (COLLABORATIVE_COMMONS_SYSTEM.md).

**Note:** `UPlanet/earth/collaborative-editor.html` is not present in the current workspace (AAA); it lives in the UPlanet repo and is served via IPNS. The analysis below covers only what can be verified in this repo (Astroport.ONE templates and RUNTIME, and the doc).

---

## 1. umap_index.html ↔ Doc

### 1.1 Conform (matches doc)

| Doc claim | Code reality |
|-----------|--------------|
| Section "Collaborative Documents" with `#collaborative` badge | Present: card-title "📄 Collaborative Documents", card-badge "#collaborative" |
| "New Document" link with `lat`, `lon`, `umap` | Two links: `.../collaborative-editor.html?lat=_LAT_&lon=_LON_&umap=_UMAPHEX_` (line 354, 384) |
| Documents loaded dynamically via `loadCollaborativeDocs()` | Implemented; queries kind 30023 (UMAP-signed + `#p` ref), then strict filter |
| Two valid doc types: (1) signed by UMAP, (2) from friend with tag `p` | Filter: `e.pubkey === ZONE_CONFIG.umapPubkeyHex` OR (`refsThisUmap` and `friends.includes(e.pubkey)`) |
| Tag `p`: document must have `["p", UMAP_PUBKEY_HEX]` for visibility | Code checks `t[0] === 'p' && t[1] === ZONE_CONFIG.umapPubkeyHex` (no requirement for 3rd/4th element; doc’s `"", "umap"` is optional) |
| ZONE_CONFIG with lat, lon, umapPubkeyHex, relay, ipfs, coracle | Present: `lat`, `lon`, `umapPubkeyHex`, `umapNpub`, `relay`, `ipfs`, `coracle` |
| Official docs first, then "En attente" proposals | `officialDocs` / `proposalDocs`; labels "DOCUMENTS OFFICIELS" and "PROPOSITIONS"; border emerald vs amber |
| Doc types and icons (commons, project, decision, garden, resource) | `typeIcons = { commons: '🤝', project: '🎯', decision: '🗳️', garden: '🌱', resource: '📦' }`; docType from tag `t` in that list |
| "Lire / Éditer" → collaborative-editor with `doc=<id>` | `editorUrl = .../collaborative-editor.html?lat=...&lon=...&umap=...&doc=${doc.id}` |
| loadFriends() → kind 3, loadMessages() → kind 1 | Implemented as described |

### 1.2 Doc incomplete or imprecise

| Topic | Doc | Code | Recommendation |
|-------|-----|------|----------------|
| **Placeholders** | Lists only `_LAT_`, `_LON_`, `_UMAPHEX_`, `_UMAPNPUB_`, `_MYRELAY_`, `_MYIPFS_`, `_CORACLEURL_` | Script also replaces `_MAPURL_`, `_SECTOR_`, `_REGION_`, `_SECTORURL_`, `_REGIONURL_` in `generate_umap_index()` | Add these placeholders to the "Placeholders injectés par le serveur" table. |
| **Kind 7 "valid" likes** | "Approuver: ✅ ou + ou 👍" | Stats: `validLikes = likes.filter(l => ['+', '❤️', '👍', '✅', '🤙'].includes(l.content))` | Doc could mention that ❤️ and 🤙 are also counted as positive (optional). |

### 1.3 Minor

- Doc says "Bordure verte = Document Adopté", "Bordure orange = En Attente". Code uses `var(--accent-emerald)` and `var(--accent-amber)` with labels "Adopté" / "En attente". **Conform.**

---

## 2. NOSTR.UMAP.refresh.sh ↔ Doc

### 2.1 Conform (matches doc)

| Doc claim | Code reality |
|-----------|--------------|
| `republish_umap_commons` runs per UMAP; queries kind 30023 with `#p` = UMAP and tag `t` = collaborative or commons | `strfry scan` with `#p`: [UMAP_HEX], then jq filter for `t` = "collaborative" or "commons", `pubkey != UMAP_HEX` |
| Seuil ≥ 3 likes | `COMMONS_LIKE_THRESHOLD=3` |
| Count kind 7 reactions: +, 👍, ❤️, ♥️, ✅ | `count_likes()` uses jq `select(.content == "+" or .content == "👍" or .content == "❤️" or .content == "♥️" or .content == "✅")` |
| Already adopted = kind 30023 by UMAP with tag `original-event` = original id | Query authors=[UMAP_HEX], then jq `.[0] == "original-event" | .[1]` to build `adopted_ids`; skip if `orig_id` in that list |
| Republish adds tags: `original-author`, `original-event`, `likes`, `adopted-at` | All four present in `article_tags` (author = hex, orig_ev = id, likes count, adopted timestamp) |
| Key derived on the fly; temp keyfile for `nostr_send_note.py` | `UMAPNSEC=$(keygen ... -s)`, `echo "NSEC=$UMAPNSEC;" > "$temp_keyfile"`, then `nostr_send_note.py --keyfile "$temp_keyfile"` |
| Template from `templates/NOSTR/umap_index.html`; replace _LAT_, _LON_, _UMAPHEX_, _UMAPNPUB_, etc. | `generate_umap_index()` copies template and runs sed for all listed placeholders |
| UMAP keys: `keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}"` and `nostr2hex.py` for hex | Same in `generate_umap_index()` (NPUB from keygen, then UMAPHEX from nostr2hex.py) |

### 2.2 Doc incomplete or different from code

| Topic | Doc | Code | Recommendation |
|-------|-----|------|----------------|
| **Tags on adopted event** | "Tags Spéciaux" table lists only `original-author`, `original-event`, `likes`, `adopted-at` | Script also sends `d`, `title`, `t` (collaborative, UPlanet, commons), `g`, `latitude`, `longitude`, `author`, `version`, `published_at` | Extend the "Tags Spéciaux" section (or the adopted-event example) to mention that the republished event also keeps/gets NIP-23-style tags: `d`, `title`, `t`, `g`, `latitude`, `longitude`, `author`, `version`, `published_at`. |
| **Format of `d` for adopted** | Example: `commons-43.60-1.44-charte` | Code: `d_tag="commons-${LAT}-${LON}-${orig_id:0:12}"` (first 12 chars of original event id, not a slug) | Doc should state that the adopted event’s `d` is `commons-{LAT}-{LON}-{first 12 chars of original event id}`. |
| **Placeholders** | Doc does not list `_MAPURL_`, `_SECTOR_`, `_REGION_`, `_SECTORURL_`, `_REGIONURL_` | All are replaced in `generate_umap_index()` | Add to the placeholders table (see 1.2). |

### 2.3 Call site

- Doc says republish is done by `NOSTR.UMAP.refresh.sh` (function `republish_umap_commons`). **Conform:** `republish_umap_commons "$hex"` is called at the end of `process_umap_messages` for each UMAP.

---

## 3. collaborative-editor.html

- **Not in workspace:** The file `UPlanet/earth/collaborative-editor.html` is not under the AAA repo; the doc correctly states it is part of UPlanet and served via IPNS.
- **Cannot verify:** Tags actually emitted (e.g. `["p", UMAP_PUBKEY_HEX, "", "umap"]`), use of Milkdown, workflow UI, templates (commons, project, decision, garden, resource), quorum/fork-policy handling.
- **Recommendation:** Keep the doc as the specification for the editor; when editing UPlanet, verify that the editor publishes kind 30023 with at least `p` = UMAP hex and one of `t` = "collaborative" or "commons" so that both `umap_index.html` and `republish_umap_commons` discover the document.

---

## 4. Cross-cutting checks

| Check | Result |
|-------|--------|
| Same like threshold (3) for commons in script and doc | ✅ |
| Same list of "approve" reactions in script and index (script: +, 👍, ❤️, ♥️, ✅; index stats: +, ❤️, 👍, ✅, 🤙) | ⚠️ Index includes 🤙, script does not. Doc lists ✅, +, 👍. Inconsistent but harmless (index counts more; script may adopt with slightly different count). Optional: add 🤙 to `count_likes` or document the difference. |
| Filtrage "ami de l’UMAP" = friend in kind 3 contact list | ✅ `friends` from kind 3, `isFromFriend = friends.includes(e.pubkey)` |
| Official = signed by UMAP (adopted) | ✅ `e.pubkey === ZONE_CONFIG.umapPubkeyHex` |

---

## 5. Summary and doc change suggestions

- **Overall:** The doc and the code in this repo are largely aligned. Main gaps are (1) placeholder list incomplete in the doc, (2) adopted event tag set and `d` format not fully described, (3) optional precision on valid like emojis.
- **Suggested doc updates:**
  1. **Placeholders:** Add `_MAPURL_`, `_SECTOR_`, `_REGION_`, `_SECTORURL_`, `_REGIONURL_` to the table "Placeholders injectés par le serveur" with short descriptions.
  2. **Documents adoptés:** Specify that the republished event includes, in addition to `original-author`, `original-event`, `likes`, `adopted-at`, the tags `d` (format `commons-{LAT}-{LON}-{12 first chars of original event id}`), `title`, `t`, `g`, `latitude`, `longitude`, `author`, `version`, `published_at`.
  3. **Réactions kind 7:** Optionally specify that the script (and optionally the index) treats as "like" the content values: +, 👍, ❤️, ♥️, ✅ (and in umap_index stats also 🤙).

---

*Analysis date: 2025-02; codebase: Astroport.ONE (templates, RUNTIME), COLLABORATIVE_COMMONS_SYSTEM.md. collaborative-editor.html not in workspace.*
