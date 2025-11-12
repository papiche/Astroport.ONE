# VOCALS System - Enhanced Voice Messages with Encryption

## Overview

The VOCALS (Voice Over Communication And Localization System) is a comprehensive voice messaging system built on NOSTR that enables users to send public or end-to-end encrypted voice messages with optional geolocation. It implements NIP-A0 for voice messages and extends it with encryption capabilities.

**Status:** Production  
**NIPs Used:** [NIP-A0](nostr-nips/A0.md), [NIP-A0 Encryption Extension](nostr-nips/A0-encryption-extension.md), [NIP-44](nostr-nips/44.md), [NIP-04](nostr-nips/04.md), [NIP-42](nostr-nips/42.md), [NIP-92](nostr-nips/92.md), [NIP-22](nostr-nips/22.md), [NIP-101](nostr-nips/101.md), [NIP-40](nostr-nips/40.md)

## Features

- ✅ **Public Voice Messages**: Standard NIP-A0 compatible messages
- ✅ **End-to-End Encryption**: Optional E2EE using NIP-44 (recommended) or NIP-04 (legacy)
- ✅ **Geolocation Support**: Optional UMAP anchoring (NIP-101)
- ✅ **Multiple Recipients**: Support for encrypted messages to multiple recipients
- ✅ **Self-Messaging**: Send encrypted voice messages to yourself (reminders, notes)
- ✅ **Expiration Support**: Optional NIP-40 expiration timestamp (relay auto-deletion)
- ✅ **IPFS Storage**: Decentralized storage via IPFS
- ✅ **Metadata Rich**: Waveform, duration, title, description
- ✅ **Reply Support**: Kind 1244 for threaded voice conversations

## Architecture

### Components

1. **Frontend Interface - Recording** (`/vocals` route, `vocals.html`)
   - Voice recording/upload interface
   - Encryption configuration UI
   - Recipient selection
   - Geolocation picker
   - Preview and publishing

2. **Frontend Interface - Reading** (`/vocals-read` route, `vocals-read.html`)
   - Voice message inbox/reader
   - NOSTR event fetching (kinds 1222/1244)
   - Decryption of encrypted messages (NIP-44/NIP-04)
   - Audio playback
   - Filtering (public, encrypted, sent, received)
   - Profile display for senders

3. **Backend API** (`54321.py`)
   - `/vocals` (GET): Serves the recording interface
   - `/vocals` (POST): Processes and publishes voice messages
   - `/vocals-read` (GET): Serves the reading interface
   - `/api/fileupload`: Handles audio file upload to IPFS
   - `/api/getN2`: Provides contact list for recipient selection

4. **NOSTR Integration**
   - Event publishing (kinds 1222/1244)
   - NIP-42 authentication
   - Profile fetching for contacts
   - Relay communication

4. **IPFS Storage**
   - Audio file storage
   - Metadata storage (info.json)
   - Decentralized content delivery

## User Workflow

### 1. Recording/Uploading Voice Message

**Option A: Record like Webcam Interface**
- User navigates to `/vocals`
- Clicks "Start Recording" (if webcam available)
- Records up to 30 seconds (configurable)
- Stops recording

**Option B: Upload Audio File**
- User navigates to `/vocals?type=mp3` or `/vocals?audio=1`
- Selects audio file (MP3, WAV, OGG, FLAC, AAC, M4A)
- File is validated (type, size max 500MB)

### 2. Preview and Configuration

After recording/uploading:
- Modal opens with audio preview
- User fills in:
  - **Title** (required)
  - **Description** (optional)
  - **Encryption** (optional):
    - Enable/disable E2EE
    - Select encryption method (NIP-44 or NIP-04)
    - Enter recipient pubkeys (one per line, npub format) OR
    - Click "📝 Send to Myself" to add your own npub as recipient
  - **Expiration** (optional):
    - Set expiration date/time (NIP-40)
    - Relay will automatically delete event after this timestamp
  - **Geolocation** (optional):
    - Manual coordinates entry
    - "My Location" button (uses `/api/myGPS` if NIP-42 authenticated)
    - Interactive map (Leaflet)
  - **Publish to NOSTR** checkbox

