# UPlanet File Management Contract

**A Decentralized File Storage and Metadata Publishing Protocol**

---

## Abstract

This document specifies the UPlanet File Management Contract, a protocol for decentralized file storage using IPFS (InterPlanetary File System) and metadata publication via the NOSTR (Notes and Other Stuff Transmitted by Relays) protocol. The system implements a separation-of-concerns architecture distinguishing between video content (NIP-71, kinds 21/22) and general file metadata (NIP-94, kind 1063), while ensuring provenance tracking through cryptographic hashing and chain-of-custody mechanisms.

**Protocol Version**: 2.0.0  
**Document Version**: 1.3  
**JSON Canonicalization**: RFC 8785 (JCS) compliant  
**Metadata Format**: See [INFO_JSON_FORMATS.md](INFO_JSON_FORMATS.md) for v2.0 specification  
**Keywords**: IPFS, NOSTR, NIP-94, NIP-71, NIP-96, Decentralized Storage, Provenance Tracking, Metadata Publishing, RFC 8785, JSON Canonicalization, MULTIPASS, Tiered Quotas

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Architecture](#2-system-architecture)
3. [Protocol Specifications](#3-protocol-specifications)
4. [Metadata Extraction Pipeline](#4-metadata-extraction-pipeline)
5. [Provenance Tracking Mechanism](#5-provenance-tracking-mechanism)
6. [Security Considerations](#6-security-considerations)
7. [Implementation Details](#7-implementation-details)
8. [Administrative Tools](#8-administrative-tools)
9. [Use Cases and Examples](#9-use-cases-and-examples)
10. [References](#10-references)

---

## 1. Introduction

### 1.1 Motivation

Traditional centralized file storage systems present several challenges:
- **Single point of failure**: Server outages result in complete service unavailability
- **Censorship vulnerability**: Centralized control enables arbitrary content removal
- **Data portability issues**: Vendor lock-in complicates migration
- **Privacy concerns**: Centralized entities have complete access to user data

The UPlanet File Management Contract addresses these limitations by leveraging:
- **IPFS**: Content-addressed, distributed file storage
- **NOSTR**: Censorship-resistant, decentralized event publishing
- **Cryptographic hashing**: Immutable content identification and provenance tracking

### 1.2 Design Principles

The protocol adheres to the following design principles:

1. **Separation of Concerns**: Distinct workflows for different file types (video vs. non-video)
2. **Content Addressing**: Files identified by cryptographic hash rather than location
3. **Provenance Tracking**: Complete audit trail of file upload history
4. **Metadata Richness**: Type-specific metadata extraction (dimensions, duration, codecs)
5. **Idempotency**: Re-uploading identical files reuses existing IPFS CIDs
6. **Interoperability**: Compliance with NOSTR Improvement Proposals (NIPs)

### 1.3 Terminology

- **CID (Content Identifier)**: IPFS cryptographic hash identifying file content
- **NIP (NOSTR Improvement Proposal)**: Protocol specification for NOSTR events
- **Kind**: NOSTR event type identifier (1063 for files, 21/22 for videos)
- **Provenance**: Chain-of-custody tracking for file uploads
- **Upload Chain**: Array of objects with `pubkey` and `timestamp` representing upload history (in info.json), or comma-separated string in Nostr tags (backward compatibility)

---

## 2. System Architecture

### 2.1 Architectural Overview

The system implements a three-layer architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Application Layer                            │
│  (Client: Web Browser, CLI, Mobile App)                          │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTP/REST API
┌────────────────────────▼────────────────────────────────────────┐
│                     Service Layer                                │
│  • FastAPI Backend (54321.py)                                    │
│  • File Upload Endpoint (/api/fileupload)                        │
│  • Video Publishing Endpoint (/webcam)                           │
│  • Authentication & Authorization (NOSTR NIP-42)                 │
└────────────────┬────────────────────────┬───────────────────────┘
                 │                        │
        ┌────────▼────────┐      ┌───────▼────────┐
        │  Storage Layer  │      │  Metadata Layer │
        │  (IPFS Network) │      │ (NOSTR Relays)  │
        └─────────────────┘      └─────────────────┘
```

### 2.2 Component Responsibilities

#### 2.2.1 Client Layer
- File selection and upload initiation
- Metadata input (title, description, geolocation)
- Authentication via NOSTR keys (npub/nsec)

#### 2.2.2 Service Layer
- **upload2ipfs.sh**: Bash script for IPFS upload and metadata extraction
- **publish_nostr_file.sh**: Unified NIP-94 event publisher
- **publish_nostr_video.sh**: Specialized NIP-71 video event publisher
- **54321.py**: FastAPI application coordinating workflows

#### 2.2.3 Storage Layer
- **IPFS**: Content-addressed file storage with CID generation
- **Local IPFS Node**: Gateway and pinning service

#### 2.2.4 Metadata Layer
- **NOSTR Relay (strfry)**: Local event storage and relay
- **External Relays**: Federation for event propagation

### 2.3 Separation of Concerns: Video vs. Audio vs. Other Files

The protocol distinguishes between video files, audio files, and other file types due to:

1. **Metadata Complexity**:
   - Videos require: duration, dimensions, thumbnail, animated GIF
   - Audio requires: duration, codecs, waveform (optional)
   - Other files: basic metadata (size, type, hash)

2. **User Experience**:
   - Videos: Two-step workflow (upload → preview → publish)
   - Audio: Two-step workflow (upload → preview → publish via /vocals)
   - Other files: Single-step workflow (upload → immediate publish)

3. **NOSTR Event Types**:
   - Videos: NIP-71 (kinds 21/22) with specialized tags
   - Audio: NIP-A0 (kinds 1222/1244) for voice messages
   - Other files: NIP-94 (kind 1063) with generic file metadata

**Decision Matrix**:

| File Type | MIME Pattern | Endpoint | NOSTR Kind | Script |
|-----------|--------------|----------|------------|---------|
| Video | `video/*` | `/api/fileupload` → `/webcam` | 21 or 22 | `publish_nostr_video.sh` |
| Audio | `audio/*` | `/api/fileupload` → `/vocals` | 1222 or 1244 | Backend (NIP-A0) |
| Image | `image/*` | `/api/fileupload` | 1063 | `publish_nostr_file.sh` |
| Document | `application/*`, `text/*` | `/api/fileupload` | 1063 | `publish_nostr_file.sh` |

---

## 3. Protocol Specifications

### 3.1 Workflow: Non-Video, Non-Audio File Upload

**Note**: This workflow applies to images, documents, and other file types. Audio files follow a two-phase workflow similar to videos (see section 3.4), and video files have their own workflow (see section 3.2).

```
┌──────────┐      ┌──────────┐      ┌──────────────┐      ┌──────────┐
│  Client  │      │ 54321.py │      │upload2ipfs.sh│      │  NOSTR   │
└────┬─────┘      └────┬─────┘      └──────┬───────┘      └────┬─────┘
     │                 │                    │                   │
     │ POST /api/      │                    │                   │
     │ fileupload      │                    │                   │
     ├────────────────>│                    │                   │
     │                 │                    │                   │
     │                 │ Execute script     │                   │
     │                 ├───────────────────>│                   │
     │                 │                    │                   │
     │                 │                    │ 1. Upload to IPFS │
     │                 │                    │ 2. Extract metadata
     │                 │                    │ 3. Calculate SHA256
     │                 │                    │ 4. Check provenance
     │                 │                    │                   │
     │                 │ JSON output        │                   │
     │                 │<───────────────────┤                   │
     │                 │                    │                   │
     │                 │ Verify MIME type   │                   │
     │                 │ IF NOT video/*:    │                   │
     │                 │   Call publish_    │                   │
     │                 │   nostr_file.sh    │                   │
     │                 ├────────────────────────────────────────>│
     │                 │                    │                   │
     │                 │                    │         Publish NIP-94
     │                 │                    │         (kind 1063)
     │                 │                    │                   │
     │                 │ Event ID           │                   │
     │                 │<────────────────────────────────────────┤
     │                 │                    │                   │
     │ UploadResponse  │                    │                   │
     │<────────────────┤                    │                   │
     │                 │                    │                   │
```

**Protocol Steps**:

1. **Client Request**: HTTP POST with multipart/form-data containing:
   - `file`: Binary file content
   - `npub`: NOSTR public key (authentication)

2. **File Persistence**: Save to user-specific directory
   ```
   ~/.zen/game/players/{SECTOR}/{EMAIL}/{FILENAME}
   ```

3. **IPFS Upload**: Execute `upload2ipfs.sh`:
   ```bash
   upload2ipfs.sh "$FILE_PATH" "$OUTPUT_JSON" "$USER_HEX"
   ```

4. **Metadata Extraction**: Type-specific processing:
   - **Images**: Extract dimensions (ImageMagick `identify`)
   - **Images (non-JPG)**: Generate JPG thumbnail (ImageMagick `convert`)
   - **Audio**: Extract duration (ffprobe)

5. **Provenance Check**: Search NOSTR for existing events with identical SHA256 hash

6. **MIME Type Verification**:
   ```python
   if not file_mime.startswith('video/') and not file_mime.startswith('audio/') and not is_reupload:
       # Publish to NOSTR (kind 1063)
       # Note: Audio files are published via /vocals endpoint (kind 1222/1244)
   ```

7. **NOSTR Publication**: Execute `publish_nostr_file.sh`:
   ```bash
   publish_nostr_file.sh --auto "$OUTPUT_JSON" \
                         --nsec "$SECRET_FILE" \
                         --title "$TITLE" \
                         --json
   ```

8. **Response**: Return `UploadResponse` with:
   - `cid`: IPFS Content Identifier
   - `fileName`: Original filename
   - `thumbnail_ipfs`: Thumbnail CID (if applicable)
   - `info`: info.json CID (complete metadata)
   - `upload_chain`: Provenance chain

### 3.2 Workflow: Video File Upload

Video files follow a **two-phase workflow**:

**Phase 1: IPFS Upload and Metadata Generation**

```
┌──────────┐      ┌──────────┐      ┌──────────────┐
│  Client  │      │ 54321.py │      │upload2ipfs.sh│
└────┬─────┘      └────┬─────┘      └──────┬───────┘
     │                 │                    │
     │ POST /api/      │                    │
     │ fileupload      │                    │
     ├────────────────>│                    │
     │                 │                    │
     │                 │ Execute script     │
     │                 ├───────────────────>│
     │                 │                    │
     │                 │                    │ 1. Upload to IPFS
     │                 │                    │ 2. Generate thumbnail
     │                 │                    │    (ffmpeg @ 10% duration)
     │                 │                    │ 3. Generate GIF
     │                 │                    │    (ffmpeg @ φ ratio, 1.6s)
     │                 │                    │ 4. Extract duration
     │                 │                    │ 5. Extract dimensions
     │                 │                    │
     │                 │ JSON output        │
     │                 │<───────────────────┤
     │                 │                    │
     │                 │ Detect video/*     │
     │                 │ SKIP NOSTR         │
     │                 │ (deferred to /webcam)
     │                 │                    │
     │ UploadResponse  │                    │
     │ (cid, thumb,    │                    │
     │  gif, info)     │                    │
     │<────────────────┤                    │
```

**Phase 2: NOSTR Publication with User Metadata**

```
┌──────────┐      ┌──────────┐      ┌────────────────────┐      ┌──────────┐
│  Client  │      │ 54321.py │      │publish_nostr_video.sh│      │  NOSTR   │
└────┬─────┘      └────┬─────┘      └─────────┬──────────┘      └────┬─────┘
     │                 │                       │                      │
     │ POST /webcam    │                       │                      │
     │ (cid, thumb,    │                       │                      │
     │  gif, title,    │                       │                      │
     │  description,   │                       │                      │
     │  location)      │                       │                      │
     ├────────────────>│                       │                      │
     │                 │                       │                      │
     │                 │ Verify NIP-42 auth    │                      │
     │                 │                       │                      │
     │                 │ Execute script        │                      │
     │                 ├──────────────────────>│                      │
     │                 │                       │                      │
     │                 │                       │ Build NIP-71 tags:   │
     │                 │                       │ - title, url         │
     │                 │                       │ - duration           │
     │                 │                       │ - thumbnail_ipfs     │
     │                 │                       │ - gifanim_ipfs       │
     │                 │                       │ - dimensions         │
     │                 │                       │ - imeta              │
     │                 │                       │ - geolocation        │
     │                 │                       │ - upload_chain       │
     │                 │                       │                      │
     │                 │                       │ Determine kind:      │
     │                 │                       │ - 21 if > 60s        │
     │                 │                       │ - 22 if ≤ 60s        │
     │                 │                       │                      │
     │                 │                       │ Publish event        │
     │                 │                       ├─────────────────────>│
     │                 │                       │                      │
     │                 │ Event ID              │                      │
     │                 │<──────────────────────┤                      │
     │                 │                       │                      │
     │ Success         │                       │                      │
     │<────────────────┤                       │                      │
```

**Rationale for Two-Phase Workflow**:

1. **User Control**: Allows preview of video with generated thumbnail/GIF before publication
2. **Metadata Enrichment**: User provides title, description, geolocation after preview
3. **Network Efficiency**: Avoids publishing incomplete metadata that would require event deletion

### 3.3 Workflow: Audio File Upload (Voice Messages)

Audio files follow a **two-phase workflow** similar to videos, using NIP-A0 (kinds 1222/1244) instead of NIP-71:

**Phase 1: IPFS Upload and Metadata Generation**

```
┌──────────┐      ┌──────────┐      ┌──────────────┐
│  Client  │      │ 54321.py │      │upload2ipfs.sh│
└────┬─────┘      └────┬─────┘      └──────┬───────┘
     │                 │                    │
     │ POST /api/      │                    │
     │ fileupload      │                    │
     ├────────────────>│                    │
     │                 │                    │
     │                 │ Execute script     │
     │                 ├───────────────────>│
     │                 │                    │
     │                 │                    │ 1. Upload to IPFS
     │                 │                    │ 2. Extract duration
     │                 │                    │ 3. Extract codecs
     │                 │                    │ 4. Calculate SHA256
     │                 │                    │
     │                 │ JSON output        │
     │                 │<───────────────────┤
     │                 │                    │
     │                 │ Detect audio/*     │
     │                 │ SKIP NOSTR         │
     │                 │ (deferred to /vocals)
     │                 │                    │
     │ UploadResponse  │                    │
     │ (cid, info)      │                    │
     │<────────────────┤                    │
```

**Phase 2: NOSTR Publication with User Metadata**

```
┌──────────┐      ┌──────────┐      ┌──────────┐
│  Client  │      │ 54321.py │      │  NOSTR   │
└────┬─────┘      └────┬─────┘      └────┬─────┘
     │                 │                  │
     │ POST /vocals     │                  │
     │ (cid, title,     │                  │
     │  description,   │                  │
     │  encrypted,      │                  │
     │  recipients)     │                  │
     ├────────────────>│                  │
     │                 │                  │
     │                 │ Verify NIP-42    │
     │                 │                  │
     │                 │ Build NIP-A0 tags:
     │                 │ - url (IPFS CID) │
     │                 │ - imeta (duration, waveform)
     │                 │ - e (reply-to, if kind 1244)
     │                 │ - p (reply-to author, if kind 1244)
     │                 │                  │
     │                 │ Determine kind:  │
     │                 │ - 1222 if root   │
     │                 │ - 1244 if reply  │
     │                 │                  │
     │                 │ Publish event    │
     │                 ├─────────────────>│
     │                 │                  │
     │                 │ Event ID         │
     │                 │<─────────────────┤
     │                 │                  │
     │ Success         │                  │
     │<────────────────┤                  │
```

**Key Differences from Video Workflow**:
- Uses NIP-A0 (kinds 1222/1244) instead of NIP-71 (kinds 21/22)
- No thumbnail or animated GIF generation
- Optional waveform generation for visual preview
- Supports end-to-end encryption (NIP-44 or NIP-04)
- Duration typically limited to 60 seconds (recommended)

### 3.4 Workflow: Re-Upload (Provenance Tracking)

```
┌──────────┐      ┌──────────┐      ┌──────────────┐      ┌──────────┐
│  User B  │      │ 54321.py │      │upload2ipfs.sh│      │  NOSTR   │
└────┬─────┘      └────┬─────┘      └──────┬───────┘      └────┬─────┘
     │                 │                    │                   │
     │ POST /api/      │                    │                   │
     │ fileupload      │                    │                   │
     │ (same file as   │                    │                   │
     │  User A)        │                    │                   │
     ├────────────────>│                    │                   │
     │                 │                    │                   │
     │                 │ Execute script     │                   │
     │                 │ with user_hex_B    │                   │
     │                 ├───────────────────>│                   │
     │                 │                    │                   │
     │                 │                    │ Calculate SHA256  │
     │                 │                    │                   │
     │                 │                    │ Query NOSTR for   │
     │                 │                    │ existing hash     │
     │                 │                    ├──────────────────>│
     │                 │                    │                   │
     │                 │                    │ Return event from │
     │                 │                    │ User A            │
     │                 │                    │<──────────────────┤
     │                 │                    │                   │
     │                 │                    │ REUSE existing CID│
     │                 │                    │ Download + pin    │
     │                 │                    │ (ipfs get)        │
     │                 │                    │                   │
     │                 │                    │ Build upload_chain:
     │                 │                    │ "hex_A,hex_B"     │
     │                 │                    │                   │
     │                 │ JSON (provenance)  │                   │
     │                 │ is_reupload=true   │                   │
     │                 │<───────────────────┤                   │
     │                 │                    │                   │
     │                 │ Detect re-upload   │                   │
     │                 │ SKIP NOSTR         │                   │
     │                 │ (event exists)     │                   │
     │                 │                    │                   │
     │ UploadResponse  │                    │                   │
     │ (reused CID,    │                    │                   │
     │  upload_chain:  │                    │                   │
     │  A→B)           │                    │                   │
     │<────────────────┤                    │                   │
```

**Provenance Mechanism**:

1. **Hash-Based Lookup**: SHA256 hash used to search NOSTR for existing events
2. **CID Reuse**: Identical files share the same IPFS CID (content-addressing property)
3. **Chain Extension**: `upload_chain` array appends new uploader's public key with timestamp
4. **No Duplicate Events**: Prevents redundant NOSTR events for identical content
5. **Audit Trail**: Complete history of file custody preserved in `upload_chain` with timestamps for each upload

---

## 4. Metadata Extraction Pipeline

### 4.1 Type-Specific Metadata

The system extracts metadata based on MIME type:

#### 4.1.1 Images (`image/*`)

**Extraction Tools**: ImageMagick (`identify`, `convert`)

**Metadata Collected**:
- **Dimensions**: Width × Height (e.g., "1920x1080")
- **Thumbnail**: JPG conversion for non-JPG images
  - Quality: 85
  - Max dimension: 1200×1200
  - Optimization: Strip metadata

**NIP-94 Tags**:
```json
{
  "kind": 1063,
  "tags": [
    ["url", "/ipfs/{CID}/{filename}"],
    ["m", "image/png"],
    ["x", "{SHA256_hash}"],
    ["dim", "1920x1080"],
    ["r", "/ipfs/{thumb_CID}", "Thumbnail"],
    ["image", "/ipfs/{thumb_CID}"],
    ["thumbnail_ipfs", "{thumb_CID}"],
    ["info", "{info_CID}"],
    ["upload_chain", "{pubkey_list}"]
  ]
}
```

**Implementation**:
```bash
# Dimensions extraction
IMAGE_DIMENSIONS=$(identify -format "%wx%h" "$FILE_PATH")

# Thumbnail generation (non-JPG only)
if [[ ! "$FILE_TYPE" =~ ^image/jpe?g$ ]]; then
    convert "$FILE_PATH" -resize 1200x1200\> \
            -quality 85 -strip "$THUMBNAIL_PATH"
fi
```

#### 4.1.2 Audio (`audio/*`)

**Extraction Tool**: ffprobe

**Metadata Collected**:
- **Duration**: Seconds (floating point)
- **Codecs**: Audio codec names (in info.json)
- **Waveform**: Optional amplitude values for visual preview (NIP-A0)

**Note**: Audio files are **NOT** published with NIP-94 (kind 1063). They are published via `/vocals` endpoint using NIP-A0 (kinds 1222/1244) for voice messages.

**NIP-A0 Tags** (kinds 1222/1244):
```json
{
  "kind": 1222,
  "content": "https://ipfs.copylaradio.com/ipfs/{CID}/{filename}",
  "tags": [
    ["url", "https://ipfs.copylaradio.com/ipfs/{CID}/{filename}"],
    ["imeta", "url https://ipfs.copylaradio.com/ipfs/{CID}/{filename}", "duration 45", "waveform ..."],
    ["x", "{SHA256_hash}"],
    ["info", "{info_CID}"]
  ]
}
```

**For replies (kind 1244)**:
```json
{
  "kind": 1244,
  "content": "https://ipfs.copylaradio.com/ipfs/{CID}/{filename}",
  "tags": [
    ["e", "{root_event_id}"],
    ["p", "{root_author_pubkey}"],
    ["url", "https://ipfs.copylaradio.com/ipfs/{CID}/{filename}"],
    ["imeta", "url https://ipfs.copylaradio.com/ipfs/{CID}/{filename}", "duration 30"],
    ["x", "{SHA256_hash}"]
  ]
}
```

**Implementation**:
```bash
# Duration extraction
DURATION=$(ffprobe -v error -show_entries format=duration \
           -of default=noprint_wrappers=1:nokey=1 "$FILE_PATH")

# Codec extraction
AUDIO_CODECS=$(ffprobe -v error -select_streams a \
               -show_entries stream=codec_name -of csv=p=0 "$FILE_PATH")
```

#### 4.1.3 Videos (`video/*`)

**Extraction Tools**: ffprobe, ffmpeg

**Metadata Collected**:
- **Duration**: Seconds
- **Dimensions**: Width × Height
- **Thumbnail**: JPG frame extracted at 10% of duration
- **Animated GIF**: 1.6-second clip at φ ratio (0.618) of duration
- **Codecs**: Video and audio codec names

**NIP-71 Tags** (kind 21/22):
```json
{
  "kind": 21,
  "tags": [
    ["title", "Video Title"],
    ["url", "/ipfs/{CID}/{filename}"],
    ["m", "video/mp4"],
    ["duration", "120"],
    ["published_at", "{unix_timestamp}"],
    ["thumbnail_ipfs", "{thumb_CID}"],
    ["gifanim_ipfs", "{gif_CID}"],
    ["dim", "1920x1080"],
    ["imeta", "url /ipfs/{CID}/{filename}", "m video/mp4", "dim 1920x1080"],
    ["x", "{SHA256_hash}"],
    ["info", "{info_CID}"],
    ["upload_chain", "{pubkey_list}"],
    ["t", "Channel-{channel_name}"],
    ["g", "{geohash}"],
    ["location", "{city}, {country}"],
    ["latitude", "{lat}"],
    ["longitude", "{lon}"]
  ],
  "content": "Video description"
}
```

**Implementation**:
```bash
# Duration and dimensions
DURATION=$(ffprobe -v error -show_entries format=duration \
           -of default=noprint_wrappers=1:nokey=1 "$FILE_PATH")
VIDEO_DIMENSIONS=$(ffprobe -v error -select_streams v \
                   -show_entries stream=width,height -of csv=s=x:p=0 "$FILE_PATH")

# Thumbnail at 10% of duration
THUMBNAIL_TIME=$(awk "BEGIN {print int($DURATION * 0.1)}")
ffmpeg -i "$FILE_PATH" -ss "$THUMBNAIL_TIME" -vframes 1 "$THUMBNAIL_PATH"

# Animated GIF at φ ratio (golden ratio)
PROBETIME=$(awk "BEGIN {print int($DURATION * 0.618)}")
ffmpeg -ss "$PROBETIME" -t 1.6 -i "$FILE_PATH" "$GIFANIM_PATH"
```

**Kind Determination**:
- Kind 21 (long-form video): duration > 60 seconds
- Kind 22 (short-form video): duration ≤ 60 seconds

#### 4.1.4 Documents and Text

**No Specialized Extraction**: Uses only base NIP-94 tags (url, m, x, info, title)

### 4.2 info.json Structure

All files generate a comprehensive `info.json` file stored on IPFS. **The JSON is canonicalized according to RFC 8785 (JCS) before IPFS upload** to ensure deterministic CID generation and signature consistency.

**Version History**:
- **v1.0.0**: Initial format (snake_case, flat structure)
- **v2.0.0**: Standardized format (camelCase, nested structure, `source` section) - See [INFO_JSON_FORMATS.md](INFO_JSON_FORMATS.md)

**Example (v2.0 format)**:

```json
{
  "protocol": {
    "name": "UPlanet File Management Contract",
    "version": "2.0.0",
    "specification": "https://github.com/papiche/Astroport.ONE/blob/main/Astroport.ONE/docs/UPlanet_FILE_CONTRACT.md"
  },
  "file": {
    "name": "filename.ext",
    "size": 1234567,
    "type": "mime/type",
    "hash": "sha256_hexdigest"
  },
  "ipfs": {
    "cid": "QmXXX...",
    "url": "/ipfs/QmXXX.../filename.ext",
    "gateway": "https://ipfs.copylaradio.com",
    "date": "2025-11-14T12:34:56Z",
    "node_id": "IPNS_address_or_node_identifier"
  },
  "image": {
    "dimensions": "1920x1080"
  },
  "media": {
    "type": "video",
    "duration": 180,
    "dimensions": {
      "width": 1920,
      "height": 1080,
      "aspectRatio": "16:9"
    },
    "codecs": {
      "video": "h264",
      "audio": "aac"
    },
    "thumbnails": {
      "static": "QmTHUMB...",
      "animated": "QmGIF..."
    }
  },
  "source": {
    "type": "youtube",
    "youtube": {
      "id": "video_id",
      "title": "Video Title",
      "channel": {
        "name": "Channel Name",
        "id": "channel_id"
      }
    }
  },
  "provenance": {
    "originalEventId": "evt_abc123...",
    "originalAuthor": "hex_pubkey",
    "uploadChain": [
      {"pubkey": "hex1", "timestamp": "2025-01-01T12:00:00Z"},
      {"pubkey": "hex2", "timestamp": "2025-01-02T14:30:00Z"}
    ],
    "isReupload": true
  },
  "metadata": {
    "description": "Auto-generated or user-provided description",
    "type": "image|audio|video|pdf|text|other",
    "title": "$:/type/CID/filename"
  },
  "nostr": {
    "nip94_tags": [
      ["url", "..."],
      ["m", "..."],
      ["x", "..."]
    ]
  }
}
```

**Key Improvements in v2.0**:
- **camelCase naming**: Consistent with JavaScript conventions
- **Nested structures**: `dimensions` as object, `codecs` object, `thumbnails` object
- **Source section**: Separate `source.youtube` or `source.tmdb` for attribution
- **ISO 8601 dates**: Standard timestamp format
- **Backward compatibility**: Clients support both v1.0 and v2.0

**Protocol Versioning**:
- **Version Format**: Semantic versioning (MAJOR.MINOR.PATCH)
- **MAJOR**: Breaking changes to structure (incompatible)
- **MINOR**: New fields added (backward compatible)
- **PATCH**: Bug fixes and corrections
- **Current Version**: 2.0.0
- **Previous Version**: 1.0.0 (still supported by clients)

**JSON Canonicalization (RFC 8785)**:
- All `info.json` files are canonicalized before IPFS upload
- Ensures deterministic CID generation (same content → same CID)
- Critical for signature verification and provenance tracking
- Implementation: `canonicalize_json.py` script (RFC 8785 JCS compliant)

**IPFS Section Fields**:
- **`cid`**: IPFS Content Identifier (hash of file content)
- **`url`**: IPFS path to access the file (`/ipfs/{CID}/{filename}`)
- **`date`**: Upload timestamp in local timezone format
- **`node_id`**: (Optional) IPNS address or node identifier of the IPFS node where the file was uploaded. This identifies the specific Astroport station or IPFS node that handled the upload, useful for tracking file distribution across the network.

**Purpose of info.json**:
1. **Complete Metadata Archive**: Single source of truth for all file metadata
2. **Provenance Documentation**: Preserves upload history
3. **Interoperability**: JSON format enables cross-platform parsing
4. **Redundancy**: Metadata survives even if NOSTR events are lost
5. **Node Tracking**: Records which IPFS node handled the upload for network analysis

---

## 5. Provenance Tracking Mechanism

### 5.1 Theoretical Foundation

Provenance tracking in UPlanet is based on:

1. **Content-Addressing**: IPFS CID = Hash(file_content)
   - Identical files → Identical CID
   - Enables deduplication and integrity verification

2. **Cryptographic Identity**: NOSTR public keys
   - Each upload associated with unique public key
   - Non-repudiation: Cannot deny authorship

3. **Append-Only Chain**: Upload chain structure with timestamps
   - New uploads append to existing chain with current timestamp
   - Maintains complete custody history with temporal information
   - Format: Array of objects `[{"pubkey": "hex", "timestamp": "ISO8601"}]` in info.json
   - Backward compatibility: Comma-separated string in Nostr tags for older clients

### 5.2 Hash-Based Lookup Algorithm

**Input**: File uploaded by User B
**Output**: Existing event from User A (if file previously uploaded)

```python
def find_existing_event(file_path: str, user_hex: str) -> Optional[Event]:
    # 1. Calculate file hash
    file_hash = sha256(read_file(file_path)).hexdigest()
    
    # 2. Query NOSTR for events with matching hash
    if is_video(file_path):
        events = nostr_query(kind=[21, 22], limit=1000)
    else:
        events = nostr_query(kind=1063, limit=1000)
    
    # 3. Filter by 'x' tag (file hash)
    for event in events:
        if event.has_tag('x', file_hash):
            return event
    
    return None
```

**Complexity**: O(n) where n = number of events in relay
**Optimization**: Index NOSTR events by hash for O(1) lookup

### 5.3 Chain Extension Algorithm

The upload chain is stored as an array of objects in `info.json` with timestamps for each upload:

```python
from datetime import datetime
from typing import List, Dict, Optional

def extend_upload_chain(
    existing_chain: Optional[List[Dict[str, str]]], 
    new_uploader: str,
    current_timestamp: str = None
) -> List[Dict[str, str]]:
    """
    Extend upload chain with new uploader and timestamp.
    
    Args:
        existing_chain: Existing chain array or None
        new_uploader: Hex public key of new uploader
        current_timestamp: ISO 8601 timestamp (defaults to current time)
    
    Returns:
        Updated chain array with new entry
    """
    if current_timestamp is None:
        current_timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    
    # Initialize chain if empty
    if existing_chain is None:
        existing_chain = []
    
    # Check if uploader already in chain
    existing_pubkeys = [entry["pubkey"] for entry in existing_chain]
    
    if new_uploader not in existing_pubkeys:
        # Append new entry with timestamp
        existing_chain.append({
            "pubkey": new_uploader,
            "timestamp": current_timestamp
        })
    
    return existing_chain

# Example usage:
chain = [
    {"pubkey": "hex_A", "timestamp": "2025-01-01T10:00:00Z"}
]
chain = extend_upload_chain(chain, "hex_B", "2025-01-02T14:30:00Z")
# Result: [
#   {"pubkey": "hex_A", "timestamp": "2025-01-01T10:00:00Z"},
#   {"pubkey": "hex_B", "timestamp": "2025-01-02T14:30:00Z"}
# ]
```

**Backward Compatibility**:
- Nostr tags still use comma-separated string format: `["upload_chain", "hex1,hex2,hex3"]`
- `info.json` uses array format with timestamps for richer metadata
- Old string chains are automatically converted to array format when processing

### 5.4 Provenance Visualization

**Example: File uploaded by 3 users**

```
┌─────────────────────────────────────────────────────────────┐
│                    Upload Timeline                           │
└─────────────────────────────────────────────────────────────┘

    User A           User B           User C
      │                │                │
      ▼                ▼                ▼
  2024-01-01       2024-01-15       2024-02-01
  Upload file      Re-upload        Re-upload
  (first)          (same hash)      (same hash)
      │                │                │
      │                │                │
      └────────┬───────┴────────┬───────┘
               │                │
               ▼                ▼
         upload_chain: "hex_A,hex_B,hex_C"
```

**NOSTR Event Evolution**:

```json
// Event 1 (User A)
{
  "id": "evt_001",
  "pubkey": "hex_A",
  "tags": [
    ["x", "file_hash_123"],
    ["upload_chain", "hex_A"]
  ]
}

// No Event 2 (User B re-upload)
// Instead: info.json updated with extended chain

// No Event 3 (User C re-upload)
// Instead: info.json updated with extended chain

// Final info.json
{
  "provenance": {
    "original_event_id": "evt_001",
    "original_author": "hex_A",
    "upload_chain": [
      {"pubkey": "hex_A", "timestamp": "2025-01-01T10:00:00Z"},
      {"pubkey": "hex_B", "timestamp": "2025-01-02T14:30:00Z"},
      {"pubkey": "hex_C", "timestamp": "2025-01-03T09:15:00Z"}
    ],
    "is_reupload": true
  }
}
```

**Benefits**:
- **Space Efficiency**: No duplicate NOSTR events
- **IPFS Efficiency**: No duplicate file storage
- **Audit Trail**: Complete custody history
- **Attribution**: Original author always credited

---

## 6. Security Considerations

### 6.1 Authentication and Authorization

**Authentication Mechanism**: NOSTR NIP-42 (Event-Based Auth)

```python
async def verify_nostr_auth(npub: str) -> bool:
    # 1. Convert npub to hex
    hex_pubkey = npub_to_hex(npub)
    
    # 2. Verify secret file exists
    secret_file = find_secret_file(hex_pubkey)
    if not secret_file.exists():
        return False
    
    # 3. Verify NIP-42 challenge-response (optional)
    # ...
    
    return True
```

**Authorization**: User directory isolation
- Each user's files stored in: `~/.zen/game/players/{SECTOR}/{EMAIL}/`
- No cross-user file access
- Directory permissions enforced by OS

### 6.2 Input Validation

**File Size Limits**: Dynamic limits based on user authentication status

The system implements tiered file size limits aligned with NIP-96 Discovery:

- **MULTIPASS users** (recognized by UPlanet): **650 MB** (681574400 bytes)
- **Other NOSTR users**: **100 MB** (104857600 bytes)

**Implementation**:
```python
def get_max_file_size_for_user(npub: str) -> int:
    """
    Get the maximum file size limit for a user.
    MULTIPASS users: 650MB, Other users: 100MB
    """
    hex_pubkey = npub_to_hex(npub) if npub else None
    if hex_pubkey and is_multipass_user(hex_pubkey):
        return 681574400  # 650MB (aligned with NIP-96 Discovery)
    else:
        return 104857600  # 100MB (default per UPlanet_FILE_CONTRACT.md)

# Validation in /api/fileupload and /api/upload
max_size_bytes = get_max_file_size_for_user(npub)
if file.size and file.size > max_size_bytes:
    raise HTTPException(413, f"File size exceeds maximum allowed size ({max_size_bytes // 1048576}MB)")
```

**MULTIPASS Detection**: Uses `search_for_this_hex_in_uplanet.sh` to verify if a user's hex public key is registered in UPlanet's user database. This enables higher quotas for trusted users.

**Note**: The 650MB limit for MULTIPASS users is aligned with the NIP-96 Discovery endpoint (`/.well-known/nostr/nip96.json`) which advertises the same limits to NOSTR clients.

**MIME Type Validation**: Magic byte inspection
```python
def detect_file_type(content: bytes, filename: str) -> str:
    # Use python-magic or similar
    mime_type = magic.from_buffer(content, mime=True)
    return mime_type
```

**Filename Sanitization**: Prevent path traversal
```python
def sanitize_filename(filename: str) -> str:
    # Remove path separators
    filename = filename.replace('/', '_').replace('\\', '_')
    # Remove null bytes
    filename = filename.replace('\x00', '')
    # Limit length
    return filename[:255]
```

### 6.3 Double Protection Against Misclassification

**Layer 1**: Python backend (54321.py)
```python
if not file_mime.startswith('video/') and not file_mime.startswith('audio/') and not is_reupload:
    # Publish non-video, non-audio files (kind 1063)
    publish_nostr_file.sh --auto ...
```

**Layer 2**: Bash script (publish_nostr_file.sh)
```bash
if [[ "$MIME_TYPE" == "video/"* ]]; then
    # Delegate to video-specific script
    exec publish_nostr_video.sh ...
fi
```

**Result**: 
- Videos can never be published as NIP-94 (kind 1063) by mistake
- Audio files can never be published as NIP-94 (kind 1063) by mistake - they must use NIP-A0 (kinds 1222/1244) via `/vocals` endpoint

### 6.4 Rate Limiting

**Implementation**: Token bucket algorithm
```python
class RateLimiter:
    def __init__(self):
        self.requests_per_minute = 60
        self.requests_per_hour = 1000
        self.cleanup_interval = 300  # 5 minutes
```

**Trusted IPs**: Exemption for local and trusted networks
```python
TRUSTED_NETWORKS = [
    "127.0.0.0/8",    # Localhost
    "10.0.0.0/8",     # Private network
    "172.16.0.0/12",  # Private network
    "192.168.0.0/16"  # Private network
]
```

### 6.5 Data Integrity

**SHA256 Hashing**: Cryptographic verification
```bash
FILE_HASH=$(sha256sum "$FILE_PATH" | awk '{print $1}')
```

**IPFS Content Addressing**: Integrity by design
- CID = Hash(content)
- Tampering → Different CID
- Self-verifying content

**JSON Canonicalization (RFC 8785)**: Deterministic serialization
- All JSON metadata (info.json, NOSTR event content) is canonicalized before signing
- Ensures same logical data always produces same string representation
- Critical for signature consistency and CID determinism
- Implementation: `canonicalize_json.py` (RFC 8785 JCS compliant)
```python
def canonicalize_json(data: Any) -> str:
    return json.dumps(
        data,
        sort_keys=True,           # Lexicographic key ordering
        separators=(',', ':'),   # No whitespace (compact)
        ensure_ascii=False,      # Preserve Unicode
        allow_nan=False          # Reject NaN/Infinity
    )
```

**NOSTR Event Signatures**: Non-repudiation
```json
{
  "id": "event_hash",
  "pubkey": "author_public_key",
  "sig": "schnorr_signature"
}
```

**Protocol Versioning**: Compatibility tracking
- All `info.json` files include protocol version (currently 1.0.0)
- Enables version-aware parsing and migration
- Specification URL included for reference

---

## 7. Implementation Details

### 7.1 Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Backend | Python 3.x + FastAPI | REST API, request handling |
| Storage | IPFS (go-ipfs/kubo) | Decentralized file storage |
| Metadata | NOSTR + strfry relay | Event publishing and retrieval |
| Media Processing | ffmpeg, ffprobe | Video/audio metadata extraction |
| Image Processing | ImageMagick | Image metadata and thumbnail generation |
| Data Format | JSON | Metadata serialization |
| Authentication | NOSTR NIP-42 | Cryptographic identity |

### 7.2 Script Architecture

#### 7.2.1 upload2ipfs.sh

**Responsibilities**:
1. Upload file to IPFS
2. Extract type-specific metadata
3. Generate thumbnails/GIFs (if applicable)
4. Check provenance (existing uploads)
5. Generate info.json with protocol version (1.0.0)
6. **Canonicalize info.json** according to RFC 8785 (JCS) before IPFS upload
7. Return JSON output

**JSON Canonicalization**:
- Uses `canonicalize_json.py` script to ensure RFC 8785 compliance
- Ensures deterministic CID generation (same content → same CID)
- Critical for signature verification and provenance tracking

**Interface**:
```bash
Usage: upload2ipfs.sh <file_path> <output_json> [user_hex]

Arguments:
  file_path    : Path to file for upload
  output_json  : Path for JSON output
  user_hex     : (Optional) User's hex public key for provenance

Output: JSON file with structure:
{
  "cid": "QmXXX...",
  "mimeType": "image/png",
  "fileHash": "sha256_hash",
  "dimensions": "1920x1080",
  "thumbnail_ipfs": "QmTHUMB...",
  "duration": 180,
  "info": "QmINFO...",
  "upload_chain": "hex1,hex2",
  "provenance": {
    "is_reupload": true,
    "original_event_id": "evt_abc",
    "original_author": "hex1"
  }
}
```

**Note**: The `info.json` file (referenced by `info` CID) is:
- Canonicalized according to RFC 8785 (JCS) before IPFS upload
- Includes protocol version (1.0.0) for compatibility tracking
- Ensures deterministic CID generation for signature verification

#### 7.2.2 publish_nostr_file.sh

**Responsibilities**:
1. Parse upload2ipfs.sh JSON output (--auto mode)
2. Detect MIME type
3. Delegate to publish_nostr_video.sh if video
4. Build NIP-94 tags for non-video files
5. Call nostr_send_note.py
6. Return JSON with event ID

**Interface**:
```bash
Usage: publish_nostr_file.sh [OPTIONS]

Options:
  --auto <json_file>       : Read metadata from upload2ipfs.sh output
  --nsec <key_or_file>     : NOSTR secret key or file path
  --ipfs-cid <cid>         : IPFS Content Identifier
  --filename <name>        : Original filename
  --mime-type <type>       : MIME type
  --file-hash <hash>       : SHA256 hash
  --info-cid <cid>         : info.json CID
  --upload-chain <chain>   : Comma-separated pubkey list
  --title <title>          : File title
  --description <desc>     : File description
  --json                   : Output JSON format

Output (with --json):
{
  "event_id": "evt_abc123...",
  "kind": 1063,
  "relays_success": 2,
  "relays_total": 2
}
```

#### 7.2.3 publish_nostr_video.sh

**Responsibilities**:
1. Parse video-specific metadata
2. Build NIP-71 tags
3. Determine kind (21 vs 22) based on duration
4. Add geolocation tags
5. Call nostr_send_note.py
6. Return JSON with event ID

**Interface**:
```bash
Usage: publish_nostr_video.sh [OPTIONS]

Options:
  --auto <json_file>       : Read metadata from upload2ipfs.sh output
  --nsec <key_or_file>     : NOSTR secret key or file path
  --ipfs-cid <cid>         : Video IPFS CID
  --filename <name>        : Video filename
  --title <title>          : Video title
  --description <desc>     : Video description
  --thumbnail-cid <cid>    : Thumbnail IPFS CID
  --gifanim-cid <cid>      : Animated GIF IPFS CID
  --info-cid <cid>         : info.json CID
  --file-hash <hash>       : SHA256 hash
  --mime-type <type>       : MIME type
  --upload-chain <chain>   : Provenance chain
  --duration <seconds>     : Video duration
  --dimensions <WxH>       : Video dimensions
  --latitude <lat>         : Geographic latitude
  --longitude <lon>        : Geographic longitude
  --channel <name>         : Channel name
  --json                   : Output JSON format
```

### 7.3 FastAPI Endpoints

#### 7.3.1 POST /api/fileupload

**Purpose**: Upload any file to IPFS and optionally publish metadata to NOSTR

**Note**: 
- **Video files** (`video/*`): Upload only, publication deferred to `/webcam` endpoint (kinds 21/22)
- **Audio files** (`audio/*`): Upload only, publication deferred to `/vocals` endpoint (kinds 1222/1244)
- **Other files** (`image/*`, `application/*`, `text/*`): Upload and immediate publication (kind 1063)

**Authentication**: NIP-42 (required, `force_check=True`)

**File Size Limits**:
- MULTIPASS users: 650MB (681574400 bytes)
- Other NOSTR users: 100MB (104857600 bytes)

**Request**:
```http
POST /api/fileupload HTTP/1.1
Content-Type: multipart/form-data

file: <binary_data>
npub: npub1abc123...
youtube_metadata: <optional_json_file>
```

**Validation**:
1. **File Size**: Validated before file content is read (prevents DoS)
2. **MIME Type**: Magic byte inspection for content safety
3. **File Content**: Signature verification for critical file types
4. **MULTIPASS Detection**: Automatic quota assignment based on user status

**Response** (Success):
```json
{
  "success": true,
  "message": "File uploaded successfully to IPFS",
  "file_path": "/path/to/file",
  "file_type": "image",
  "target_directory": "/user/directory",
  "new_cid": "QmXXX...",
  "timestamp": "2024-01-01T12:00:00",
  "auth_verified": true,
  "fileName": "image.png",
  "description": "AI-generated description",
  "info": "QmINFO...",
  "thumbnail_ipfs": "QmTHUMB...",
  "gifanim_ipfs": null
}
```

**Response** (Video - Deferred NOSTR Publication):
```json
{
  "success": true,
  "message": "File uploaded successfully to IPFS",
  "new_cid": "QmVIDEO...",
  "thumbnail_ipfs": "QmTHUMB...",
  "gifanim_ipfs": "QmGIF...",
  "info": "QmINFO..."
}
```
(Log: "📹 Video file - kind 21/22 will be published by /webcam endpoint")

**Response** (Audio - Deferred NOSTR Publication):
```json
{
  "success": true,
  "message": "File uploaded successfully to IPFS",
  "new_cid": "QmAUDIO...",
  "info": "QmINFO...",
  "duration": 45
}
```
(Log: "🎤 Audio file - kind 1222/1244 will be published by /vocals endpoint")

#### 7.3.2 POST /webcam

**Purpose**: Publish video metadata to NOSTR with user-provided information

**Request**:
```http
POST /webcam HTTP/1.1
Content-Type: application/x-www-form-urlencoded

player=user@example.com
ipfs_cid=QmVIDEO...
thumbnail_ipfs=QmTHUMB...
gifanim_ipfs=QmGIF...
info_cid=QmINFO...
file_hash=sha256_hash
mime_type=video/mp4
upload_chain=hex1,hex2
duration=120
video_dimensions=1920x1080
title=My Video
description=Video description
npub=npub1abc123...
publish_nostr=true
latitude=48.8566
longitude=2.3522
```

**Response** (Success):
```http
HTTP/1.1 200 OK
Content-Type: text/html

<html>
  <body>
    ✅ NOSTR video event (kind 21) published: evt_abc123...
    📡 Published to 2/2 relay(s)
  </body>
</html>
```

#### 7.3.3 POST /vocals

**Purpose**: Publish voice message metadata to NOSTR with user-provided information (NIP-A0)

**Request**:
```http
POST /vocals HTTP/1.1
Content-Type: application/x-www-form-urlencoded

player=user@example.com
ipfs_cid=QmAUDIO...
info_cid=QmINFO...
file_hash=sha256_hash
mime_type=audio/webm
file_name=voice_1234567890.mp3
duration=45
title=My Voice Message
description=Voice message description
npub=npub1abc123...
publish_nostr=true
encrypted=false
encryption_method=nip44
recipients=[]
latitude=48.8566
longitude=2.3522
expiration=1735689600
```

**Response** (Success):
```http
HTTP/1.1 200 OK
Content-Type: text/html

<html>
  <body>
    ✅ NOSTR voice message (kind 1222) published: evt_abc123...
    📡 Published to 2/2 relay(s)
  </body>
</html>
```

**Note**: 
- Kind 1222 for root messages, kind 1244 for replies (when `e` and `p` tags are provided)
- Supports end-to-end encryption via NIP-44 (recommended) or NIP-04 (legacy)
- Optional expiration timestamp (NIP-40) for automatic relay deletion

### 7.4 Configuration

**Environment Variables**:
```bash
# IPFS Gateway
myIPFS="http://127.0.0.1:8080"

# NOSTR Relay
NOSTR_RELAY="ws://127.0.0.1:7777"

# User Data Directory
ZEN_DIR="${HOME}/.zen"

# Scripts Directory
ASTROPORT_DIR="${HOME}/.zen/Astroport.ONE"
```

**NOSTR Relays** (publish_nostr_*.sh):
```bash
RELAYS="ws://127.0.0.1:7777,wss://relay.copylaradio.com"
```

---

## 8. Administrative Tools

### 8.1 NostrTube Manager (nostr_tube_manager.sh)

The NostrTube Manager is a comprehensive command-line tool for monitoring, administering, and upgrading video channels published via the UPlanet File Management Contract.

#### 8.1.1 Overview

**Purpose**: Centralized management interface for NOSTR video events (kinds 21/22) stored in the local strfry relay.

**Key Features**:
- Multi-channel video browsing and administration
- Metadata completeness verification
- Video upgrade mechanism (regenerate missing metadata)
- Provenance chain visualization
- Interactive terminal UI with pagination
- Safe event deletion with strfry integration
- Channel statistics and analytics

#### 8.1.2 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   nostr_tube_manager.sh                      │
│                  (Bash CLI Application)                       │
└───────┬─────────────────────────────────────┬───────────────┘
        │                                     │
        ▼                                     ▼
┌───────────────────┐              ┌──────────────────────┐
│ nostr_get_events  │              │  upload2ipfs.sh      │
│  (Query relay)    │              │  (Regenerate meta)   │
└────────┬──────────┘              └──────────┬───────────┘
         │                                    │
         ▼                                    ▼
┌────────────────────┐             ┌─────────────────────┐
│  strfry relay      │             │ publish_nostr_video │
│  (Local NOSTR DB)  │             │  (Republish events) │
└────────────────────┘             └─────────────────────┘
```

#### 8.1.3 Command Reference

**Core Commands**:

| Command | Description | User Authentication Required |
|---------|-------------|------------------------------|
| `list-all` | List all videos from all channels | No |
| `browse` | Interactive channel and video browser | No |
| `list` | List videos for specific user | Yes |
| `channel` | Interactive channel administration | Yes |
| `check` | Verify metadata completeness | Yes |
| `stats` | Show channel statistics | Yes |
| `upgrade` | Upgrade single video | Yes |
| `upgrade-all` | Upgrade all videos with missing metadata | Yes |

**User Identification Options**:
- `--npub <npub>`: NOSTR public key (npub format)
- `--hex <hex>`: NOSTR public key (hexadecimal)
- `--email <email>`: User email (resolves to hex via file system lookup)

**Example Usage**:

```bash
# Browse all channels interactively (no auth required)
nostr_tube_manager.sh browse

# List all videos globally
nostr_tube_manager.sh list-all

# Manage specific user's channel
nostr_tube_manager.sh channel --email user@example.com

# Check metadata completeness
nostr_tube_manager.sh check --npub npub1abc...

# Upgrade specific video (regenerate metadata)
nostr_tube_manager.sh upgrade --event-id evt123... --hex abc123...

# Upgrade all videos missing metadata
nostr_tube_manager.sh upgrade-all --hex abc123... --force
```

#### 8.1.4 Video Upgrade Mechanism

The upgrade process addresses incomplete metadata (missing `gifanim_ipfs`, `thumbnail_ipfs`, or `info`) by re-processing videos through the complete pipeline.

**Upgrade Algorithm**:

```
┌─────────────────────────────────────────────────────────────┐
│ UPGRADE WORKFLOW                                             │
└─────────────────────────────────────────────────────────────┘

1. Query Event
   ├─ Fetch event from relay by ID
   ├─ Extract: title, description, CID, location
   └─ Verify: event exists and belongs to user

2. Download Video
   ├─ ipfs get <CID>/<filename>
   ├─ Save to: ~/.zen/tmp/nostr_tube_$$/
   └─ Verify: download successful

3. Regenerate Metadata
   ├─ Execute: upload2ipfs.sh <video_path> <output_json> <user_hex>
   ├─ Generates:
   │  ├─ Thumbnail (JPG @ 10% duration)
   │  ├─ Animated GIF (1.6s @ φ ratio)
   │  ├─ info.json (complete metadata)
   │  └─ Upload chain (provenance)
   └─ Returns: JSON with all CIDs

4. Delete Old Event
   ├─ Build filter: {"ids": ["<event_id>"]}
   ├─ Execute: strfry delete --filter='<json>'
   └─ Verify: deletion successful

5. Publish New Event
   ├─ Locate user's .secret.nostr file
   ├─ Execute: publish_nostr_video.sh --auto <json> --nsec <secret>
   ├─ Preserves: title, description, location
   ├─ Adds: fresh metadata (thumb, GIF, info)
   └─ Returns: new event ID

6. Cleanup
   └─ Remove: ~/.zen/tmp/nostr_tube_$$/

```

**Safety Features**:
- **Confirmation Prompts**: User must confirm before deletion (unless `--force`)
- **Atomic Deletion**: Uses event ID filter (no wildcards)
- **Metadata Preservation**: Original title, description, geolocation retained
- **Error Handling**: If republication fails, manual intervention instructions provided

**Implementation** (simplified):

```bash
cmd_upgrade() {
    local event_id="$1"
    local user_hex="$2"
    
    # 1. Fetch event
    local event=$(bash "$NOSTR_GET_EVENTS" --kind 21 --author "$user_hex" \
                  | jq "select(.id == \"$event_id\")")
    
    # 2. Download video from IPFS
    local cid=$(echo "$event" | jq -r '.tags[] | select(.[0] == "url") | .[1]' \
                | grep -oP '(?<=ipfs/)[^/]+')
    ipfs get "$cid/$filename" -o "$video_path"
    
    # 3. Regenerate metadata
    bash "$UPLOAD2IPFS" "$video_path" "$upload_output" "$user_hex"
    
    # 4. Delete old event safely
    delete_event_by_id "$event_id" "true"
    
    # 5. Publish new event with fresh metadata
    bash "$PUBLISH_NOSTR_VIDEO" --auto "$upload_output" \
         --nsec "$secret_file" --title "$title" --json
    
    # 6. Cleanup temp files
    rm -rf "$TEMP_DIR"
}
```

#### 8.1.5 Interactive Browse Mode

The browse mode provides a multi-level navigation interface:

**Level 1: Channel Selection**
```
╔════════════════════════════════════════════════════════════╗
║                    Select a Channel                         ║
╚════════════════════════════════════════════════════════════╝

  1. 📺 alice@example.com (12 videos)
  2. 📺 bob@example.com (5 videos)
  3. 📺 charlie@example.com (8 videos)
  
  0. 🚪 Exit

Select channel [0-3]:
```

**Level 2: Video List (Paginated)**
```
╔════════════════════════════════════════════════════════════╗
║                Channel: alice@example.com                   ║
╚════════════════════════════════════════════════════════════╝

Page 1/3 - 12 videos total

  1. 📹 Introduction to Decentralized Systems
      ⏱️  120s | 📅 2024-01-15 10:30 | Kind 21 | Status: ✅✅✅
      
  2. 📹 IPFS Deep Dive
      ⏱️  95s | 📅 2024-01-20 14:15 | Kind 21 | Status: ❌✅✅
      
  (... 3 more videos ...)

─────────────────────────────────────────────────────────────

  1-5. 🔍 View video details
  n. ➡️  Next page
  b. 🔙 Back to channels
  0. 🚪 Exit

Choose action:
```

**Level 3: Video Details**
```
╔════════════════════════════════════════════════════════════╗
║                       Video Details                         ║
╚════════════════════════════════════════════════════════════╝

📹 Title: Introduction to Decentralized Systems
🆔 Event ID: evt_a1b2c3d4e5f6...
👤 Author: abc123def456...
📅 Date: 2024-01-15 10:30:45
⏱️  Duration: 120s
📐 Dimensions: 1920x1080
🎬 Kind: 21

📝 Description:
  This video introduces core concepts of decentralized systems,
  covering IPFS, NOSTR, and content-addressing principles.

╔════════════════════════════════════════════════════════════╗
║                        IPFS Links                           ║
╚════════════════════════════════════════════════════════════╝

📹 Video File:
   CID: QmVIDEO123abc...
   URL: http://127.0.0.1:8080/ipfs/QmVIDEO123abc.../video.mp4

🖼️  Thumbnail:
   CID: QmTHUMB456def...
   URL: http://127.0.0.1:8080/ipfs/QmTHUMB456def...

🎬 Animated GIF:
   CID: QmGIF789ghi...
   URL: http://127.0.0.1:8080/ipfs/QmGIF789ghi...

📋 Info.json:
   CID: QmINFO012jkl...
   URL: http://127.0.0.1:8080/ipfs/QmINFO012jkl...

🔐 File Hash (SHA256):
   a1b2c3d4e5f6789012345678901234567890abcdef...

🔗 Upload Chain (Provenance):
   abc123def456...,xyz789abc012...

─────────────────────────────────────────────────────────────

  1. 🔄 Upgrade video (re-generate metadata)
  2. 📋 Copy video URL to clipboard
  3. 🖼️  Open thumbnail in browser
  4. 🎬 Open animated GIF in browser
  5. 📊 View info.json
  6. 🗑️  Delete this video
  b. 🔙 Back to video list
  0. 🚪 Exit

Choose action:
```

#### 8.1.6 Statistics and Analytics

The `stats` command provides comprehensive channel metrics:

```bash
$ nostr_tube_manager.sh stats --hex abc123...

╔════════════════════════════════════════════════════════════╗
║                    NostrTube Statistics                     ║
╚════════════════════════════════════════════════════════════╝

📊 Video Count
  Total videos: 25
  Regular videos (kind 21): 18
  Short videos (kind 22): 7

⏱️  Total Duration
  2h 45m 30s (9930 seconds)

📋 Metadata Completeness
  Animated GIF: 20/25 (80%)
  Thumbnail: 25/25 (100%)
  Info.json: 23/25 (92%)

💡 Recommendations
  5 videos are missing metadata
  Run: nostr_tube_manager.sh upgrade-all --hex abc123...
```

#### 8.1.7 Integration with Core Pipeline

The NostrTube Manager integrates seamlessly with the core upload pipeline:

**Dependency Graph**:
```
upload2ipfs.sh ────────┬────> IPFS (storage)
                       │
                       ├────> info.json generation
                       │
                       └────> Provenance check (NOSTR query)

publish_nostr_video.sh ─────> NOSTR relay (event publication)

nostr_get_events.sh ────────> NOSTR relay (event retrieval)

nostr_tube_manager.sh ──┬───> All above scripts (orchestration)
                        │
                        └───> strfry (direct deletion)
```

**Workflow Harmony**:
1. **Upload Phase** (`/api/fileupload` → `upload2ipfs.sh`): Generates metadata
2. **Publish Phase** (`/webcam` → `publish_nostr_video.sh`): Creates event
3. **Admin Phase** (`nostr_tube_manager.sh`): Monitors, upgrades, manages
4. **Upgrade Phase** (`nostr_tube_manager.sh upgrade`): Full re-processing loop

#### 8.1.8 Security Considerations

**User Authentication**:
- Resolves user identity via multiple methods (npub, hex, email)
- Verifies `.secret.nostr` file ownership before operations
- No cross-user access (user isolation enforced)

**Event Deletion Safety**:
- Uses precise event ID filter (no wildcards)
- Requires confirmation unless `--force` flag
- Operates directly on strfry database (bypasses relay API)

**File System Isolation**:
- Temporary files in `~/.zen/tmp/nostr_tube_$$/` (unique per process)
- Automatic cleanup via `trap` on exit
- No persistent temporary data

#### 8.1.9 Use Case: Metadata Repair

**Scenario**: A video was uploaded before the animated GIF feature was implemented. The channel admin wants to add the missing GIF without re-uploading.

**Solution**:

```bash
# Step 1: Identify videos with missing metadata
nostr_tube_manager.sh check --email admin@channel.com

# Output shows:
# ❌ Missing animated GIF: 3 videos

# Step 2: Upgrade all videos automatically
nostr_tube_manager.sh upgrade-all --email admin@channel.com --force

# Process:
# - Downloads each video from IPFS
# - Re-runs upload2ipfs.sh (generates GIF, thumbnail, info)
# - Deletes old event
# - Publishes new event with complete metadata

# Result: All 3 videos now have animated GIFs
```

**Technical Flow**:
```
Old Event (missing GIF)          Upgraded Event (complete)
┌────────────────────┐          ┌────────────────────────┐
│ kind: 21           │          │ kind: 21               │
│ title: "Video"     │   ───>   │ title: "Video"         │
│ url: QmVIDEO...    │          │ url: QmVIDEO...        │
│ thumbnail_ipfs: Qm │          │ thumbnail_ipfs: Qm...  │
│ gifanim_ipfs: ❌   │          │ gifanim_ipfs: QmGIF... │✅
│ info: QmINFO1...   │          │ info: QmINFO2...       │
└────────────────────┘          └────────────────────────┘
```

#### 8.1.10 Performance Characteristics

**Query Performance**:
- List 100 videos: ~0.5s (local relay)
- List 1000 videos: ~2s (local relay)
- Browse interactive: < 0.1s per page (cached in memory)

**Upgrade Performance** (50 MB video):
- Download from IPFS: ~6s
- Metadata regeneration: ~3s (thumbnail + GIF + info)
- Event deletion: < 0.1s
- Event publication: ~0.2s
- **Total**: ~10s per video

**Bulk Operations**:
- Upgrade 10 videos: ~120s (includes 2s delay between uploads)
- Upgrade 100 videos: ~1200s (~20 minutes)

---

## 9. Use Cases and Examples

### 9.1 Academic Use Case: Research Data Publication

**Scenario**: Dr. Alice publishes a research dataset with provenance tracking

**Workflow**:

1. **Initial Publication** (Dr. Alice):
```bash
# Upload dataset
curl -X POST http://localhost:54321/api/fileupload \
     -F "file=@research_data.csv" \
     -F "npub=npub1alice..."

# NOSTR event created (kind 1063)
```

2. **Replication** (Dr. Bob):
```bash
# Re-upload same dataset for replication
curl -X POST http://localhost:54321/api/fileupload \
     -F "file=@research_data.csv" \
     -F "npub=npub1bob..."

# No new NOSTR event (provenance tracked)
# upload_chain: "alice_hex,bob_hex"
```

3. **Third-Party Verification** (Dr. Charlie):
```bash
# Verify data integrity
curl -X POST http://localhost:54321/api/fileupload \
     -F "file=@research_data.csv" \
     -F "npub=npub1charlie..."

# upload_chain: "alice_hex,bob_hex,charlie_hex"
```

**Benefits**:
- **Attribution**: Alice credited as original publisher
- **Replication**: Bob and Charlie's participation documented
- **Integrity**: SHA256 ensures data hasn't been modified
- **Decentralization**: No single point of failure

### 9.2 Media Use Case: Citizen Journalism

**Scenario**: Journalist uploads video with geolocation

**Phase 1: Upload and Metadata Generation**:
```bash
curl -X POST http://localhost:54321/api/fileupload \
     -F "file=@protest_footage.mp4" \
     -F "npub=npub1journalist..."

# Response:
{
  "cid": "QmPROTEST...",
  "thumbnail_ipfs": "QmTHUMB...",
  "gifanim_ipfs": "QmGIF...",
  "duration": 180
}
```

**Phase 2: Publication with Context**:
```bash
curl -X POST http://localhost:54321/webcam \
     -F "ipfs_cid=QmPROTEST..." \
     -F "thumbnail_ipfs=QmTHUMB..." \
     -F "gifanim_ipfs=QmGIF..." \
     -F "title=Peaceful Protest Documentation" \
     -F "description=Citizens exercising freedom of assembly" \
     -F "latitude=40.7128" \
     -F "longitude=-74.0060" \
     -F "publish_nostr=true" \
     -F "npub=npub1journalist..."

# NOSTR event (kind 21) with geolocation
```

**Benefits**:
- **Censorship Resistance**: IPFS prevents takedown
- **Verification**: Thumbnail and GIF enable preview
- **Context**: Geolocation tags provide spatial context
- **Immutability**: Content-addressing prevents manipulation

### 9.3 Educational Use Case: Course Materials Distribution

**Scenario**: Professor shares lecture slides

```bash
# Upload PDF slides
curl -X POST http://localhost:54321/api/fileupload \
     -F "file=@lecture_01_slides.pdf" \
     -F "npub=npub1professor..."

# NOSTR event (kind 1063)
{
  "kind": 1063,
  "tags": [
    ["url", "/ipfs/QmSLIDES.../lecture_01_slides.pdf"],
    ["m", "application/pdf"],
    ["x", "file_hash"],
    ["title", "Lecture 1: Introduction to Decentralized Systems"],
    ["info", "QmINFO..."]
  ]
}
```

**Student Access**:
1. Query NOSTR for professor's publications
2. Retrieve file from IPFS gateway
3. Verify integrity via SHA256 hash

**Benefits**:
- **Persistence**: Materials remain accessible indefinitely
- **Verification**: Students can verify file authenticity
- **Distribution**: P2P sharing reduces bandwidth costs

### 9.4 Example: Image with AI Description

**Scenario**: User uploads photo, system generates AI description

```bash
# Upload image
curl -X POST http://localhost:54321/api/fileupload \
     -F "file=@sunset.jpg" \
     -F "npub=npub1user..."

# Backend calls describe_image.py (AI model)
# Generates: "A beautiful orange and pink sunset over a calm ocean with silhouetted palm trees"

# NOSTR event (kind 1063)
{
  "kind": 1063,
  "tags": [
    ["url", "/ipfs/QmSUNSET.../sunset.jpg"],
    ["m", "image/jpeg"],
    ["dim", "4032x3024"],
    ["description", "A beautiful orange and pink sunset..."]
  ],
  "content": "A beautiful orange and pink sunset over a calm ocean with silhouetted palm trees"
}
```

---

## 10. References

### 10.1 Standards and Protocols

1. **IPFS (InterPlanetary File System)**
   - Specification: https://docs.ipfs.tech/concepts/
   - CID Format: https://github.com/multiformats/cid

2. **NOSTR (Notes and Other Stuff Transmitted by Relays)**
   - Protocol: https://github.com/nostr-protocol/nostr
   - NIP-01 (Basic Protocol): https://github.com/nostr-protocol/nips/blob/master/01.md

3. **NIP-94 (File Metadata)**
   - Specification: https://github.com/nostr-protocol/nips/blob/master/94.md
   - Event Kind: 1063

4. **NIP-71 (Video Events)**
   - Specification: https://github.com/nostr-protocol/nips/blob/master/71.md
   - Event Kinds: 21 (long-form), 22 (short-form)

5. **NIP-42 (Authentication)**
   - Specification: https://github.com/nostr-protocol/nips/blob/master/42.md

6. **RFC 8785 (JSON Canonicalization Scheme - JCS)**
   - Specification: https://datatracker.ietf.org/doc/html/rfc8785
   - Purpose: Deterministic JSON serialization for cryptographic signatures
   - Implementation: `canonicalize_json.py` in Astroport.ONE/tools/

### 10.2 Dependencies

- **Python 3.x**: Backend language
- **FastAPI**: Web framework
- **IPFS (go-ipfs/kubo)**: Content storage
- **strfry**: NOSTR relay implementation
- **ffmpeg/ffprobe**: Media processing
- **ImageMagick**: Image processing
- **jq**: JSON processing in bash

### 10.3 Related Work

- **BitTorrent**: P2P file sharing (centralized trackers)
- **Filecoin**: Incentivized decentralized storage (blockchain-based)
- **Arweave**: Permanent data storage (pay-once model)
- **Mastodon**: Federated social media (server-based federation)

**UPlanet's Differentiator**: Combines IPFS (storage) + NOSTR (metadata) with provenance tracking and type-specific metadata extraction.

---

## Appendix A: Decision Matrix

| File Type | MIME Type | Processing Endpoint | Metadata Extraction | NOSTR Kind | Publishing Script |
|-----------|-----------|---------------------|---------------------|------------|-------------------|
| Video | `video/*` | `/api/fileupload` → `/webcam` | Duration, dimensions, thumbnail (JPG), animated GIF, codecs | 21 or 22 | `publish_nostr_video.sh` |
| Audio | `audio/*` | `/api/fileupload` → `/vocals` | Duration, codecs | 1222 or 1244 | Backend (NIP-A0) |
| Image (JPG) | `image/jpeg` | `/api/fileupload` | Dimensions | 1063 | `publish_nostr_file.sh` |
| Image (PNG/GIF/WEBP) | `image/{png,gif,webp}` | `/api/fileupload` | Dimensions, thumbnail (JPG conversion) | 1063 | `publish_nostr_file.sh` |
| PDF | `application/pdf` | `/api/fileupload` | None | 1063 | `publish_nostr_file.sh` |
| Text | `text/*` | `/api/fileupload` | Content preview (optional) | 1063 | `publish_nostr_file.sh` |
| Other | `*/*` | `/api/fileupload` | None | 1063 | `publish_nostr_file.sh` |
| Re-upload | Any | `/api/fileupload` | CID reuse, chain extension | None (skip) | N/A |

---

## Appendix B: Security Threat Model

| Threat | Mitigation | Residual Risk |
|--------|-----------|---------------|
| **File Size DoS** | Tiered quotas (100MB/650MB), validation before content read, rate limiting | Low (dynamic limits, early rejection) |
| **MIME Type Spoofing** | Magic byte inspection | Low (robust detection) |
| **Path Traversal** | Filename sanitization, user directory isolation | Very Low |
| **Unauthorized Access** | NOSTR NIP-42 authentication | Low (key management responsibility) |
| **IPFS Storage Exhaustion** | Unpinning after upload, selective pinning | Medium (manual management) |
| **NOSTR Relay DoS** | Rate limiting, trusted IP whitelist | Medium (relay-dependent) |
| **Content Manipulation** | SHA256 hashing, content-addressing | Very Low (cryptographic security) |
| **Provenance Forgery** | NOSTR event signatures | Very Low (cryptographic security) |

---

## Appendix C: Performance Metrics

### C.1 Upload Performance

**Test Environment**:
- Hardware: Intel i7, 16GB RAM, SSD
- Network: 100 Mbps
- IPFS: Local node

**Results**:

| File Type | File Size | IPFS Upload | Metadata Extraction | Total Time |
|-----------|-----------|-------------|---------------------|------------|
| Image (JPG) | 5 MB | 0.8s | 0.2s | 1.0s |
| Image (PNG) | 8 MB | 1.2s | 0.5s (+ thumbnail) | 1.7s |
| Audio (MP3) | 10 MB | 1.5s | 0.3s | 1.8s |
| Video (MP4) | 50 MB | 6.0s | 2.5s (+ thumb + GIF) | 8.5s |
| PDF | 2 MB | 0.5s | 0.1s | 0.6s |

### C.2 Provenance Lookup Performance

| Relay Size (Events) | Lookup Time | Method |
|---------------------|-------------|--------|
| 1,000 | 0.1s | Linear scan |
| 10,000 | 0.8s | Linear scan |
| 100,000 | 7.5s | Linear scan |
| 100,000 | 0.01s | Hash index (optimized) |

**Recommendation**: Implement hash indexing in NOSTR relay for O(1) provenance lookup.

---

## Appendix D: API Rate Limits and File Size Quotas

### D.1 Rate Limits

**Default Configuration**:

| Endpoint | Limit | Window |
|----------|-------|--------|
| `/api/fileupload` | 60 requests | 1 minute |
| `/api/fileupload` | 1000 requests | 1 hour |
| `/webcam` | 30 requests | 1 minute |

**Trusted Networks**: Exempt from rate limiting
- 127.0.0.0/8 (localhost)
- 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 (private networks)

### D.2 File Size Quotas

**Tiered Quota System** (aligned with NIP-96 Discovery):

| User Type | Max File Size | Detection Method |
|-----------|---------------|------------------|
| MULTIPASS (recognized by UPlanet) | 650 MB (681574400 bytes) | `search_for_this_hex_in_uplanet.sh` |
| Other NOSTR users | 100 MB (104857600 bytes) | Default quota |

**Implementation Details**:
- Quota is determined **before** file content is read (prevents DoS attacks)
- MULTIPASS detection uses UPlanet user database lookup
- Limits are enforced in both `/api/fileupload` and `/api/upload` endpoints
- HTTP 413 (Payload Too Large) is returned when limit is exceeded

**Rationale**:
- **100MB default**: Prevents abuse while allowing reasonable file uploads
- **650MB MULTIPASS**: Enables trusted users (webcam.html, ajouter_media.sh) to upload larger media files
- **Dynamic detection**: No manual configuration required, automatic quota assignment

---

## Acknowledgments

This protocol was developed as part of the UPlanet decentralized ecosystem. Special thanks to the IPFS and NOSTR communities for their foundational work on decentralized storage and communication protocols.

---

## Document Metadata

- **Protocol Version**: 2.0.0
- **Document Version**: 1.3
- **Date**: 2025-01-04
- **Last Updated**: 2025-11-14 (Standardized info.json v2.0 format)
- **Authors**: UPlanet Development Team
- **License**: CC BY-SA 4.0
- **Repository**: https://github.com/papiche/Astroport.ONE

**Changes in v1.3**:
- Upgraded protocol to v2.0.0 with standardized info.json format
- Added camelCase field naming convention
- Introduced nested structures (dimensions, codecs, thumbnails as objects)
- Moved YouTube/TMDB metadata to `source` section
- Added ISO 8601 timestamp format
- Backward compatibility maintained for v1.0 clients
- Reference to INFO_JSON_FORMATS.md for complete specification

**Changes in v1.2**:
- Added tiered file size quota system (100MB default, 650MB for MULTIPASS users)
- Documented MULTIPASS detection mechanism
- Updated security section with file size validation details
- Aligned quotas with NIP-96 Discovery endpoint
- Added validation requirements for `/api/fileupload` endpoint

**Changes in v1.1**:
- Added RFC 8785 (JCS) JSON canonicalization requirement
- Added protocol versioning to info.json structure
- Updated security considerations with canonicalization details

---

**END OF DOCUMENT**

