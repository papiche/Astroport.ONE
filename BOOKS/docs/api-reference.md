# UPlanet API Reference

> **Complete API documentation for UPlanet services and tools**

## Table of Contents

- [Ustats.sh - Territory Discovery](#ustatssh---territory-discovery)
- [NOSTRAuth - Authentication](#nostrauth---authentication)
- [generate_ipfs_structure.sh - uDRIVE](#generate_ipfs_structuresh---udrive)
- [NOSTRCARD.refresh.sh - Card Management](#nostrcardrefreshsh---card-management)
- [uSPOT API - Station Intelligence](#uspot-api---station-intelligence)

## Ustats.sh - Territory Discovery

### Overview

`Ustats.sh` is the primary API for discovering territory data, active users, and available services in the UPlanet ecosystem.

### Usage

```bash
# Get global statistics
./Ustats.sh

# Get statistics for a specific area
./Ustats.sh <LAT> <LON> <DEG>

# Example: Paris area (48.85°N, 2.35°E, 0.1° radius)
./Ustats.sh 48.85 2.35 0.1
```

### Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `LAT` | float | Latitude in decimal degrees | `48.85` |
| `LON` | float | Longitude in decimal degrees | `2.35` |
| `DEG` | float | Search radius in degrees (0.1 ≈ 11km) | `0.1` |

### Output Format

The script returns the path to a JSON file containing territory data including active users, services, and economic statistics.

## NOSTRAuth - Authentication

### Overview

NOSTRAuth provides decentralized authentication using NOSTR keys (NIP-42) for secure, serverless authentication in UPlanet applications.

### JavaScript Integration

```html
<!DOCTYPE html>
<html>
<head>
    <title>UPlanet NOSTR Authentication</title>
    <script src="https://ipfs.copylaradio.com/ipfs/QmXEmaPRUaGcvhuyeG99mHHNyP43nn8GtNeuDok8jdpG4a/nostr.bundle.js"></script>
</head>
<body>
    <div id="status">Connecting to NOSTR...</div>
    <button onclick="authenticate()">Authenticate</button>

    <script>
        async function authenticate() {
            try {
                const relay = NostrTools.relayInit('ws://127.0.0.1:7777');
                await relay.connect();
                
                const event = {
                    kind: 22242,
                    created_at: Math.floor(Date.now() / 1000),
                    tags: [
                        ['relay', 'ws://127.0.0.1:7777'],
                        ['challenge', 'test-challenge']
                    ],
                    content: 'Authentication request',
                    pubkey: 'your_public_key_here'
                };
                
                const signedEvent = NostrTools.finishEvent(event, privateKey);
                await relay.publish(signedEvent);
                
                const response = await fetch('/api/test-nostr', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: `npub=${yourNpub}`
                });
                
                const result = await response.json();
                document.getElementById('status').innerHTML = 
                    result.auth_verified ? 
                    '<p style="color: green;">✅ Authenticated!</p>' : 
                    '<p style="color: red;">❌ Authentication failed</p>';
                    
            } catch (error) {
                document.getElementById('status').innerHTML = 
                    `<p style="color: red;">❌ Error: ${error.message}</p>`;
            }
        }
    </script>
</body>
</html>
```

## generate_ipfs_structure.sh - uDRIVE

### Overview

`generate_ipfs_structure.sh` creates IPFS-compatible applications with automatic file organization, manifest generation, and web interfaces.

### Usage

```bash
# Generate IPFS structure for current directory
./generate_ipfs_structure.sh .

# Generate with detailed logging
./generate_ipfs_structure.sh --log .

# Generate for specific directory
./generate_ipfs_structure.sh /path/to/your/app
```

### Features

- **Automatic File Organization**: Sorts files by type (Images, Music, Videos, Documents)
- **Manifest Generation**: Creates manifest.json with file inventory and metadata
- **Web Interface**: Modern browser-based file explorer
- **Incremental Updates**: Only processes new or modified files

## NOSTRCARD.refresh.sh - Card Management

### Overview

`NOSTRCARD.refresh.sh` manages NOSTR cards, payments, and benefit distribution with weekly payment cycles.

### Configuration

```bash
# Default payment amounts (in Ẑen)
NCARD=1    # MULTIPASS payment amount (Ẑen)
ZCARD=4    # ZENCARD payment amount (Ẑen)
```

## uSPOT API - Station Intelligence

### Overview

Each Astroport station provides a **uSPOT API** (port 54321) that intercepts NOSTR messages based on their geographical location to feed both personal AI assistants and UMAP (Unified Memory and Processing) collective intelligence.

### Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   NOSTR Relay   │───▶│   Filter 1.sh   │───▶│ UPlanet_IA_     │
│   (strfry)      │    │   (Location     │    │ Responder.sh    │
│                  │    │    Filter)      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │  short_memory   │    │   Personal AI   │
                       │     .py         │    │   (Ollama)      │
                       │                 │    │                 │
                       └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   UMAP Memory   │    │   AI Response   │
                       │   (Geographic   │    │   (NOSTR)       │
                       │    Context)     │    │                 │
                       └─────────────────┘    └─────────────────┘
```

### Message Interception Process

#### 1. Location-Based Filtering (`1.sh`)

The relay filter intercepts all NOSTR messages and processes them based on location:

```bash
# Message classification
if ! get_key_directory "$pubkey"; then
    check="nobody"  # Visitor
else
    if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        check="player"  # Registered NOSTR card
    else
        check="uplanet"  # UPlanet system
    fi
fi
```

#### 2. Geographic Memory Storage (`short_memory.py`)

Messages are stored in two memory systems:

**UMAP Memory (Geographic Context):**
```python
# File: ~/.zen/strfry/uplanet_memory/{lat}_{lon}.json
{
  "latitude": "48.8566",
  "longitude": "2.3522", 
  "messages": [
    {
      "timestamp": "2024-01-15T10:30:00Z",
      "event_id": "abc123...",
      "pubkey": "user_hex_key",
      "content": "Message content"
    }
  ]
}
```

**Personal Memory (User Context):**
```python
# File: ~/.zen/strfry/uplanet_memory/pubkey/{pubkey}.json
{
  "pubkey": "user_hex_key",
  "messages": [
    {
      "timestamp": "2024-01-15T10:30:00Z",
      "event_id": "abc123...",
      "latitude": "48.8566",
      "longitude": "2.3522",
      "content": "Message content"
    }
  ]
}
```

#### 3. AI Processing (`UPlanet_IA_Responder.sh`)

Messages tagged with `#BRO` or `#BOT` trigger AI processing:

```bash
# AI Response Generation
if [[ "$message_text" =~ \#BRO\  || "$message_text" =~ \#BOT\  ]]; then
    
    # Load user's personal memory
    QUESTION="$($MY_PATH/question.py "${cleaned_text}" --pubkey ${PUBKEY})"
    
    # Generate AI response using Ollama
    KeyANSWER="$($MY_PATH/question.py "${cleaned_text}" --pubkey ${PUBKEY})"
    
    # Send response via NOSTR
    nostpy-cli send_event \
      -privkey "$NPRIV_HEX" \
      -kind 1 \
      -content "$KeyANSWER" \
      -tags "[['e', '$EVENT'], ['p', '$PUBKEY']]" \
      --relay "$myRELAY"
fi
```

### Special AI Features

#### 1. Search Integration (`#search`)
```bash
if [[ "$message_text" =~ \#search ]]; then
    cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#search//g; s/"//g' <<< "$message_text")
    KeyANSWER="$($MY_PATH/perplexica_search.sh "${cleaned_text}")"
fi
```

#### 2. Image Generation (`#image`)
```bash
if [[ "$message_text" =~ \#image ]]; then
    cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#image//g; s/"//g' <<< "$message_text")
    IMAGE_URL="$($MY_PATH/generate_image.sh "${cleaned_text}")"
    KeyANSWER="🖼️ $TIMESTAMP (⏱️ ${execution_time%.*} s)\n📝 Description: $cleaned_text\n🔗 $IMAGE_URL"
fi
```

#### 3. Video Generation (`#video`)
```bash
if [[ "$message_text" =~ \#video ]]; then
    cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#video//g; s/"//g' <<< "$message_text")
    VIDEO_AI_RETURN="$($MY_PATH/generate_video.sh "${cleaned_text}" "$MY_PATH/workflow/Text2VideoWan2.1.json")"
fi
```

#### 4. Music Generation (`#music`)
```bash
if [[ "$message_text" =~ \#music ]]; then
    cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#music//g; s/"//g' <<< "$message_text")
    MUSIC_URL="$($MY_PATH/generate_music.sh "${cleaned_text}")"
fi
```

#### 5. YouTube Processing (`#youtube`)
```bash
if [[ "$message_text" =~ \#youtube ]]; then
    youtube_url=$(echo "$message_text" | grep -oE 'http[s]?://(www\.)?(youtube\.com|youtu\.be)/[^ ]+')
    if [[ "$message_text" =~ \#mp3 ]]; then
        media_url=$($MY_PATH/process_youtube.sh "$youtube_url" "mp3")
    else
        media_url=$($MY_PATH/process_youtube.sh "$youtube_url" "mp4")
    fi
fi
```

#### 6. Voice Synthesis (`#pierre`, `#amelie`)
```bash
if [[ "$message_text" =~ \#pierre || "$message_text" =~ \#amelie ]]; then
    if [[ "$message_text" =~ \#pierre ]]; then
        voice="pierre"
    elif [[ "$message_text" =~ \#amelie ]]; then
        voice="amelie"
    fi
    audio_url=$($MY_PATH/generate_speech.sh "$cleaned_text" "$voice")
fi
```

### UMAP Intelligence System

#### Geographic Memory Activation

UMAP memory is activated when users publish at least every 28 days:

```bash
# UMAP memory storage
UMAPPATH="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}"

# UMAP NOSTR key generation
UMAPNPUB=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
UMAPHEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNPUB")

# Follow UMAP for collective intelligence
UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY" 2>/dev/null
```

#### Memory Management

```bash
# Memory commands
if [[ "$message_text" =~ \#mem ]]; then
    # Display conversation history
    jq -r '.messages | to_entries | .[-30:] | .[] | "📅 \(.value.timestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%d/%m/%Y %H:%M"))\n💬 \(.value.content)"' "$memory_file"
fi

if [[ "$message_text" =~ \#reset ]]; then
    # Clear user memory
    rm -f "$memory_file"
fi
```

### API Endpoints (54321.py)

Each station provides these endpoints:

#### 1. Territory Discovery
```bash
GET /?lat={latitude}&lon={longitude}&deg={radius}
# Returns: Territory statistics and active services
```

#### 2. NOSTR Authentication
```bash
POST /api/test-nostr
# Body: npub={user_public_key}
# Returns: Authentication status
```

#### 3. File Upload with NOSTR Auth
```bash
POST /api/upload
# Headers: npub={user_public_key}
# Body: file upload
# Returns: IPFS CID and file metadata
```

#### 4. AI Chat Interface
```bash
POST /astrobot_chat
# Body: {
#   "user_pubkey": "hex_key",
#   "message": "User message",
#   "latitude": "48.8566",
#   "longitude": "2.3522",
#   "application": "app_name"
# }
# Returns: AI response event ID
```

### Integration Examples

#### 1. JavaScript Client
```javascript
// Get USPOT API URL from current location
function getUSPOTUrl(route) {
    const currentUrl = new URL(window.location.href);
    let newUrl = new URL(currentUrl.origin);
    
    // Transform 'ipfs.domain.tld' to 'u.domain.tld'
    if (currentUrl.hostname.startsWith('ipfs.')) {
        newUrl.hostname = newUrl.hostname.replace('ipfs.', 'u.');
    }
    
    // Change port to 54321
    if (currentUrl.port === '8080' || currentUrl.port !== '') {
        newUrl.port = '54321';
    }
    
    return newUrl.toString() + route;
}

// Send AI message
async function sendAIMessage(message, latitude, longitude) {
    const uspotApiUrl = getUSPOTUrl('/astrobot_chat');
    const response = await fetch(uspotApiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            user_pubkey: publicKey,
            message: message,
            latitude: latitude.toFixed(6),
            longitude: longitude.toFixed(6),
            application: 'MyApp'
        })
    });
    
    return response.json();
}
```

#### 2. Python Integration
```python
import requests
import json

class USPOTClient:
    def __init__(self, base_url="http://127.0.0.1:54321"):
        self.base_url = base_url
    
    def get_territory_stats(self, lat, lon, radius=0.1):
        """Get territory statistics"""
        response = requests.get(
            f"{self.base_url}/",
            params={"lat": lat, "lon": lon, "deg": radius}
        )
        return response.json()
    
    def authenticate_nostr(self, npub):
        """Authenticate with NOSTR"""
        response = requests.post(
            f"{self.base_url}/api/test-nostr",
            data={"npub": npub}
        )
        return response.json()
    
    def upload_file(self, file_path, npub):
        """Upload file with NOSTR authentication"""
        with open(file_path, 'rb') as f:
            files = {'file': f}
            data = {'npub': npub}
            response = requests.post(
                f"{self.base_url}/api/upload",
                files=files,
                data=data
            )
        return response.json()
    
    def send_ai_message(self, message, pubkey, lat, lon):
        """Send message to AI"""
        data = {
            "user_pubkey": pubkey,
            "message": message,
            "latitude": str(lat),
            "longitude": str(lon),
            "application": "PythonClient"
        }
        response = requests.post(
            f"{self.base_url}/astrobot_chat",
            json=data
        )
        return response.json()

# Usage
client = USPOTClient()
stats = client.get_territory_stats(48.8566, 2.3522)
ai_response = client.send_ai_message("#BRO Hello AI!", "user_hex_key", 48.8566, 2.3522)
```

### Benefits of the uSPOT System

1. **Geographic Intelligence**: Each location develops its own collective memory
2. **Personal AI**: Users get personalized AI responses based on their history
3. **Decentralized**: Each station operates independently
4. **Privacy-Preserving**: Messages are stored locally with user consent
5. **Scalable**: New stations automatically join the network
6. **Interoperable**: Works with existing NOSTR infrastructure

### Maintenance Requirements

- **28-Day Publishing**: Users must publish at least every 28 days to maintain UMAP access
- **Memory Cleanup**: Old messages are automatically archived after 50 entries
- **AI Model Updates**: Ollama models are maintained automatically
- **Relay Health**: strfry relay status is monitored continuously

---

*Last updated: January 2024*
 