### 3. Upload to IPFS

When user clicks "Publish Voice Message":
1. **NIP-42 Authentication Check**
   - Verifies recent NIP-42 auth event (kind 22242)
   - If not authenticated, attempts to send auth event
   - Required for `/api/fileupload`

2. **File Upload** (`/api/fileupload`)
   - Uploads audio file to IPFS
   - Returns:
     - `new_cid`: IPFS Content Identifier
     - `fileHash`: SHA256 hash (provenance tracking)
     - `mimeType`: Detected MIME type
     - `duration`: Audio duration in seconds
     - `info`: CID of info.json metadata file

### 4. Encryption (if enabled)

If encryption is enabled:
1. **Client-side encryption** using `window.nostr.nip44.encrypt()` or `window.nostr.nip04.encrypt()`
2. **Plaintext structure**:
   ```json
   {
     "url": "https://ipfs.io/ipfs/QmXXX.../voice.m4a",
     "duration": 45,
     "title": "My Secret Voice Note",
     "description": "A private message for you.",
     "waveform": "0 7 35 8 100...",
     "latitude": 48.85,
     "longitude": 2.29
   }
   ```
3. **Encrypted payload** stored in event `content` field
4. **Recipients** added as `p` tags

### 5. NOSTR Event Publication

Backend (`/vocals` POST endpoint):
1. Validates all required parameters
2. Gets user secret file (`~/.zen/tmp/{player}/secret.dunikey`)
3. Calls `publish_nostr_video.sh` with:
   - `--kind 1222` (or `1244` for replies)
   - `--ipfs-cid`: Audio file CID
   - `--title`: Voice message title
   - `--description`: Optional description
   - `--duration`: Audio duration
   - `--latitude`, `--longitude`: Optional geolocation
   - `--waveform`: Optional waveform data
   - `--file-hash`: SHA256 hash
   - `--mime-type`: Audio MIME type
   - `--channel`: User email/identifier
   - `--expiration`: Optional NIP-40 expiration timestamp (Unix timestamp)
   - `--encrypted`: Flag if message is encrypted
   - `--encryption-method`: "nip44" or "nip04"
   - `--recipients`: JSON array of recipient pubkeys (if encrypted)

4. Script publishes NOSTR event to relay
5. Returns event ID and publication status

### 6. Reading Voice Messages

Users can read voice messages via `/vocals-read`:

1. **Connect to NOSTR**
   - Click "Connect" button
   - Browser extension (Alby, nos2x, Flamingo) authenticates
   - Public key retrieved

2. **Load Messages**
   - Fetches events (kinds 1222/1244) from NOSTR relays
   - Filters by:
     - Type: All, Public, Encrypted, Sent, Received
     - Time: Last hour, 24h, 7d, 30d, All time
   - Displays sender profile, date, duration

3. **Decrypt Encrypted Messages**
   - Click "Decrypt & Play" button
   - Client-side decryption using `window.nostr.nip44.decrypt()` or `window.nostr.nip04.decrypt()`
   - Decrypted JSON parsed to extract audio URL and metadata
   - Audio player displayed with decrypted URL
   - Metadata (title, description) updated in UI

4. **Play Messages**
   - Public messages: Direct playback from IPFS URL
   - Encrypted messages: Playback after decryption
   - Waveform visualization (if available)

## API Endpoints

### GET `/vocals`

Serves the voice messaging recording interface.

**Response:** HTML page (`vocals.html`)

**Query Parameters:**
- `audio=1` or `type=mp3`: Enable audio-only mode (hides webcam controls and video preview, shows only microphone recording and file upload options)

### GET `/vocals-read`

Serves the voice messages reader interface for viewing and decrypting received messages.

**Response:** HTML page (`vocals-read.html`)

