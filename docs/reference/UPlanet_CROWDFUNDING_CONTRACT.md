# UPlanet Crowdfunding Contract

**A Decentralized Commons Acquisition Protocol**

---

## Abstract

This document specifies the UPlanet Crowdfunding Contract, a protocol for collaborative acquisition of shared assets (land, buildings, equipment, digital infrastructure, etc.) using a dual-mode ownership transfer system. The protocol distinguishes between **Commons Donations** (non-convertible Ẑen → CAPITAL wallet) and **Cash Sales** (€ → from ASSETS wallet or crowdfunding). Metadata publication occurs via the NOSTR protocol, enabling transparent tracking of campaigns and contributions through kind 7 reactions.

**Protocol Version**: 1.0.0  
**Document Version**: 1.1  
**Keywords**: Crowdfunding, Commons, Shared Assets, Ẑen, Ğ1, Nostr, IPFS, Dual-Mode Acquisition, Cooperative Wallets

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Architecture](#2-system-architecture)
3. [Wallet Infrastructure](#3-wallet-infrastructure)
4. [Ownership Transfer Modes](#4-ownership-transfer-modes)
5. [Campaign Lifecycle](#5-campaign-lifecycle)
6. [Nostr Event Specifications](#6-nostr-event-specifications)
7. [Contribution Mechanisms](#7-contribution-mechanisms)
8. [Security and Validation](#8-security-and-validation)
9. [Integration with UPlanet Ecosystem](#9-integration-with-uplanet-ecosystem)
10. [Use Cases and Examples](#10-use-cases-and-examples)

---

## 1. Introduction

### 1.1 Motivation

Traditional property acquisition presents several challenges for collaborative commons projects:

- **Capital concentration**: Individual purchasers rarely have sufficient funds
- **Legal complexity**: Shared ownership requires complex legal structures
- **Exit difficulty**: Owners cannot easily transfer their share
- **Transparency**: Funding flows are opaque

The **Crowdfunding des Communs** addresses these limitations by:

- **Dual-mode acquisition**: Flexible exit strategies (donation vs. cash sale)
- **Decentralized funding**: Crowdfunding via Ẑen (convertible €) and Ğ1 donations
- **Transparent tracking**: All transactions recorded on Nostr and Ğ1 blockchain
- **Cooperative wallets**: Predefined wallet infrastructure for fund management

### 1.2 Design Principles

1. **Owner Choice**: Property owners choose their exit mode (commons or cash)
2. **Liquidity Priority**: ASSETS wallet used first; crowdfunding only if insufficient
3. **Transparency**: All campaigns and contributions published to Nostr
4. **Provenance**: Complete audit trail via blockchain transactions
5. **Interoperability**: Integration with existing UPlanet infrastructure (DID, ZenCard, MULTIPASS)

### 1.3 Terminology

| Term | Definition |
|------|------------|
| **Commons Donation** | Owner transfers property to collective ownership, receives non-convertible Ẑen |
| **Cash Sale** | Owner sells property share for €, receives Ẑ equivalent |
| **Ẑen** | UPlanet unit (10 Ẑen = 1 Ğ1) |
| **Ğ1 (June)** | Duniter libre currency (blockchain) |
| **CAPITAL Wallet** | Stores non-convertible Ẑen for commons contributions |
| **ASSETS Wallet** | Stores convertible Ẑen for cash purchases |
| **UPLANETNAME_G1** | Cooperative Ğ1 central wallet for donations |
| **Kind 7** | Nostr reaction event for Ẑen transfers |
| **Kind 30023** | Nostr long-form content for campaign documentation |
| **Kind 30904** | Nostr crowdfunding metadata (structured JSON) |

---

## 2. System Architecture

### 2.1 Architectural Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Application Layer                                │
│   (Web UI: crowdfunding.html, collaborative-editor.html)                │
│   (CLI: CROWDFUNDING.sh)                                                │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────────────┐
│                        Protocol Layer                                   │
│   • Campaign Management (create, add-owner, contribute, finalize)       │
│   • Wallet Orchestration (ASSETS, CAPITAL, UPLANETNAME_G1)              │
│   • Nostr Event Publishing (kinds 7, 30023, 30904)                      │
└────────────────┬───────────────────────────────────┬────────────────────┘
                 │                                   │
┌────────────────▼────────────────┐   ┌─────────────▼──────────────────────┐
│       Blockchain Layer          │   │          Metadata Layer            │
│   • Duniter (Ğ1 transactions)   │   │   • Nostr Relays (events)          │
│   • PAYforSURE.sh (transfers)   │   │   • IPFS (project documents)       │
│   • G1check.sh (balance checks) │   │   • DID Documents (kind 30800)     │
└─────────────────────────────────┘   └────────────────────────────────────┘
```

### 2.2 Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| `CROWDFUNDING.sh` | CLI for campaign management |
| `crowdfunding.html` | Web interface for contributions |
| `collaborative-editor.html` | Markdown editor for campaign documents |
| `G1check.sh` | Cached Ğ1/Ẑen balance checks |
| `PAYforSURE.sh` | Secure Ğ1 blockchain transfers |
| `did_manager_nostr.sh` | DID document updates |
| `nostr_send_note.py` | Nostr event publication |
| `7.sh` (relay filter) | Kind 7 reaction processing |

### 2.3 Data Flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌─────────────┐
│   Owner     │────>│  Campaign    │────>│  Crowdfund  │────>│  Finalize   │
│  Declares   │     │  Created     │     │  (if needed)│     │  Transfer   │
│  Intention  │     │              │     │             │     │             │
└─────────────┘     └──────────────┘     └─────────────┘     └─────────────┘
      │                    │                    │                    │
      ▼                    ▼                    ▼                    ▼
  Mode Choice        Check Wallets        Kind 30023/30904     PAYforSURE.sh
  (commons/cash)     (ASSETS balance)     Published            Executes Transfer
```

---

## 3. Wallet Infrastructure

### 3.1 Cooperative Wallet Hierarchy

The UPlanet crowdfunding system relies on three predefined cooperative wallets:

```
                    ┌─────────────────────────────┐
                    │     UPLANETNAME_G1          │
                    │  (Ğ1 Donation Wallet)       │
                    │  • Receives Ğ1 donations    │
                    │  • Low threshold: 10000 Ğ1 │
                    └──────────────┬──────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          │                        │                        │
          ▼                        ▼                        ▼
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│      ASSETS         │  │      CAPITAL        │  │     R&D             │
│  (Convertible Ẑen)  │  │  (Non-conv. Ẑen)    │  │  (Development)      │
│                     │  │                     │  │                     │
│  • Cash purchases   │  │  • Commons contrib. │  │  • Software dev     │
│  • Liquidity pool   │  │  • Long-term hold   │  │  • Infrastructure   │
│  • € convertible    │  │  • Network access   │  │                     │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
```

### 3.2 Wallet Purpose and Rules

| Wallet | Pubkey Source | Purpose | Convertibility |
|--------|---------------|---------|----------------|
| **UPLANETNAME_G1** | `~/.zen/tmp/UPLANETNAME_G1` | Ğ1 donations | Full (Ğ1 native) |
| **ASSETS** | `~/.zen/game/uplanet.ASSETS.dunikey` | Cash purchases | Yes (Ẑen → €) |
| **CAPITAL** | `~/.zen/game/uplanet.CAPITAL.dunikey` | Commons contributions | No (locked Ẑen) |

### 3.3 Campaign Trigger Thresholds

| Condition | Threshold | Action |
|-----------|-----------|--------|
| ASSETS < Cash needed | Dynamic | Launch Ẑen Convertible campaign |
| UPLANETNAME_G1 < 10000 Ğ1 | `G1_LOW_THRESHOLD=10000` | Attach Ğ1 donation campaign |

> **Note**: Le seuil de 10 000 Ğ1 garantit une capacité comptable de ~100 000 Ẑen supplémentaires.

---

## 4. Ownership Transfer Modes

### 4.1 Mode 1: Commons Donation

**Flow**: Owner → Non-convertible Ẑen → CAPITAL wallet

```
┌───────────────┐                    ┌─────────────────┐
│   Property    │                    │    CAPITAL      │
│    Owner      │                    │    Wallet       │
│               │                    │                 │
│  "I donate    │ ──── Ẑen ────────> │  Non-conv Ẑen   │
│   to commons" │     (locked)       │  (permanent)    │
└───────────────┘                    └─────────────────┘
        │                                    │
        │                                    │
        ▼                                    ▼
┌───────────────┐                    ┌─────────────────┐
│   Benefits    │                    │   Collective    │
│   Received:   │                    │   Ownership:    │
│               │                    │                 │
│ • Network     │                    │ • Property in   │
│   access      │                    │   commons       │
│ • All UPlanet │                    │ • Managed by    │
│   ẐEN places  │                    │   cooperative   │
└───────────────┘                    └─────────────────┘
```

**Key Characteristics**:
- Ẑen received is **non-convertible** to € (locked in CAPITAL)
- Owner gains access to entire UPlanet ẐEN network
- Property becomes part of collective commons
- Transaction reference: `UPLANET:{G1PUB}:COMMONS:{EMAIL}:{PROJECT_ID}:{IPFS_NODE}`

### 4.2 Mode 2: Cash Sale

**Flow**: Owner → € equivalent → ASSETS wallet (or crowdfunding)

```
┌───────────────┐                    ┌─────────────────┐
│   Property    │                    │     ASSETS      │
│    Owner      │                    │     Wallet      │
│               │                    │                 │
│  "I sell     │ <──── Ğ1 ───────── │  Convertible    │
│   for cash"   │    (payment)       │      Ẑen        │
└───────────────┘                    └─────────────────┘
        │                                    │
        │                                    │
        ▼                            IF INSUFFICIENT:
┌───────────────┐                           │
│   Benefits    │                           ▼
│   Received:   │                    ┌─────────────────┐
│               │                    │   Crowdfunding  │
│ • € payment   │                    │    Campaign     │
│   (via Ğ1)    │                    │                 │
│ • Immediate   │                    │  "Ẑ conv. €"   │
│   liquidity   │                    │  Collection     │
└───────────────┘                    └─────────────────┘
```

**Key Characteristics**:
- Owner receives € equivalent in Ğ1 (immediately convertible)
- ASSETS wallet used as primary funding source
- If ASSETS insufficient → launch "Ẑen convertible €" crowdfunding
- Transaction reference: `UPLANET:{G1PUB}:CASHOUT:{EMAIL}:{PROJECT_ID}:{IPFS_NODE}`

### 4.3 Mode Decision Matrix

| Owner Intention | Wallet Source | Currency Flow | Convertibility |
|-----------------|---------------|---------------|----------------|
| Commons (donation) | UPLANETNAME_G1 → CAPITAL | Ẑen (locked) | Non-convertible |
| Cash (sale) | ASSETS | Ğ1 → Owner | € convertible |
| Cash (insufficient ASSETS) | Crowdfunding → ASSETS | Ẑen → Ğ1 | € convertible |

---

## 5. Campaign Lifecycle

### 5.1 State Machine

```
                    ┌─────────────┐
                    │   DRAFT     │
                    │  (created)  │
                    └──────┬──────┘
                           │ add-owner
                           ▼
                    ┌─────────────┐
          ┌─────────│  CHECK      │─────────┐
          │         │  WALLETS    │         │
          │         └─────────────┘         │
          │                                 │
          ▼ (sufficient)                    ▼ (insufficient)
   ┌─────────────┐                   ┌─────────────┐
   │   READY     │                   │ CROWDFUNDING│
   │             │                   │  (active)   │
   └──────┬──────┘                   └──────┬──────┘
          │                                 │
          │ finalize                        │ goals reached
          │                                 │
          │         ┌─────────────┐         │
          └────────>│   FUNDED    │<────────┘
                    │             │
                    └──────┬──────┘
                           │ finalize
                           ▼
                    ┌─────────────┐
                    │  COMPLETED  │
                    │ (transfers) │
                    └─────────────┘
```

### 5.2 State Definitions

| State | Description | Transitions |
|-------|-------------|-------------|
| `draft` | Project created, no owners yet | → vote_pending or crowdfunding (add-owner) |
| `vote_pending` | ASSETS usage requires member vote | → funded (vote approved) |
| `crowdfunding` | Active campaign (insufficient ASSETS) | → funded (goals reached) |
| `funded` | All goals reached, ready for finalization | → completed (finalize) |
| `completed` | All transfers executed | Terminal state |

### 5.3 Campaign Launch and Vote System

When an owner is added with `mode=cash`, the system follows this decision tree:

1. **Check ASSETS balance**:
   ```bash
   assets_balance=$(get_assets_balance)
   cash_eur_needed=$(jq -r '.totals.cash_eur' "$project_file")
   g1_for_cash=$(zen_to_g1 "$cash_eur_needed")
   ```

2. **If ASSETS sufficient → Launch VOTE**:
   ```bash
   if (( g1_for_cash <= assets_balance )); then
       # ASSETS could cover, but requires member vote first
       zen_from_assets=$((g1_for_cash * 10))
       jq ".vote = {
           \"assets_vote_active\": true,
           \"assets_amount_zen\": $zen_from_assets,
           \"vote_threshold\": $ASSETS_VOTE_THRESHOLD,  # Default: 100 Ẑen
           \"vote_quorum\": $ASSETS_VOTE_QUORUM,        # Default: 10 voters
           \"vote_status\": \"pending\"
       }" "$project_file"
       # Status: vote_pending
   fi
   ```

3. **If ASSETS insufficient → Launch Crowdfunding**:
   ```bash
   if (( g1_for_cash > assets_balance )); then
       zen_shortfall=$((g1_for_cash - assets_balance) * 10)
       # Launch Ẑen convertible campaign (no vote needed)
   fi
   ```

4. **Check UPLANETNAME_G1 threshold**:
   ```bash
   if (( g1_balance < G1_LOW_THRESHOLD )); then
       # Attach Ğ1 donation campaign
   fi
   ```

### 5.4 Vote Mechanism for ASSETS Usage

The decision to use cooperative ASSETS funds **requires member approval** via Nostr reactions.

**Vote Thresholds**:
| Threshold | Default | Description |
|-----------|---------|-------------|
| `ASSETS_VOTE_THRESHOLD` | 100 Ẑen | Minimum total Ẑen votes required |
| `ASSETS_VOTE_QUORUM` | 10 | Minimum number of distinct voters |

**Vote Validation**: Both conditions must be met for approval.

**Vote Flow**:
```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Cash      │────>│  ASSETS      │────>│   VOTE      │
│   Owner     │     │  Sufficient? │     │   LAUNCHED  │
│   Added     │     │              │     │             │
└─────────────┘     └──────────────┘     └─────────────┘
                           │                    │
                           │ NO                 │ Members vote +Ẑen
                           ▼                    ▼
                    ┌─────────────┐     ┌─────────────┐
                    │ CROWDFUND   │     │  Threshold  │
                    │ Campaign    │     │  + Quorum?  │
                    └─────────────┘     └──────┬──────┘
                                               │
                                        YES    │    NO
                                        ┌──────┴──────┐
                                        ▼             ▼
                                   ┌─────────┐  ┌──────────┐
                                   │ APPROVED│  │ PENDING  │
                                   │→ funded │  │(wait)    │
                                   └─────────┘  └──────────┘
```

---

## 6. Nostr Event Specifications

### 6.1 Kind 30023: Campaign Document

Long-form markdown document describing the crowdfunding campaign.

**Tags**:
```json
[
  ["d", "crowdfunding-{PROJECT_ID}"],
  ["title", "🌳 Crowdfunding: {PROJECT_NAME}"],
  ["t", "crowdfunding"],
  ["t", "UPlanet"],
  ["t", "commons"],
  ["t", "communs"],
  ["g", "{LAT},{LON}"],
  ["project-id", "{PROJECT_ID}"]
]
```

**Content Structure**:
```markdown
# 🌳 {PROJECT_NAME}

{DESCRIPTION}

## 📍 Localisation
Coordonnées: ({LAT}, {LON})

## 💰 Objectifs de Financement

### 💶 Ẑen Convertible € (pour achats cash)
**Objectif:** {ZEN_TARGET} Ẑen
**Collecté:** {ZEN_COLLECTED} Ẑen
**Progression:** {ZEN_PCT}%

### 🪙 Don de Ğ1 (June)
**Objectif:** {G1_TARGET} Ğ1
**Collecté:** {G1_COLLECTED} Ğ1
**Progression:** {G1_PCT}%

## 🤝 Comment Contribuer

### En Ẑen (convertible €)
Envoyez vos Ẑen vers le portefeuille ASSETS avec le commentaire:
`CF:{PROJECT_ID}:ZEN`

### En Ğ1 (June)
Envoyez vos Ğ1 vers le portefeuille UPLANETNAME_G1 avec le commentaire:
`CF:{PROJECT_ID}:G1`

---
*Projet UPlanet ẐEN - Crowdfunding des Communs*
ID: {PROJECT_ID}
```

### 6.2 Kind 30904: Crowdfunding Metadata (JSON)

Structured JSON event for machine parsing by `crowdfunding.html`. **Note:** The CLI `CROWDFUNDING.sh` currently publishes only kind 30023 (long-form campaign document). Kind 30904 is specified here for optional use by the web UI or relay indexing; implementations may derive 30904 from project data or publish it separately.

**Tags**:
```json
[
  ["d", "{PROJECT_ID}"],
  ["title", "{PROJECT_NAME}"],
  ["t", "crowdfunding"],
  ["t", "UPlanet"],
  ["t", "communs"],
  ["g", "{LAT},{LON}"],
  ["e", "{DOCUMENT_EVENT_ID}", "", "document"],
  ["p", "{UMAP_PUBKEY}", "", "umap"],
  ["zen_target", "{ZEN_TARGET}"],
  ["g1_target", "{G1_TARGET}"]
]
```

**Content (JSON)**:
```json
{
  "id": "CF-20250120-XXXX",
  "name": "Atelier Partagé",
  "location": {
    "latitude": 43.60,
    "longitude": 1.44
  },
  "status": "crowdfunding",
  "umapId": "UMAP_43.60_1.44",
  "umapPubkey": "hex_pubkey",
  "documentEventId": "evt_xxx",
  "owners": [
    {
      "email": "alice@example.com",
      "mode": "commons",
      "amount_zen": 500,
      "amount_eur": 0,
      "status": "pending"
    },
    {
      "email": "bob@example.com",
      "mode": "cash",
      "amount_zen": 0,
      "amount_eur": 1000,
      "status": "pending"
    }
  ],
  "totals": {
    "commons_zen": 500,
    "cash_eur": 1000,
    "zen_convertible_target": 800,
    "zen_convertible_collected": 0,
    "g1_target": 100,
    "g1_collected": 0
  },
  "campaigns": {
    "zen_convertible_campaign_active": true,
    "g1_campaign_active": true
  },
  "contributions": [],
  "opencollective": "https://opencollective.com/monnaie-libre"
}
```

### 6.3 Kind 7: Contribution Reaction

Ẑen contributions are sent via Nostr kind 7 reactions, processed by `7.sh` relay filter.

**Event Structure**:
```json
{
  "kind": 7,
  "content": "+50",
  "tags": [
    ["e", "{PROJECT_EVENT_ID}"],
    ["p", "{BIEN_HEX_PUBKEY}"],
    ["t", "crowdfunding"],
    ["t", "UPlanet"],
    ["project-id", "{PROJECT_ID}"],
    ["target", "ZEN_CONVERTIBLE"],
    ["i", "g1pub:{BIEN_G1PUB}"],
    ["k", "30904"]
  ]
}
```

**Note**: The `["p", BIEN_HEX_PUBKEY]` tag now targets the **Bien's own NOSTR identity** (not the UMAP). This ensures contributions go directly to the project's dedicated wallet. The `["i", "g1pub:..."]` tag provides blockchain traceability.

**Content Interpretation**:
| Content | Meaning |
|---------|---------|
| `+` | Send 1 Ẑen |
| `+{N}` | Send N Ẑen (e.g., `+50` = 50 Ẑen) |

**Processing by 7.sh (relay.writePolicy.plugin/filter/)**:

- **Routing order:** Check `vote-assets` first, then `crowdfunding`, so vote events are not processed as contributions.
- **No redundancy:** `CROWDFUNDING.sh contribute` and `CROWDFUNDING.sh vote` only record state; 7.sh is the single place for balance validation and (when applicable) blockchain transfer.

```bash
#!/bin/bash
# 7.sh - Kind 7 Reaction Filter for Crowdfunding
# Part of NIP-101 relay.writePolicy.plugin

# Extract event data (passed by strfry filter)
EVENT_JSON="$1"
CONTENT=$(echo "$EVENT_JSON" | jq -r '.content')
TAGS=$(echo "$EVENT_JSON" | jq '.tags')
SENDER_PUBKEY=$(echo "$EVENT_JSON" | jq -r '.pubkey')

# Extract amount from content (+50 → 50, + → 1) in Ẑen
AMOUNT=$(echo "$CONTENT" | sed 's/+//')
[[ -z "$AMOUNT" || "$AMOUNT" == "$CONTENT" ]] && AMOUNT=1

# --- 1. VOTE-ASSETS (check first to avoid misrouting) ---
IS_VOTE=$(echo "$TAGS" | jq 'any(.[0] == "t" and .[1] == "vote-assets")')
if [[ "$IS_VOTE" == "true" ]]; then
    PROJECT_ID=$(echo "$TAGS" | jq -r '.[] | select(.[0] == "project-id") | .[1]')
    VOTER_G1PUB=$(~/.zen/Astroport.ONE/tools/nostr_did_client.py get "$SENDER_PUBKEY" | jq -r '.g1pub // empty')
    VOTER_BALANCE=$(~/.zen/Astroport.ONE/tools/G1check.sh "${VOTER_G1PUB}:ZEN" 2>/dev/null)
    if [[ -n "$PROJECT_ID" && -n "$VOTER_G1PUB" ]] && [[ $(echo "$VOTER_BALANCE >= $AMOUNT" | bc -l) -eq 1 ]]; then
        # Optional: deduct vote from voter (requires VOTER_KEYFILE path from relay config/DID)
        ~/.zen/Astroport.ONE/tools/CROWDFUNDING.sh vote "$PROJECT_ID" "$SENDER_PUBKEY" "$AMOUNT"
    fi
    exit 0
fi

# --- 2. CROWDFUNDING CONTRIBUTION ---
IS_CROWDFUNDING=$(echo "$TAGS" | jq 'any(.[0] == "t" and .[1] == "crowdfunding")')
if [[ "$IS_CROWDFUNDING" == "true" ]]; then
    PROJECT_ID=$(echo "$TAGS" | jq -r '.[] | select(.[0] == "project-id") | .[1]')
    BIEN_HEX=$(echo "$TAGS" | jq -r '.[] | select(.[0] == "p") | .[1]')
    SENDER_EMAIL=$(~/.zen/Astroport.ONE/tools/nostr_did_client.py get "$SENDER_PUBKEY" | jq -r '.email // empty')
    SENDER_G1PUB=$(~/.zen/Astroport.ONE/tools/nostr_did_client.py get "$SENDER_PUBKEY" | jq -r '.g1pub // empty')
    SENDER_BALANCE=$(~/.zen/Astroport.ONE/tools/G1check.sh "${SENDER_G1PUB}:ZEN" 2>/dev/null)

    if [[ -n "$PROJECT_ID" && -n "$SENDER_EMAIL" && -n "$SENDER_G1PUB" ]] && [[ $(echo "$SENDER_BALANCE >= $AMOUNT" | bc -l) -eq 1 ]]; then
        PROJECT_DIR="$HOME/.zen/game/crowdfunding/$PROJECT_ID"
        if [[ -f "$PROJECT_DIR/bien.pubkeys" ]]; then
            source "$PROJECT_DIR/bien.pubkeys"
            # PAYforSURE.sh: keyfile amount_g1 recipient_g1pub comment (amount in Ğ1: Ẑen/10)
            AMOUNT_G1=$(echo "scale=2; $AMOUNT / 10" | bc -l)
            SENDER_KEYFILE="$HOME/.zen/game/nostr/${SENDER_EMAIL}/.secret.dunikey"
            if [[ -f "$SENDER_KEYFILE" ]]; then
                ~/.zen/Astroport.ONE/tools/PAYforSURE.sh "$SENDER_KEYFILE" "$AMOUNT_G1" "$BIEN_G1PUB" "CF:$PROJECT_ID:$SENDER_EMAIL"
            fi
            ~/.zen/Astroport.ONE/tools/CROWDFUNDING.sh contribute "$PROJECT_ID" "$SENDER_EMAIL" "$AMOUNT" "ZEN"
        fi
    fi
fi
```

**7.sh conformity (NIP-101/relay.writePolicy.plugin/filter/7.sh):** The filter must (1) evaluate vote-assets before crowdfunding; (2) use PAYforSURE only with keyfile path and amount in Ğ1; (3) call `CROWDFUNDING.sh contribute` / `CROWDFUNDING.sh vote` only after validation. `CROWDFUNDING.sh` does not perform balance checks or PAYforSURE when invoked by 7.sh—no redundancy.

### 6.4 Kind 7: Vote Reaction (ASSETS Usage)

Members vote on ASSETS usage via Nostr kind 7 reactions with the `vote-assets` tag.

**Event Structure**:
```json
{
  "kind": 7,
  "content": "+5",
  "tags": [
    ["e", "{PROJECT_EVENT_ID}"],
    ["p", "{BIEN_HEX_PUBKEY}"],
    ["t", "vote-assets"],
    ["t", "UPlanet"],
    ["project-id", "{PROJECT_ID}"],
    ["vote-type", "ASSETS_USAGE"],
    ["k", "30904"]
  ]
}
```

**Note**: The `["p", BIEN_HEX_PUBKEY]` tag targets the Bien's NOSTR identity for vote routing.

**Vote Weight**:
| Content | Vote Weight |
|---------|-------------|
| `+` | 1 Ẑen vote |
| `+{N}` | N Ẑen votes (e.g., `+5` = 5 Ẑen) |

**Processing:** Handled in the same 7.sh filter (see §6.3); vote-assets branch is evaluated first. Vote recording is done by `CROWDFUNDING.sh vote`; optional deduction from voter balance requires relay access to voter keyfile (same pattern as contribution).

**Validation Rules**:
- Each pubkey can only vote once per project
- Vote amount is deducted from voter's balance
- Both threshold AND quorum must be reached for approval

---

## 7. Contribution Mechanisms

### 7.1 Web Interface Flow (crowdfunding.html)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     crowdfunding.html                                    │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  1. Connect MULTIPASS (Nostr extension)                                  │
│     • getPublicKey()                                                     │
│     • Fetch profile (kind 0)                                             │
│     • Extract g1pub from tags                                            │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  2. Fetch ZEN Balance                                                    │
│     • GET /check_balance?g1pub={pubkey}                                  │
│     • Calculate: zen = (g1_balance - 1) * 10                             │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  3. Select Project & Amount                                              │
│     • Browse active campaigns (kind 30904)                               │
│     • Choose contribution amount (1-1000 Ẑen)                            │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  4. Sign & Publish Kind 7 Reaction                                       │
│     • content: "+{amount}"                                               │
│     • tags: [["p", umap_pubkey], ["project-id", id], ...]               │
│     • window.nostr.signEvent(event)                                      │
│     • pool.publish(relays, signedEvent)                                  │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  5. Relay Processing (7.sh)                                              │
│     • Validate sender balance                                            │
│     • Execute PAYforSURE.sh transfer                                     │
│     • Update project contributions                                       │
│     • Publish confirmation event                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 CLI Contribution Flow

```bash
# Record contribution manually
./CROWDFUNDING.sh contribute CF-20250120-XXXX contributor@email.com 100 ZEN

# Contribution JSON structure
{
    "contributor_email": "contributor@email.com",
    "amount": 100,
    "currency": "ZEN",
    "timestamp": "2025-01-20T12:34:56Z"
}
```

### 7.3 Alternative: OpenCollective Recharge

For users without existing Ẑen balance:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  OpenCollective UPlanet (https://opencollective.com/monnaie-libre)        │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              │ Payment (€)
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Sociétaire Tiers:                                                       │
│    • Satellite: 54€/year → 540 Ẑen (MULTIPASS activation)               │
│    • Constellation: 540€/year → 5400 Ẑen + IA access                    │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              │ ZenCard credited
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  User can now contribute to crowdfunding campaigns                       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Security and Validation

### 8.1 Transaction Validation Chain

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌─────────────┐
│  Kind 7     │────>│   7.sh       │────>│ PAYforSURE  │────>│  Duniter    │
│  Reaction   │     │  Filter      │     │    .sh      │     │  Blockchain │
└─────────────┘     └──────────────┘     └─────────────┘     └─────────────┘
      │                    │                    │                    │
      ▼                    ▼                    ▼                    ▼
  Nostr Sig           Balance Check        Tx Reference         Immutable
  Verified            Sufficient?          Encoded              Record
```

### 8.2 PAYforSURE.sh Security

```bash
# Transaction reference encoding
reference="UPLANET:${UPLANETG1PUB:0:8}:${MODE}:${EMAIL}:${PROJECT_ID}:${IPFSNODEID}"

# Execute with dunikey authentication
PAYforSURE.sh "$DUNIKEY_FILE" "$AMOUNT" "$RECIPIENT_PUBKEY" "$reference"

# Exit code 0 = success (skip additional confirmation per memory)
```

### 8.3 DID Update on Contribution

```bash
# Update contributor's DID document with commons contribution
did_manager_nostr.sh update "$EMAIL" "COMMONS_CONTRIBUTION" "$amount_zen" "$g1_amount"

# Adds to metadata.contributions array in kind 30800 event
```

### 8.4 Validation Rules

| Rule | Validation | Error Response |
|------|------------|----------------|
| Sender balance | `sender_balance >= amount` | "Insufficient balance" |
| Project exists | `project_file exists` | "Project not found" |
| Campaign active | `status == "crowdfunding"` | "Campaign not active" |
| Amount range | `1 <= amount <= 1000` | "Invalid amount" |
| Nostr signature | `schnorr_verify(event)` | "Invalid signature" |

---

## 9. Integration with UPlanet Ecosystem

### 9.1 DID Integration (kind 30800)

Crowdfunding contributions update the contributor's DID document:

```json
{
  "kind": 30800,
  "content": {
    "metadata": {
      "contractStatus": "SOCIETAIRE",
      "contributions": [
        {
          "projectId": "CF-20250120-XXXX",
          "type": "crowdfunding",
          "amount": 100,
          "currency": "ZEN",
          "timestamp": "2025-01-20T12:34:56Z"
        }
      ]
    }
  }
}
```

### 9.2 ZenCard Integration

Contributions are deducted from the sender's ZenCard balance:

```
ZenCard Balance = (G1_Blockchain_Balance - 1) × 10
```

### 9.3 UMAP Geolocation

Projects are geolocated and tagged with UMAP coordinates:

```bash
# UMAP identifier
umapId="UMAP_${LAT_2DECIMALS}_${LON_2DECIMALS}"

# Example: UMAP_43.60_1.44
```

### 9.4 Cooperative Config Integration

```bash
# Load cooperative configuration
source "${MY_PATH}/cooperative_config.sh"
coop_load_env_vars

# Available variables:
# - CAPTAINEMAIL (project captain)
# - UPLANETG1PUB (cooperative pubkey)
# - IPFSNODEID (node identifier)
```

---

## 10. Use Cases and Examples

### 10.1 Example: Commons with Mixed Owners

**Scenario**: A shared asset with 2 owners, different intentions.

```bash
# 1. Create project
./CROWDFUNDING.sh create 43.60 1.44 "Atelier Partagé" "Projet de bien commun collaboratif"
# → CF-20250120-A1B2

# 2. Add commons owner (Alice donates to commons)
./CROWDFUNDING.sh add-owner CF-20250120-A1B2 alice@example.com commons 500
# → Adds 500 Ẑen (non-convertible) to CAPITAL target

# 3. Add cash owner (Bob wants € payment)
./CROWDFUNDING.sh add-owner CF-20250120-A1B2 bob@example.com cash 1000
# → Checks ASSETS balance
# → If ASSETS sufficient: launches VOTE (status: vote_pending)
# → If ASSETS insufficient: launches Ẑen convertible campaign

# 4. Check vote status (if vote was launched)
./CROWDFUNDING.sh vote-status CF-20250120-A1B2
# → Shows vote progress: X/100 Ẑen, Y/10 voters

# 5. Members vote (via Nostr or CLI)
./CROWDFUNDING.sh vote CF-20250120-A1B2 PUBKEY1 5   # Member votes +5 Ẑen
./CROWDFUNDING.sh vote CF-20250120-A1B2 PUBKEY2 10  # Member votes +10 Ẑen
# ... more votes until threshold (100 Ẑen) and quorum (10 voters) reached

# 4. Check status
./CROWDFUNDING.sh status CF-20250120-A1B2
# → Shows progress, campaigns, contributions

# 5. Contributions received (via crowdfunding.html or direct)
./CROWDFUNDING.sh contribute CF-20250120-A1B2 donor@example.com 200 ZEN

# 6. Finalize when funded
./CROWDFUNDING.sh finalize CF-20250120-A1B2
# → Alice: 500 Ẑen → CAPITAL (non-convertible)
# → Bob: 100 Ğ1 → his wallet (from ASSETS)
```

### 10.2 Wallet Flow Diagram

```
                        CONTRIBUTIONS
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
           ▼                 ▼                 ▼
    ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
    │ Ẑen (conv.) │   │  Ğ1 Direct  │   │ OpenCollect │
    │   Kind 7    │   │  Donation   │   │   (€→Ẑen)   │
    └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
           │                 │                 │
           ▼                 ▼                 │
    ┌─────────────┐   ┌─────────────┐         │
    │   ASSETS    │   │ UPLANETNAME │         │
    │   Wallet    │   │    _G1      │         │
    └──────┬──────┘   └─────────────┘         │
           │                                   │
           └───────────────┬───────────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │  Commons    │ │    Cash     │ │   ZenCard   │
    │  Donation   │ │    Sale     │ │   Recharge  │
    │  (Owner A)  │ │  (Owner B)  │ │   (Donor)   │
    └──────┬──────┘ └──────┬──────┘ └─────────────┘
           │               │
           ▼               ▼
    ┌─────────────┐ ┌─────────────┐
    │   CAPITAL   │ │   Owner B   │
    │   Wallet    │ │   Wallet    │
    │  (locked)   │ │  (liquid)   │
    └─────────────┘ └─────────────┘
```

### 10.3 CLI Command Reference

| Command | Description |
|---------|-------------|
| `create LAT LON NAME [DESC]` | Create new project |
| `add-owner ID EMAIL MODE AMT` | Add property owner |
| `status ID` | Show project status |
| `contribute ID EMAIL AMT CUR` | Record contribution |
| `vote ID PUBKEY AMT` | Vote +Ẑen for ASSETS usage |
| `vote-status ID` | Show vote progress |
| `finalize ID` | Execute transfers (requires vote approval) |
| `list [--active\|--completed]` | List projects |
| `dashboard` | Interactive dashboard |

---

## Appendix A: Currency Conversion

| From | To | Rate | Example |
|------|----|------|---------|
| Ẑen | Ğ1 | ÷ 10 | 100 Ẑen = 10 Ğ1 |
| Ğ1 | Ẑen | × 10 | 10 Ğ1 = 100 Ẑen |
| € | Ẑen | ≈ 1:1 | 100€ ≈ 100 Ẑen |
| € | Ğ1 | ≈ 1:0.1 | 100€ ≈ 10 Ğ1 |

---

## Appendix B: Transaction Reference Format

```
UPLANET:{G1PUB_8CHARS}:{MODE}:{EMAIL}:{PROJECT_ID}:{IPFS_NODE_ID}

Examples:
- UPLANET:A1B2C3D4:COMMONS:alice@example.com:CF-20250120-XXXX:12D3KooW...
- UPLANET:A1B2C3D4:CASHOUT:bob@example.com:CF-20250120-XXXX:12D3KooW...
```

---

## Document Metadata

- **Protocol Version**: 1.0.0
- **Document Version**: 1.0
- **Date**: 2025-01-20
- **Authors**: UPlanet Development Team
- **License**: AGPL-3.0
- **Repository**: https://github.com/papiche/Astroport.ONE

---

**END OF DOCUMENT**
