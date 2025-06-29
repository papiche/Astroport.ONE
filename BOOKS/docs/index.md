# UPlanet Developer Guide: Extending with #BRO Tags & Services

> **Complete guide to extending UPlanet with #BRO tags and services**

---

## Table of Contents

- [What is #BRO?](#what-is-bro)
- [Creating UPlanet-Compatible Applications](#creating-uplanet-compatible-applications)
- [Encrypted File Sharing Example](#encrypted-file-sharing-example)
- [API Reference](#api-reference)
- [Tagging and Advertising Services](#tagging-and-advertising-services)
- [Developer Quickstart](#developer-quickstart)
- [uSPOT Station Intelligence](#uspot-station-intelligence)
- [Legacy Documentation](#legacy-documentation)

---

## What is #BRO?

#BRO (Broadcast Relay Operations) is UPlanet's tagging system for decentralized services and applications. It enables:

- **Service Discovery**: Find available services in your area
- **Interoperability**: Standardized communication between applications
- **Geographic Intelligence**: Location-based service matching
- **Decentralized Architecture**: No central authority required

### Why Use #BRO?

1. **Automatic Discovery**: Services are automatically found by UPlanet users
2. **Geographic Context**: Services are matched based on user location
3. **Standardized Interface**: Common API patterns across all services
4. **Privacy-Preserving**: Direct peer-to-peer communication
5. **Extensible**: Easy to add new service types

### Philosophy

UPlanet follows an open, composable, and decentralized approach:
- **Open**: All protocols and APIs are documented and accessible
- **Composable**: Services can be combined and extended
- **Decentralized**: No single point of control or failure

---

## Creating UPlanet-Compatible Applications

### Core Principles

1. **Tag Your Service**: Use #BRO and relevant tags in your manifest
2. **Expose APIs**: Provide REST endpoints or shell scripts for interaction
3. **Follow Conventions**: Use UPlanet directory structures and naming
4. **Document Everything**: Clear APIs and usage examples

### Example: `generate_ipfs_structure.sh` (uDRIVE)

This script transforms any folder into a decentralized drive, generating a manifest and providing a modern web interface for browsing, editing, and sharing files.

#### Key Features

- **Incremental IPFS Publishing**: Only uploads new or modified files
- **Markdown Editor**: Built-in editor for documents
- **File Copy Between uDRIVE Instances**: Seamless file sharing
- **NOSTR Authentication**: Secure uploads using decentralized identity

#### How to Use

```bash
# Basic usage
./generate_ipfs_structure.sh ./myfolder

# With detailed logging
./generate_ipfs_structure.sh --log ./myfolder

# The script returns a CID - access your drive at:
# http://127.0.0.1:8080/ipfs/[CID]/
```

#### How to Extend

1. **Add a manifest.json with tags**:
```json
{
  "name": "MyCoolApp",
  "version": "1.0.0",
  "description": "A UPlanet-compatible application",
  "tags": ["#BRO", "#storage", "#documents"],
  "api": "/api/mycoolapp",
  "author": "Your Name",
  "license": "AGPL-3.0"
}
```

2. **Implement a REST or shell API** for your service
3. **Advertise your service** in the UPlanet swarm (see below)

#### Directory Structure

```
myapp/
├── Documents/     # User documents
├── Images/        # User images  
├── Videos/        # User videos
├── Music/         # User audio
├── manifest.json  # App metadata and tags
├── _index.html    # Web interface
└── api/           # API endpoints
    └── myapp.sh   # Main API script
```

---

## Encrypted File Sharing Example

This example demonstrates secure file sharing using NOSTR/NaCl, age, and GPG:

```bash
#!/bin/bash
# secure_share.sh

# Generate NOSTR keypair
NOSTR_KEY=$(keygen -t nostr "salt" "pepper")
NOSTR_PUB=$(echo "$NOSTR_KEY" | grep "NPUB=" | cut -d'=' -f2)

# Encrypt file with age
age -r "$NOSTR_PUB" -o encrypted_file.age original_file.txt

# Create NOSTR event
nostpy-cli send_event \
  -privkey "$NOSTR_SEC" \
  -kind 1 \
  -content "Encrypted file: $(ipfs add encrypted_file.age)" \
  -tags "[['t', 'secure-share'], ['p', '$RECIPIENT_PUB']]" \
  --relay "ws://127.0.0.1:7777"
```

---

## API Reference

### Ustats.sh - Territory Discovery

Discover active users and services in your area:

```bash
# Get statistics for Paris area
STATS_FILE=$(./Ustats.sh 48.85 2.35 0.1)

# Extract available services
SERVICES=$(cat "$STATS_FILE" | jq -r '.SWARM[].services[]' | sort -u)
echo "Available services: $SERVICES"
```

### NOSTRAuth - Authentication

Decentralized authentication using NOSTR keys:

```javascript
// Connect to UPlanet relay
const relay = NostrTools.relayInit('ws://127.0.0.1:7777');
await relay.connect();

// Create authentication event (NIP-42)
const event = {
    kind: 22242,
    created_at: Math.floor(Date.now() / 1000),
    tags: [
        ['relay', 'ws://127.0.0.1:7777'],
        ['challenge', 'uplanet-auth-' + Date.now()]
    ],
    content: 'Authentication for UPlanet API',
    pubkey: publicKey
};

// Sign and publish
const signedEvent = NostrTools.finishEvent(event, privateKey);
await relay.publish(signedEvent);
```

### generate_ipfs_structure.sh - uDRIVE

Create decentralized file storage:

```bash
# Generate IPFS structure
CID=$(./generate_ipfs_structure.sh ./myfiles)

# Access your drive at:
echo "http://127.0.0.1:8080/ipfs/$CID/"
```

---

## Tagging and Advertising Services

### How to Make Your Service Discoverable

1. **Add Tags to Your Manifest**:
```json
{
  "name": "MyCoolApp",
  "version": "1.0.0",
  "description": "A UPlanet-compatible application",
  "tags": ["#BRO", "#music", "#calendar", "#social"],
  "api": "/api/mycoolapp",
  "author": "Your Name",
  "license": "AGPL-3.0",
  "endpoints": {
    "upload": "/api/upload",
    "download": "/api/download",
    "search": "/api/search"
  }
}
```

2. **Announce on NOSTR Relay**:
```bash
# Create announcement event
cat > announcement.json << EOF
{
  "kind": 1,
  "content": "New #BRO service: MyCoolApp - Music streaming and calendar management",
  "tags": [
    ["t", "bro"],
    ["t", "music"],
    ["t", "calendar"],
    ["latitude", "48.8566"],
    ["longitude", "2.3522"]
  ]
}
EOF

# Publish announcement
nostpy-cli send_event -f announcement.json --relay "ws://127.0.0.1:7777"
```

3. **Register with Ustats.sh**:
```bash
# Your service will be automatically discovered
# when users run Ustats.sh in your area
```

### Service Discovery

Other users can discover your service using:

```bash
# Find all #BRO services
./Ustats.sh | jq -r '.SWARM[].services[]' | grep "#BRO" | sort -u

# Find music services
./Ustats.sh | jq -r '.SWARM[] | select(.services[] | contains("#music")) | .node_id'
```

---

## Developer Quickstart

### 1. Fork and Extend

```bash
# Clone the UPlanet repository
git clone https://github.com/your-username/uplanet-app.git
cd uplanet-app

# Create your service structure
mkdir -p {Documents,Images,Videos,Music,api}
touch manifest.json
```

### 2. Create Your API

```bash
# Create main API script
cat > api/myservice.sh << 'EOF'
#!/bin/bash

case "$1" in
    "upload")
        # Handle file upload
        echo "File uploaded successfully"
        ;;
    "download")
        # Handle file download
        echo "File downloaded successfully"
        ;;
    "search")
        # Handle search
        echo "Search results"
        ;;
    *)
        echo "Usage: $0 {upload|download|search}"
        exit 1
        ;;
esac
EOF

chmod +x api/myservice.sh
```

### 3. Create Your Manifest

```json
{
  "name": "MyService",
  "version": "1.0.0",
  "description": "My UPlanet-compatible service",
  "tags": ["#BRO", "#custom"],
  "api": "/api/myservice.sh",
  "author": "Your Name",
  "license": "AGPL-3.0"
}
```

### 4. Test and Deploy

```bash
# Test your service
./generate_ipfs_structure.sh --log .

# Get the CID
CID=$(./generate_ipfs_structure.sh .)
echo "Your service is available at: http://127.0.0.1:8080/ipfs/$CID/"

# Announce your service
echo "New #BRO service deployed: http://127.0.0.1:8080/ipfs/$CID/"
```

### 5. Join the Community

- **Chat**: Join the UPlanet developer chat
- **Issues**: Report bugs and request features
- **Contributions**: Submit pull requests and improvements

---

## uSPOT Station Intelligence

### Overview

Each Astroport station provides a **uSPOT API** (port 54321) that intercepts NOSTR messages based on their geographical location to feed both personal AI assistants and UMAP (Unified Memory and Processing) collective intelligence.

### How It Works

1. **Message Interception**: All NOSTR messages are filtered by location using `1.sh`
2. **Geographic Memory**: Messages are stored in `short_memory.py` based on coordinates
3. **AI Processing**: Messages tagged with `#BRO` or `#BOT` trigger AI responses
4. **UMAP Intelligence**: Collective memory is built for each geographic area

### AI Features Available

- **Search Integration** (`#search`): Internet search via Perplexica
- **Image Generation** (`#image`): AI image creation with ComfyUI
- **Video Generation** (`#video`): AI video creation
- **Music Generation** (`#music`): AI music composition
- **YouTube Processing** (`#youtube`): Download and convert videos
- **Voice Synthesis** (`#pierre`, `#amelie`): Text-to-speech generation

### Integration Example

```javascript
// Send AI message to local station
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

// Usage
sendAIMessage("#BRO #search latest AI developments", 48.8566, 2.3522);
```

### Benefits

1. **Geographic Intelligence**: Each location develops its own collective memory
2. **Personal AI**: Users get personalized AI responses based on their history
3. **Decentralized**: Each station operates independently
4. **Privacy-Preserving**: Messages are stored locally with user consent
5. **Scalable**: New stations automatically join the network

### Maintenance Requirements

- **28-Day Publishing**: Users must publish at least every 28 days to maintain UMAP access
- **Memory Cleanup**: Old messages are automatically archived after 50 entries
- **AI Model Updates**: Ollama models are maintained automatically

---

## Legacy Documentation

For historical reference and advanced features:

- [API.NOSTRAuth.readme.md](../Astroport.ONE/API.NOSTRAuth.readme.md) - Complete NOSTR authentication guide
- [NOSTRCARD.refresh.sh](../Astroport.ONE/RUNTIME/NOSTRCARD.refresh.sh) - Card management system
- [Ustats.sh](../Astroport.ONE/Ustats.sh) - Territory discovery API
- [generate_ipfs_structure.sh](../Astroport.ONE/tools/generate_ipfs_structure.sh) - IPFS application generator

---

## Contributing

This documentation is open for contributions! To improve it:

1. **Fork the repository**
2. **Make your changes**
3. **Submit a pull request**

For questions or help, join the UPlanet developer community.

---

*Last updated: January 2024*