**Features:**
- NOSTR connection via browser extension
- Fetches voice messages (kinds 1222/1244) from relays
- Filters by type (public, encrypted, sent, received) and time range
- Decrypts encrypted messages client-side
- Displays sender profiles and metadata
- Audio playback

### POST `/vocals`

Processes and publishes a voice message to NOSTR.

**Required Parameters:**
- `player`: User identifier/email
- `ipfs_cid`: IPFS Content Identifier (from `/api/fileupload`)
- `title`: Voice message title
- `npub`: NOSTR public key (for authentication)
- `file_hash`: SHA256 hash (for provenance tracking)

**Optional Parameters:**
- `description`: Voice message description
- `duration`: Audio duration in seconds
- `mime_type`: Audio MIME type (default: `audio/mpeg`)
- `waveform`: Waveform data for visual preview
- `latitude`, `longitude`: Geographic coordinates
- `expiration`: Unix timestamp (NIP-40) - relay will delete event after this time
- `encrypted`: `"true"` to enable encryption (default: `"false"`)
- `encryption_method`: `"nip44"` (recommended) or `"nip04"` (legacy)
- `recipients`: JSON array of recipient pubkeys (required if `encrypted=true`)
- `publish_nostr`: Flag to publish event (default: `"false"`)

**Response:** HTML page with publication status

**Example Request:**
```bash
curl -X POST http://localhost:54321/vocals \
  -F "player=user@example.com" \
  -F "ipfs_cid=QmXXX..." \
  -F "title=My Voice Message" \
  -F "npub=npub1..." \
  -F "file_hash=abc123..." \
  -F "encrypted=true" \
  -F "encryption_method=nip44" \
  -F "recipients=[\"npub1recipient1...\",\"npub1recipient2...\"]" \
  -F "latitude=48.8566" \
  -F "longitude=2.3522" \
  -F "expiration=1752600000"
```

### GET `/api/getN2`

Returns network of contacts for recipient selection.

**Parameters:**
- `hex`: User's public key (64-char hex)
- `range`: `"default"` (mutual connections) or `"full"` (all N1 connections)
- `output`: `"json"` (default) or `"html"`

**Response:** JSON with enriched node data:
```json
{
  "center_pubkey": "...",
  "total_n1": 10,
  "total_n2": 50,
  "nodes": [
    {
      "pubkey": "...",
      "npub": "npub1...",
      "display_name": "Alice",
      "email": "alice@example.com",
      "picture": "https://...",
      "mutual": true,
      "is_follower": true,
      "is_followed": true
    }
  ]
}
```

**Usage in Frontend:**
```javascript
// Fetch contacts for recipient selection
const response = await fetch(`/api/getN2?hex=${userPubkeyHex}&range=default`);
const network = await response.json();

// Filter mutual contacts
const recipients = network.nodes
  .filter(node => node.mutual && node.npub)
  .map(node => node.npub);
```

## NOSTR Event Structure

### Public Voice Message (Kind 1222)

```json
{
  "kind": 1222,
  "content": "https://ipfs.io/ipfs/QmXXX.../voice.m4a",
  "created_at": 1752501052,
  "pubkey": "sender_pubkey_hex",
  "tags": [
    ["imeta", "url https://ipfs.io/ipfs/QmXXX.../voice.m4a", "duration 45", "waveform 0 7 35 8 100..."],
    ["g", "u09tun0"],  // Geohash (NIP-101)
    ["t", "voice-message"]
  ],
  "id": "...",
  "sig": "..."
}
```

### Encrypted Voice Message (Kind 1222)

```json
{
  "kind": 1222,
  "content": "nip44encryptedpayloadbase64...",
  "created_at": 1752501052,
  "pubkey": "sender_pubkey_hex",
  "tags": [
    ["p", "recipient1_pubkey_hex"],
    ["p", "recipient2_pubkey_hex"],
    ["encrypted", "true"],
    ["encryption", "nip44"],
    ["imeta", "duration 45"],  // Public metadata (optional)
    ["expiration", "1752600000"]  // NIP-40: Relay will delete after this timestamp (optional)
  ],
  "id": "...",
  "sig": "..."
}
```

**Decrypted Content Structure:**
```json
{
  "url": "https://ipfs.io/ipfs/QmXXX.../voice_encrypted.m4a",
  "duration": 45,
  "title": "My Secret Voice Note",
  "description": "A private message for you.",
  "waveform": "0 7 35 8 100...",
  "latitude": 48.8566,
  "longitude": 2.3522
}
```

### Reply Voice Message (Kind 1244)

Follows NIP-22 reply structure with `e` and `p` tags:

```json
{
  "kind": 1244,
  "content": "https://ipfs.io/ipfs/QmYYY.../reply.m4a",
  "created_at": 1752501053,
  "pubkey": "sender_pubkey_hex",
  "tags": [
    ["e", "original_event_id", "relay_url", "reply"],
    ["p", "original_sender_pubkey"],
    ["imeta", "url https://ipfs.io/ipfs/QmYYY.../reply.m4a", "duration 30"]
  ],
  "id": "...",
  "sig": "..."
}
```

## Encryption Details

### Supported Methods

1. **NIP-44** (Recommended)
   - Modern encryption using ChaCha20-Poly1305
   - Better security than NIP-04
   - Client-side: `window.nostr.nip44.encrypt(recipientPubkey, plaintext)`
   - Client-side: `window.nostr.nip44.decrypt(senderPubkey, ciphertext)`

2. **NIP-04** (Legacy)
   - AES-256-CBC encryption
   - Backward compatibility
   - Client-side: `window.nostr.nip04.encrypt(recipientPubkey, plaintext)`
   - Client-side: `window.nostr.nip04.decrypt(senderPubkey, ciphertext)`

### Self-Messaging

Users can send encrypted voice messages to themselves:
- Click "📝 Send to Myself" button in the encryption UI
- Automatically adds your own npub as recipient
- Useful for reminders, notes, or scheduled messages
- Works with expiration dates (NIP-40) for time-limited reminders

### Multiple Recipients

**Approach 1: Separate Events** (Recommended for small groups)
- Create separate events for each recipient
- Each event encrypted with that recipient's public key
- All events reference same audio file URL

**Approach 2: Shared Secret** (For larger groups)
- Encrypt audio URL with symmetric key
- Encrypt symmetric key separately for each recipient
- Store encrypted keys in `["key", "..."]` tags

**Current Implementation:**
- Uses Approach 1 (separate encryption per recipient)
- TODO: Support Approach 2 for groups

## Expiration (NIP-40)

### Event Expiration

Voice messages can include an expiration timestamp (NIP-40):

- **Tag**: `["expiration", "<unix_timestamp>"]`
- **Behavior**: Relays supporting NIP-40 will automatically delete the event after this timestamp
- **Use Cases**:
  - Temporary reminders
  - Time-limited announcements
  - Self-destructing messages
- **Client Behavior**: Clients SHOULD ignore expired events
- **Relay Behavior**: Relays SHOULD NOT send expired events to clients

**Note**: Expiration is not a security feature - events may be cached or downloaded before expiration.

## Geolocation

### UMAP Integration (NIP-101)

Voice messages can be anchored to geographic locations:

- **Public Messages**: Use `g` tag with geohash
- **Encrypted Messages**: Include coordinates in encrypted payload
- **Map Display**: Clients SHOULD display location only after decryption

### Location Sources

1. **User Profile GPS** (`/api/myGPS`)
   - Requires NIP-42 authentication
   - More accurate (from UPlanet profile)
   - Preferred method

2. **Browser Geolocation API**
   - Fallback if NIP-42 not authenticated
   - Less accurate
   - Requires user permission

3. **Manual Entry**
   - User enters coordinates manually
   - Interactive map (Leaflet) for selection

## File Formats

### Supported Audio Formats

- **MP3** (`.mp3`) - `audio/mpeg`
- **WAV** (`.wav`) - `audio/wav`
- **OGG** (`.ogg`) - `audio/ogg`
- **FLAC** (`.flac`) - `audio/flac`
- **AAC** (`.aac`) - `audio/aac`
- **M4A** (`.m4a`) - `audio/mp4` (recommended per NIP-A0)

### File Size Limits

- **Maximum**: 500MB per file
- **Recommended**: < 10MB for encrypted messages (per A0-encryption-extension.md)
- **Duration**: SHOULD be ≤ 60 seconds (per NIP-A0)

## Security Considerations

### Authentication

- **NIP-42 Required**: All uploads require recent NIP-42 authentication event (kind 22242)
- **Cache TTL**: 5 minutes (prevents DoS)
- **Force Check**: Uploads use `force_check=True` for fresh validation

### Encryption

- **Client-Side Only**: Encryption happens in browser using `window.nostr` API
- **No Server Access**: Backend never sees decrypted content
- **Metadata Leakage**: Public tags (duration) may leak information
- **Relay Trust**: Relays see event metadata but not decrypted content

### File Validation

- **MIME Type Detection**: Uses `python-magic` for content-based detection
- **Extension Fallback**: If MIME type is `application/octet-stream`, checks file extension
- **Path Traversal Protection**: All file paths validated and sanitized
- **Size Limits**: Enforced per user (MULTIPASS users: 650MB, others: 100MB)

## Integration with Other Systems

### NOSTR Network (N2)

The `/api/getN2` endpoint provides enriched contact information:
- Profile data (name, picture, email)
- Connection status (mutual, follower, followed)
- npub format for encryption

**Use Case**: Recipient selection in encryption UI

### IPFS Storage

- Audio files stored on IPFS
- Metadata in `info.json` (RFC 8785 JCS)
- Provenance tracking via SHA256 hashes
- Upload chain for re-uploads

### UMAP (NIP-101)

- Geographic anchoring of voice messages
- Integration with UPlanet location system
- Geohash tags for public messages

## Frontend Implementation

### Key Functions

**`publishVoiceMessage(audioBlob, filename)`**
- Handles complete publication workflow
- Uploads to IPFS
- Encrypts if enabled
- Publishes to NOSTR

**`adaptUIForAudioMode()`**
- Hides webcam controls
- Shows audio upload section
- Adapts UI for audio-only workflow

**Encryption Flow:**
```javascript
// Check if encryption enabled
const isEncrypted = document.getElementById('encrypt-message')?.checked;
const recipientsText = document.getElementById('recipients-list')?.value;

if (isEncrypted && recipientsText) {
  // Parse recipients
  const recipientsList = recipientsText.split('\n')
    .map(line => line.trim())
    .filter(line => line.startsWith('npub'));
  
  // Prepare metadata
  const voiceMetadata = {
    url: ipfsUrl,
    duration: duration,
    title: title,
    description: description
  };
  
  // Encrypt for first recipient
  const encryptedContent = await window.nostr.nip44.encrypt(
    recipientsList[0], 
    JSON.stringify(voiceMetadata)
  );
  
  // Add to form data
  formData.append('encrypted', 'true');
  formData.append('encryption_method', 'nip44');
  formData.append('recipients', JSON.stringify(recipientsList));
}
```

## Backend Implementation

### Key Functions

**`process_vocals_message()`** (`/vocals` POST)
- Validates all parameters
- Checks NIP-42 authentication
- Calls `publish_nostr_video.sh` with kind 1222
- Returns publication status

**`fetch_nostr_profiles()`**
- Fetches NOSTR profiles (kind 0) for contact list
- Cached for 1 hour (TTL)
- Returns enriched profile data

**`require_nostr_auth()`**
- FastAPI dependency for authentication
- Reduces code duplication
- Returns authenticated npub or raises HTTPException

## Examples

### Example 1: Public Voice Message

```bash
# 1. Upload audio file
curl -X POST http://localhost:54321/api/fileupload \
  -F "file=@voice.m4a" \
  -F "npub=npub1..."

# Response: {"success": true, "new_cid": "QmXXX...", ...}

# 2. Publish to NOSTR
curl -X POST http://localhost:54321/vocals \
  -F "player=user@example.com" \
  -F "ipfs_cid=QmXXX..." \
  -F "title=Hello World" \
  -F "npub=npub1..." \
  -F "file_hash=abc123..." \
  -F "publish_nostr=true"
```

### Example 2: Encrypted Voice Message

```javascript
// Frontend code
const formData = new FormData();
formData.append('player', 'user@example.com');
formData.append('ipfs_cid', 'QmXXX...');
formData.append('title', 'Secret Message');
formData.append('npub', userPubkey);
formData.append('file_hash', 'abc123...');
formData.append('encrypted', 'true');
formData.append('encryption_method', 'nip44');
formData.append('recipients', JSON.stringify(['npub1recipient...']));

const response = await fetch('/vocals', {
  method: 'POST',
  body: formData
});
```

### Example 3: Fetching Contacts for Recipient Selection

```javascript
// Get user's hex pubkey
const userHex = npubToHex(userPubkey);

// Fetch network
const response = await fetch(`/api/getN2?hex=${userHex}&range=default`);
const network = await response.json();

// Filter mutual contacts
const contacts = network.nodes
  .filter(node => node.mutual && node.npub)
  .map(node => ({
    npub: node.npub,
    name: node.display_name || node.name || 'Unknown',
    picture: node.picture,
    email: node.email
  }));

// Display in UI for selection
```

## Error Handling

### Common Errors

1. **"No IPFS CID provided"**
   - **Cause**: Audio not uploaded via `/api/fileupload` first
   - **Solution**: Upload file first, then use returned CID

2. **"Nostr authentication failed"**
   - **Cause**: No recent NIP-42 auth event
   - **Solution**: Click "Connect" button to send auth event

3. **"Recipients required for encrypted messages"**
   - **Cause**: Encryption enabled but no recipients specified
   - **Solution**: Enter at least one recipient npub

4. **"File type 'application/octet-stream' is not allowed"**
   - **Cause**: MIME type detection failed
   - **Solution**: Backend automatically falls back to extension check

## Performance Optimizations

### Caching

- **Profile Cache**: 1 hour TTL for NOSTR profiles
- **Auth Cache**: 5 minutes TTL for NIP-42 authentication
- **Directory Cache**: Cached user directory lookups

### Batch Operations

- Profile fetching: Batched (50 pubkeys at a time)
- Network analysis: Optimized for large networks

## Future Enhancements

- [ ] Support for multiple recipients with shared secret approach (currently uses separate events)
- [ ] Audio file encryption before upload (full E2EE - currently only URL/metadata encrypted)
- [ ] Voice message threading/replies UI
- [ ] Waveform generation client-side
- [ ] Voice message playback in feed
- [ ] Integration with NostrTube for voice message discovery
- [ ] Voice message transcription (NIP-90 integration)
- [ ] Scheduled messages (currently only expiration supported via NIP-40)

## Related Documentation

- [NIP-A0: Voice Messages](nostr-nips/A0.md)
- [A0-encryption-extension.md](nostr-nips/A0-encryption-extension.md)
- [NIP-44: Encrypted Payloads](nostr-nips/44.md)
- [NIP-42: Authentication of Clients to Relays](nostr-nips/42.md)
- [NIP-101: UPlanet - Decentralized Identity & Geographic Coordination](nostr-nips/101.md)
- [UPlanet_FILE_CONTRACT.md](UPlanet_FILE_CONTRACT.md)

## Code References

- Frontend Recording: `UPassport/templates/vocals.html`
- Frontend Reading: `UPassport/templates/vocals-read.html`
- Backend Routes: `UPassport/54321.py` (lines 3746-4410)
- NOSTR Script: `~/.zen/Astroport.ONE/tools/publish_nostr_video.sh`
- Upload Script: `~/.zen/Astroport.ONE/tools/upload2ipfs.sh`

