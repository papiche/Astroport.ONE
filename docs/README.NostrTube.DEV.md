# Nostr Tube - Developer Guide

## Overview

This guide explains how to build applications on top of **NostrTube** using the provided JavaScript libraries and FastAPI backend. NostrTube provides a complete toolkit for building decentralized video platforms, social networks, and Web3 applications.

---

## Table of Contents

1. [Infrastructure Discovery](#infrastructure-discovery)
2. [JavaScript Libraries](#javascript-libraries)
3. [Core NOSTR Functions](#core-nostr-functions)
4. [Video & Media Functions](#video--media-functions)
5. [Social Graph & N² Network](#social-graph--n²-network)
6. [UMAP Geographic Chat](#umap-geographic-chat-nip-28-extension)
7. [UPlanet ORE & Flora](#uplanet-ore--flora)
8. [FastAPI Backend](#fastapi-backend)
9. [Complete Examples](#complete-examples)
10. [Best Practices](#best-practices)

---

## Infrastructure Discovery

### Overview

**Critical concept**: UPlanet applications use **automatic service discovery** to find the API endpoint (uSPOT), IPFS gateway, and NOSTR relay based on the access URL. This allows applications to work seamlessly whether served from the API or from an IPFS gateway.

### Why This Matters

UPlanet applications can be accessed in **two ways**:

1. **Via API (uSPOT)**: `https://u.copylaradio.com/youtube`
2. **Via IPFS Gateway**: `https://ipfs.copylaradio.com/ipns/copylaradio.com/plantnet.html`

Both access methods must automatically discover:
- **API endpoint** (uSPOT) - for file uploads, video publishing, user management
- **IPFS gateway** - for loading videos, images, thumbnails
- **NOSTR relay** (WebSocket) - for events, comments, reactions

### Automatic Detection (common.js)

The `detectUSPOTAPI()` function in `common.js` automatically detects these URLs:

```javascript
/**
 * Detect uSPOT API, IPFS gateway, and NOSTR relay from current URL
 * Called automatically on page load
 * 
 * Sets global variables:
 * - window.uSPOT (API endpoint)
 * - window.myIPFS (IPFS gateway)
 * - window.relayUrl (NOSTR relay WebSocket)
 */
function detectUSPOTAPI() {
    const currentUrl = window.location.href;
    const hostname = window.location.hostname;
    
    // Case 1: Accessed via API (u.domain.com)
    if (hostname.startsWith('u.')) {
        window.uSPOT = window.location.origin;  // https://u.copylaradio.com
        const domain = hostname.substring(2);    // copylaradio.com
        window.myIPFS = `https://ipfs.${domain}`;
        window.relayUrl = `wss://relay.${domain}`;
    }
    
    // Case 2: Accessed via IPFS gateway (ipfs.domain.com)
    else if (hostname.startsWith('ipfs.')) {
        const domain = hostname.substring(5);    // copylaradio.com
        window.myIPFS = window.location.origin;  // https://ipfs.copylaradio.com
        window.uSPOT = `https://u.${domain}`;
        window.relayUrl = `wss://relay.${domain}`;
    }
    
    // Case 3: Localhost development
    else if (hostname === 'localhost' || hostname === '127.0.0.1') {
        window.uSPOT = 'http://127.0.0.1:54321';
        window.myIPFS = 'http://127.0.0.1:8080';
        window.relayUrl = 'ws://127.0.0.1:7777';
    }
    
    // Case 4: Other domains (default to copylaradio.com)
    else {
        window.uSPOT = 'https://u.copylaradio.com';
        window.myIPFS = 'https://ipfs.copylaradio.com';
        window.relayUrl = 'wss://relay.copylaradio.com';
    }
    
    console.log('API uSPOT détectée:', window.uSPOT);
    console.log('Gateway IPFS:', window.myIPFS);
    console.log('Relay par défaut:', window.relayUrl);
}
```

### Domain Naming Convention

UPlanet uses a **consistent subdomain naming scheme** for Astroport nodes:

| Service | Subdomain Pattern | Example | Purpose |
|---------|------------------|---------|---------|
| **API** | `u.{domain}` | `https://u.copylaradio.com` | UPassport API (FastAPI) |
| **IPFS** | `ipfs.{domain}` | `https://ipfs.copylaradio.com` | IPFS HTTP gateway |
| **Relay** | `relay.{domain}` | `wss://relay.copylaradio.com` | NOSTR relay (strfry) |

This convention allows **automatic discovery** of all services from any entry point.

### Discovery Flow

#### Scenario 1: User accesses via API

```
User visits: https://u.copylaradio.com/youtube
                    ↓
     detectUSPOTAPI() extracts hostname: u.copylaradio.com
                    ↓
     Detects "u." prefix → API access mode
                    ↓
     Sets:
     - uSPOT = https://u.copylaradio.com (current origin)
     - myIPFS = https://ipfs.copylaradio.com (derive from domain)
     - relayUrl = wss://relay.copylaradio.com (derive from domain)
                    ↓
     Application loads videos from IPFS gateway
     Application sends API requests to uSPOT
     Application connects to NOSTR relay
```

#### Scenario 2: User accesses via IPFS gateway

```
User visits: https://ipfs.copylaradio.com/ipns/copylaradio.com/youtube.html
                    ↓
     detectUSPOTAPI() extracts hostname: ipfs.copylaradio.com
                    ↓
     Detects "ipfs." prefix → IPFS access mode
                    ↓
     Sets:
     - uSPOT = https://u.copylaradio.com (derive from domain)
     - myIPFS = https://ipfs.copylaradio.com (current origin)
     - relayUrl = wss://relay.copylaradio.com (derive from domain)
                    ↓
     Application loads videos from IPFS gateway (current origin)
     Application sends API requests to uSPOT (cross-origin)
     Application connects to NOSTR relay
```

### Using Detected URLs in Your Code

Once `detectUSPOTAPI()` has run (automatically on page load), use the global variables:

```javascript
// ✅ Correct: Use detected API endpoint
const response = await fetch(`${window.uSPOT}/youtube`);

// ❌ Wrong: Hardcoded API URL
const response = await fetch('https://u.copylaradio.com/youtube');

// ✅ Correct: Use detected IPFS gateway for video
const videoUrl = `${window.myIPFS}/ipfs/${videoCID}/video.mp4`;

// ❌ Wrong: Hardcoded IPFS gateway
const videoUrl = `https://ipfs.copylaradio.com/ipfs/${videoCID}/video.mp4`;

// ✅ Correct: Use detected relay
await connectToRelay();  // Uses window.relayUrl automatically

// ❌ Wrong: Hardcoded relay URL
const relay = relayInit('wss://relay.copylaradio.com');
```

### Helper Function: getAPIBaseUrl()

For API requests, use the helper function:

```javascript
/**
 * Get the base API URL (alias for window.uSPOT)
 * @returns {string} API base URL
 */
function getAPIBaseUrl() {
    return window.uSPOT || 'https://u.copylaradio.com';
}

// Usage
const apiUrl = getAPIBaseUrl();
const response = await fetch(`${apiUrl}/api/fileupload`, {...});
```

### Cross-Origin Considerations

When accessing from IPFS gateway, API requests are **cross-origin**. The FastAPI backend handles CORS properly:

```python
# 54321.py - CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows IPFS gateway origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Swarm Discovery (Advanced)

For Astroport swarms, services are discovered via IPNS:

```javascript
// Each Astroport node publishes its services in 12345.json
// Example: https://ipfs.copylaradio.com/ipns/{node_id}/12345.json
{
    "myIPFS": "https://ipfs.copylaradio.com",
    "myRELAY": "wss://relay.copylaradio.com",
    "myAPI": "https://u.copylaradio.com",
    "ipfsnodeid": "Qm..."
}
```

The swarm map is stored in `~/.zen/tmp/swarm/{ipfsnodeid}/` and used by `backfill_constellation.sh` to synchronize NOSTR events across the network.

### Development Mode

For local development:

```javascript
// Localhost access is automatically detected
// http://localhost:54321/youtube
// or http://127.0.0.1:54321/youtube

// Sets:
window.uSPOT = 'http://127.0.0.1:54321';
window.myIPFS = 'http://127.0.0.1:8080';
window.relayUrl = 'ws://127.0.0.1:7777';
```

You can also override detection for testing:

```javascript
// Override in browser console
window.uSPOT = 'https://u.test.com';
window.myIPFS = 'https://ipfs.test.com';
window.relayUrl = 'wss://relay.test.com';

// Reload services
await connectToRelay();
```

### Best Practices

✅ **Always use detected URLs**:
```javascript
const apiUrl = window.uSPOT;
const ipfsUrl = window.myIPFS;
const relay = window.relayUrl;
```

✅ **Check if detection has run**:
```javascript
if (!window.uSPOT) {
    detectUSPOTAPI();  // Force detection
}
```

✅ **Use in templates (Jinja2)**:
```html
<!-- FastAPI sets myIPFS variable -->
<script src="{{ myIPFS }}/ipns/copylaradio.com/common.js"></script>

<!-- JavaScript then uses window.myIPFS for dynamic URLs -->
<script>
    const videoUrl = `${window.myIPFS}/ipfs/${cid}/video.mp4`;
</script>
```

✅ **Log detected values for debugging**:
```javascript
console.log('Infrastructure detected:', {
    api: window.uSPOT,
    ipfs: window.myIPFS,
    relay: window.relayUrl
});
```

❌ **Never hardcode infrastructure URLs**:
```javascript
// ❌ Bad
fetch('https://u.copylaradio.com/youtube');

// ✅ Good
fetch(`${window.uSPOT}/youtube`);
```

### Why This Design?

**1. Decentralization**: Applications work from any IPFS gateway, not just the original API

**2. Censorship Resistance**: If API goes down, users can still access via IPFS

**3. Load Distribution**: Traffic can be distributed across multiple gateways

**4. Network Resilience**: Astroport swarm can auto-discover services from any node

**5. Flexibility**: Developers can deploy on any domain following the naming convention

### Example: Multi-Node Deployment

```
Node 1 (Paris):
- API: https://u.paris.astroport.com
- IPFS: https://ipfs.paris.astroport.com
- Relay: wss://relay.paris.astroport.com

Node 2 (Berlin):
- API: https://u.berlin.astroport.com
- IPFS: https://ipfs.berlin.astroport.com
- Relay: wss://relay.berlin.astroport.com

User in Paris → Accesses u.paris.astroport.com
User in Berlin → Accesses u.berlin.astroport.com

Both see the same content (synchronized via N² NOSTR network)
Both can access videos from either IPFS gateway
Both can publish to either API endpoint
```

---

## JavaScript Libraries

### Loading Libraries

Include these libraries in your HTML templates **in this exact order**:

```html
<!-- 1. NOSTR protocol library (cryptography, event signing, relay communication) -->
<script src="{{ myIPFS }}/ipns/copylaradio.com/nostr.bundle.js"></script>

<!-- 2. Common utilities (authentication, comments, payments, UI helpers) -->
<script src="{{ myIPFS }}/ipns/copylaradio.com/common.js"></script>

<!-- 3. Optional: YouTube enhancements (video player, theater mode, engagement stats) -->
<script src="{{ myIPFS }}/ipns/copylaradio.com/youtube.enhancements.js"></script>

<!-- Optional: CSS for enhancements -->
<link rel="stylesheet" href="{{ myIPFS }}/ipns/copylaradio.com/youtube.enhancements.css" />
```

**Note**: `{{ myIPFS }}` is automatically set by FastAPI based on your Astroport gateway.

### Avoiding Variable Conflicts

⚠️ **Important**: `common.js` declares global variables like `userPubkey`, `userNpub`, `nostrRelay`, etc. To avoid conflicts in your application code, use a **namespace pattern**.

#### ❌ Wrong - Direct Variable Declaration (causes conflicts)

```javascript
<script>
    // ❌ This will conflict with common.js
    let userPubkey = null;
    let userNpub = null;
    
    async function login() {
        userPubkey = await connectNostr();  // Error: already declared
    }
</script>
```

#### ✅ Correct - Use Application Namespace

```javascript
<script>
    // ✅ Create your own namespace to avoid conflicts
    window.MyApp = {
        userPubkey: null,
        userNpub: null,
        userData: {},
        isConnected: false
    };
    
    async function login() {
        // Use common.js function
        const pubkey = await connectNostr();
        
        // Store in your namespace
        MyApp.userPubkey = pubkey;
        MyApp.isConnected = true;
        
        // Access common.js globals when needed
        console.log('Global relay:', window.nostrRelay);
    }
    
    async function uploadFile(file) {
        if (!MyApp.userPubkey) {
            alert('Please login first');
            return;
        }
        
        const formData = new FormData();
        formData.append('file', file);
        formData.append('npub', MyApp.userPubkey);
        
        const response = await fetch('/api/fileupload', {
            method: 'POST',
            body: formData
        });
    }
</script>
```

### Common.js Global Variables

After loading `common.js`, these **global variables** are available:

```javascript
// User authentication
window.userPubkey          // User's hex public key (set after connectNostr())
window.userNpub            // User's npub (set after connectNostr())

// Relay connection
window.nostrRelay          // Relay connection object
window.isNostrConnected    // Connection status (boolean)
window.relayUrl            // Current relay URL

// Infrastructure
window.myIPFS              // IPFS gateway URL (auto-detected)
window.uSPOT               // UPassport API URL (auto-detected)

// NOSTR Tools
window.NostrTools          // nostr-tools library object
```

**Best Practice**: Read from these globals but store your app state in your own namespace:

```javascript
window.MyApp = {
    // Copy from globals when needed
    init: async function() {
        await connectNostr();  // Sets window.userPubkey
        this.userPubkey = window.userPubkey;  // Copy to app state
        this.userNpub = window.userNpub;
        this.relayConnected = window.isNostrConnected;
    }
};
```

### Library Structure

```
nostr.bundle.js (7783 lines)
├── Cryptography (secp256k1, schnorr, bech32)
├── NOSTR Protocol (events, signing, verification)
├── Relay Communication (WebSocket, subscriptions)
└── Utilities (NIP-19 encoding, NIP-05 verification)

common.js (5717 lines)
├── NOSTR Connection & Auth (NIP-42)
├── User Interface (Toast notifications, themes)
├── Comments & Reactions (NIP-22, Kind 7)
├── Social Graph (Follow/unfollow, N² network)
├── Payments (MULTIPASS integration)
├── ORE & Flora (NIP-101 environmental data)
└── Utilities (Profile fetching, relay management)

youtube.enhancements.js (~3700 lines)
├── Video Player (Theater mode, engagement stats)
├── Comment System (Threading, real-time updates)
├── Playlists (NIP-51 lists)
├── Related Videos & Recommendations
├── Profile Links & Social Features
└── UI Components (Modals, cards, buttons)
```

---

## Core NOSTR Functions

### 1. Authentication & Connection

#### Connect to NOSTR

```javascript
/**
 * Connect user to NOSTR (extension or nsec key)
 * @param {boolean} forceAuth - Force authentication prompt
 * @returns {Promise<string>} User's public key (hex)
 */
async function connectNostr(forceAuth = false)

// Usage
const userPubkey = await connectNostr();
if (userPubkey) {
    console.log('Connected:', userPubkey);
}
```

#### Ensure Connection (Helper)

```javascript
/**
 * Ensure NOSTR connection, prompt if not connected
 * @param {object} options - { silent, forceAuth }
 * @returns {Promise<string|null>} User's public key or null
 */
async function ensureNostrConnection(options = {})

// Usage
const pubkey = await ensureNostrConnection({ silent: false });
if (!pubkey) {
    // User cancelled or error
    return;
}
```

#### Connect to Relay

```javascript
/**
 * Connect to NOSTR relay (WebSocket)
 * @param {boolean} forceAuth - Force NIP-42 authentication
 * @returns {Promise<void>}
 */
async function connectToRelay(forceAuth = false)

// Usage
await connectToRelay();
// Global variables set:
// - nostrRelay (relay object)
// - isNostrConnected (boolean)
// - relayUrl (string)
```

#### Global Variables

```javascript
// After successful connection:
window.userPubkey          // User's hex public key (64 chars)
window.userNpub            // User's npub (bech32 encoded)
window.nostrRelay          // Relay connection object
window.isNostrConnected    // Connection status (boolean)
window.relayUrl            // Current relay URL
window.myIPFS              // IPFS gateway URL
window.uSPOT               // UPassport API URL
```

---

### 2. Publishing Events

#### Publish Note (Generic)

```javascript
/**
 * Publish a NOSTR note (any kind)
 * @param {string} content - Note content
 * @param {Array} additionalTags - Additional tags (e.g., [['p', pubkey], ['e', eventId]])
 * @param {number} kind - Event kind (default: 1)
 * @param {object} options - { relays, ephemeral, silent, timeout }
 * @returns {Promise<object>} Result object
 */
async function publishNote(content, additionalTags = [], kind = 1, options = {})

// Usage - Simple text note (Kind 1)
const result = await publishNote('Hello Nostr!');
if (result.success) {
    console.log('Published:', result.eventId);
}

// Usage - Reply to event
const result = await publishNote('Great video!', [
    ['e', parentEventId, relayUrl, parentAuthorPubkey],
    ['p', parentAuthorPubkey]
]);

// Usage - Contact list update (Kind 3)
const tags = myFollowList.map(pk => ['p', pk]);
await publishNote('', tags, 3, { silent: true });

// Result object
{
    success: true,
    event: {...},              // Full signed event
    eventId: "abc123...",      // Event ID (hex)
    relaysSuccess: 1,          // Number of successful relays
    relaysTotal: 1,            // Total relays attempted
    errors: []                 // Array of errors (if any)
}
```

#### Multi-Relay Publishing

```javascript
// Publish to multiple relays
const relays = [
    'wss://relay.copylaradio.com',
    'wss://relay.damus.io',
    'wss://nos.lol'
];

const result = await publishNote('Multi-relay message', [], 1, {
    relays: relays,
    timeout: 5000  // 5 seconds timeout per relay
});

console.log(`Published to ${result.relaysSuccess}/${result.relaysTotal} relays`);
```

#### Ephemeral Events

```javascript
// Ephemeral event (not stored by relay)
await publishNote('Temporary message', [], 20000, {
    ephemeral: true,
    silent: true
});
```

---

### 3. User Profile & Metadata

#### Fetch User Metadata (Kind 0)

```javascript
/**
 * Fetch user's profile metadata (Kind 0)
 * @param {string} pubkey - User's hex public key
 * @returns {Promise<object|null>} Profile object or null
 */
async function fetchUserMetadata(pubkey)

// Usage
const profile = await fetchUserMetadata(userPubkey);
if (profile) {
    console.log('Name:', profile.name || profile.display_name);
    console.log('Avatar:', profile.picture);
    console.log('About:', profile.about);
    console.log('NIP-05:', profile.nip05);
}

// Profile object structure
{
    name: "username",
    display_name: "Display Name",
    picture: "https://example.com/avatar.jpg",
    about: "Bio text",
    nip05: "user@domain.com",
    banner: "https://example.com/banner.jpg",
    website: "https://example.com",
    lud16: "user@getalby.com"  // Lightning address
}
```

#### Get Display Name (Helper)

```javascript
/**
 * Get user's display name with fallback
 * @param {string} pubkey - User's hex public key
 * @param {boolean} cached - Use cached profile (default: true)
 * @returns {Promise<string>} Display name or truncated pubkey
 */
async function getUserDisplayName(pubkey, cached = true)

// Usage
const name = await getUserDisplayName(pubkey);
console.log(name); // "Alice" or "60c1133d..." (if no profile)
```

#### Fetch User Email (NIP-101 DID)

```javascript
/**
 * Fetch user's email from DID document (Kind 30800)
 * @param {string} pubkey - User's hex public key
 * @returns {Promise<string|null>} Email or null
 */
async function fetchUserEmailWithFallback(pubkey)

// Usage
const email = await fetchUserEmailWithFallback(pubkey);
if (email) {
    console.log('Email:', email);
}
```

---

### 4. Social Graph (Follow/Unfollow)

#### Fetch Follow List (Kind 3)

```javascript
/**
 * Fetch user's contact list (Kind 3)
 * @param {string} pubkey - User's hex public key
 * @param {number} timeout - Timeout in ms (default: 3000)
 * @returns {Promise<Array<string>>} Array of followed pubkeys
 */
async function fetchUserFollowList(pubkey, timeout = 3000)

// Usage
const following = await fetchUserFollowList(userPubkey);
console.log(`Following ${following.length} users`);
```

#### Check if Following

```javascript
/**
 * Check if current user is following target
 * @param {string} targetPubkey - Target user's pubkey
 * @returns {Promise<boolean>}
 */
async function isUserFollowing(targetPubkey)

// Usage
const isFollowing = await isUserFollowing(targetPubkey);
console.log(isFollowing ? 'Following' : 'Not following');
```

#### Toggle Follow/Unfollow

```javascript
/**
 * Follow or unfollow a user
 * @param {string} targetPubkey - Target user's pubkey
 * @param {object} options - { silent, onSuccess, onError }
 * @returns {Promise<object>} Result object
 */
async function toggleUserFollow(targetPubkey, options = {})

// Usage
const result = await toggleUserFollow(targetPubkey, {
    onSuccess: (action, followList) => {
        console.log(`${action === 'follow' ? 'Followed' : 'Unfollowed'}`);
        console.log(`Now following ${followList.length} users`);
    }
});

// Result object
{
    success: true,
    action: 'follow',      // 'follow' or 'unfollow'
    followList: [...]      // Updated follow list
}
```

---

### 5. Comments & Reactions

#### Post Comment (NIP-22, Kind 1111)

```javascript
/**
 * Post a comment on current page (Kind 1111)
 * @param {string} content - Comment text
 * @param {string} url - Target URL (default: current page)
 * @returns {Promise<object>} Result object
 */
async function postComment(content, url = null)

// Usage
const result = await postComment('Great content!');
if (result.success) {
    showNotification({ message: 'Comment published!', type: 'success' });
}
```

#### Fetch Comments

```javascript
/**
 * Fetch comments for URL (Kind 1111)
 * @param {string} url - Target URL (default: current page)
 * @param {number} limit - Max comments (default: 100)
 * @returns {Promise<Array>} Array of comment objects
 */
async function fetchComments(url = null, limit = 100)

// Usage
const comments = await fetchComments();
comments.forEach(comment => {
    console.log(`${comment.authorName}: ${comment.content}`);
});

// Comment object structure
{
    id: "event_id",
    pubkey: "author_pubkey",
    content: "Comment text",
    created_at: 1704067200,
    authorName: "Display Name",
    authorAvatar: "https://...",
    rawEvent: {...}  // Full NOSTR event
}
```

#### Display Comments UI

```javascript
/**
 * Render comments section with form and threading
 * @param {string} containerId - Container element ID
 * @returns {Promise<void>}
 */
async function displayComments(containerId = 'nostr-comments')

// Usage in HTML
<div id="nostr-comments"></div>

<script>
await displayComments('nostr-comments');
</script>
```

#### Send Reaction (Like/Dislike)

```javascript
/**
 * Send a like reaction (Kind 7)
 * @param {string} eventId - Target event ID
 * @param {string} authorPubkey - Author's pubkey
 * @param {string} content - Reaction content (default: "+")
 * @returns {Promise<object>} Result object
 */
async function sendLike(eventId, authorPubkey, content = "+")

/**
 * Send a dislike reaction (Kind 7)
 */
async function sendDislike(eventId, authorPubkey)

/**
 * Send custom emoji reaction (Kind 7)
 */
async function sendCustomReaction(eventId, authorPubkey, emoji)

// Usage
await sendLike(videoEventId, uploaderPubkey);
await sendCustomReaction(videoEventId, uploaderPubkey, '🔥');
```

#### Fetch Reactions

```javascript
/**
 * Fetch all reactions for an event (Kind 7)
 * @param {string} eventId - Target event ID
 * @param {number} limit - Max reactions (default: 50)
 * @returns {Promise<Array>} Array of reaction events
 */
async function fetchReactions(eventId, limit = 50)

/**
 * Get reaction statistics
 * @returns {Promise<object>} Stats object
 */
async function getReactionStats(eventId)

// Usage
const stats = await getReactionStats(videoEventId);
console.log(`Likes: ${stats.likes}, Dislikes: ${stats.dislikes}`);

// Stats object
{
    likes: 42,
    dislikes: 3,
    customReactions: {
        '🔥': 15,
        '❤️': 8,
        '👍': 12
    },
    total: 80
}
```

---

### 6. UI Helpers

#### Show Notification (Toast UI)

```javascript
/**
 * Display modern toast notification
 * @param {object} options - Notification options
 * @returns {HTMLElement} Toast element
 */
function showNotification(options = {})

// Usage - Simple success
showNotification({
    message: 'Video uploaded successfully!',
    type: 'success'
});

// Usage - Error with long duration
showNotification({
    message: 'Failed to connect to relay',
    type: 'error',
    duration: 5000  // 5 seconds
});

// Usage - Persistent warning
showNotification({
    message: 'Your session will expire soon',
    type: 'warning',
    duration: 0,  // Stays until manually closed
    position: 'top-center'
});

// Options
{
    message: 'Text to display',
    type: 'success',     // 'success', 'error', 'warning', 'info'
    duration: 3000,      // Duration in ms (0 = permanent)
    position: 'top-right', // 'top-right', 'top-center', 'bottom-right', 'bottom-center'
    dismissible: true    // Show close button
}
```

#### Update Button State

```javascript
/**
 * Temporarily update button text and state
 * @param {HTMLElement|string} button - Button element or ID
 * @param {object} options - State options
 */
function updateButtonState(button, options = {})

// Usage
const btn = document.getElementById('submit-btn');
updateButtonState(btn, {
    text: 'Published!',
    icon: '✅',
    duration: 2000,
    disable: true
});

// After 2 seconds, button returns to original state
```

#### Create Profile Link

```javascript
/**
 * Create clickable profile link with avatar
 * @param {object} options - Link options
 * @returns {Promise<HTMLElement>} Link element
 */
async function createProfileLink(options = {})

// Usage
const link = await createProfileLink({
    pubkey: authorPubkey,
    displayName: 'Alice',  // Optional, will fetch if not provided
    className: 'author-link',
    onClick: (pubkey, displayName) => {
        console.log('Clicked:', displayName);
        openProfileModal(pubkey);
    }
});

document.getElementById('author-container').appendChild(link);
```

---

## Video & Media Functions

### 1. Video Upload & Publishing

#### Upload File to IPFS

```javascript
/**
 * Upload file to IPFS via /api/fileupload
 * @param {File} file - File object from input
 * @param {string} npub - User's npub for authentication
 * @returns {Promise<object>} Upload result
 */
async function uploadFileToIPFS(file, npub)

// Usage
const fileInput = document.getElementById('video-file');
const file = fileInput.files[0];

const result = await uploadFileToIPFS(file, userNpub);
if (result.success) {
    console.log('IPFS CID:', result.new_cid);
    console.log('Thumbnail:', result.thumbnail_ipfs);
    console.log('Info JSON:', result.info);
}

// Result object
{
    success: true,
    message: "File uploaded successfully to IPFS",
    file_path: "/path/to/file.mp4",
    file_type: "video",
    target_directory: "/path/to/uDRIVE/Videos",
    new_cid: "QmHash...",
    thumbnail_ipfs: "QmThumb...",
    gifanim_ipfs: "QmGif...",
    info: "QmInfo...",
    timestamp: "2025-11-06T12:00:00",
    auth_verified: true
}
```

#### Publish Video to NOSTR (NIP-71)

```javascript
/**
 * Publish video event to NOSTR (Kind 21/22)
 * Calls POST /webcam endpoint
 */
async function publishVideoToNostr(videoData)

// Usage
const formData = new FormData();
formData.append('player', playerEmail);
formData.append('ipfs_cid', uploadResult.new_cid);
formData.append('thumbnail_ipfs', uploadResult.thumbnail_ipfs || '');
formData.append('gifanim_ipfs', uploadResult.gifanim_ipfs || '');
formData.append('info_cid', uploadResult.info || '');
formData.append('file_hash', uploadResult.file_hash || '');
formData.append('title', 'My Video Title');
formData.append('description', 'Video description');
formData.append('npub', userNpub);
formData.append('publish_nostr', 'true');
formData.append('latitude', '48.8566');
formData.append('longitude', '2.3522');

const response = await fetch('/webcam', {
    method: 'POST',
    body: formData
});

const html = await response.text();
// Returns success page or error
```

---

### 2. Fetch & Display Videos

#### Fetch Videos from NOSTR

```javascript
/**
 * Fetch videos from /youtube API
 * @param {object} filters - Query parameters
 * @returns {Promise<object>} Video data
 */
async function fetchVideos(filters = {})

// Usage - All videos
const data = await fetch('/youtube').then(r => r.json());

// Usage - Filter by channel
const data = await fetch('/youtube?channel=MyChannel').then(r => r.json());

// Usage - Search
const data = await fetch('/youtube?search=bitcoin').then(r => r.json());

// Usage - Geographic filter
const data = await fetch('/youtube?lat=48.8566&lon=2.3522&radius=5').then(r => r.json());

// Response structure
{
    success: true,
    total_videos: 42,
    channels: {
        "ChannelName": {
            channel_info: {
                name: "ChannelName",
                display_name: "Channel Display",
                type: "youtube",
                video_count: 10,
                total_duration_seconds: 3600,
                total_duration_formatted: "1h 0m"
            },
            videos: [...]
        }
    },
    filtered_videos: [...]
}
```

#### Video Object Structure

```javascript
// Video object from /youtube API
{
    id: "event_id",
    title: "Video Title",
    url: "/ipfs/QmHash/video.mp4",
    thumbnail: "/ipfs/QmThumb/thumb.jpg",
    duration: "3:45",
    duration_seconds: 225,
    uploader: "Channel Name",
    channel: "Channel-Name",
    published_at: 1704067200,
    published_at_formatted: "2024-01-01",
    description: "Video description",
    tags: ["tag1", "tag2"],
    latitude: 48.8566,
    longitude: 2.3522,
    location: "48.86,2.35",
    dimensions: "1920x1080",
    mime_type: "video/mp4",
    file_hash: "abc123...",
    info_cid: "QmInfo...",
    upload_chain: "pubkey1,pubkey2",
    original_event: "event_id",
    original_author: "pubkey"
}
```

---

### 3. Theater Mode & Video Player

#### Open Theater Mode

```javascript
/**
 * Open video in theater mode modal
 * @param {string} videoId - Video event ID or IPFS CID
 */
function openTheaterMode(videoId)

// Usage
const videoCard = document.querySelector('.video-card');
videoCard.addEventListener('dblclick', () => {
    openTheaterMode(videoCard.dataset.eventId);
});
```

#### Load Video in Theater

```javascript
/**
 * Initialize theater mode with video data
 * Called automatically when /theater loads
 */
async function initializeTheaterModeLocal(videoId)

// This function:
// 1. Fetches video event from NOSTR
// 2. Loads video player
// 3. Loads comments (Kind 1111)
// 4. Loads related videos
// 5. Displays engagement stats
// 6. Shows provenance info
```

#### Post Video Comment

```javascript
/**
 * Post comment on video (Kind 1111 with NIP-22 tags)
 * @param {string} content - Comment text
 * @param {string} videoEventId - Video event ID
 * @param {number} videoKind - Video kind (21 or 22)
 * @param {string} authorPubkey - Video author's pubkey
 * @returns {Promise<object>} Result object
 */
async function postVideoComment(content, videoEventId, videoKind, authorPubkey)

// Usage (in theater-modal.html)
const commentText = document.getElementById('comment-input').value;
const result = await postVideoComment(
    commentText,
    videoData.eventId,
    videoData.kind,  // 21 or 22
    videoData.authorId
);
```

---

### 4. Engagement Stats

#### Load Video Statistics

```javascript
/**
 * Load engagement stats for video
 * @param {string} eventId - Video event ID
 * @returns {Promise<object>} Stats object
 */
async function loadVideoStats(eventId)

// Usage
const stats = await loadVideoStats(videoEventId);
console.log(`Likes: ${stats.likes}, Comments: ${stats.comments}`);

// Stats object
{
    likes: 42,
    dislikes: 3,
    comments: 15,
    shares: 8,
    views: 150  // Estimated from comment/reaction activity
}
```

#### Display Stats on Video Card

```javascript
/**
 * Add engagement stats badges to video card
 * @param {HTMLElement} card - Video card element
 * @param {string} eventId - Video event ID
 */
async function addEngagementBadges(card, eventId)

// Usage
document.querySelectorAll('.video-card').forEach(async (card) => {
    const eventId = card.dataset.eventId;
    await addEngagementBadges(card, eventId);
});
```

---

### 5. User Tags & Tag Cloud

#### Add Tag to Video

```javascript
/**
 * Add a user tag to a video (NIP-32 Labeling)
 * @param {string} videoEventId - Video event ID (kind 21 or 22)
 * @param {string} tagValue - Tag value (lowercase, alphanumeric)
 * @param {string} videoAuthorPubkey - Video author's pubkey (optional)
 * @param {string} relayUrl - Relay URL where video is stored
 * @returns {Promise<object>} Result object
 */
async function addVideoTag(videoEventId, tagValue, videoAuthorPubkey = null, relayUrl = null)

// Usage
const result = await addVideoTag(videoEventId, 'bitcoin');
if (result.success) {
    console.log('Tag added:', result.tagValue);
}

// Result object
{
    success: true,
    tagEventId: "event_id",
    tagValue: "bitcoin"
}
```

#### Remove Tag from Video

```javascript
/**
 * Remove a user tag from a video
 * @param {string} tagEventId - The kind 1985 event ID to delete
 * @returns {Promise<object>} Result object
 */
async function removeVideoTag(tagEventId)

// Usage
const result = await removeVideoTag(tagEventId);
if (result.success) {
    console.log('Tag removed');
}
```

#### Fetch Tags for Video

```javascript
/**
 * Fetch all tags for a video
 * @param {string} videoEventId - Video event ID
 * @param {number} timeout - Timeout in ms (default: 5000)
 * @returns {Promise<object>} Tags object with counts and taggers
 */
async function fetchVideoTags(videoEventId, timeout = 5000)

// Usage
const tags = await fetchVideoTags(videoEventId);
console.log('Tags:', tags);

// Tags object structure
{
    "bitcoin": {
        count: 5,
        taggers: ["pubkey1", "pubkey2", ...],
        events: ["event_id1", "event_id2", ...]
    },
    "tutorial": {
        count: 3,
        taggers: ["pubkey1", ...],
        events: ["event_id3", ...]
    }
}
```

#### Fetch Tag Cloud

```javascript
/**
 * Fetch tag cloud statistics
 * @param {number} limit - Number of top tags to return (default: 50)
 * @param {number} minCount - Minimum tag count (default: 1)
 * @returns {Promise<object>} Tag cloud object
 */
async function fetchTagCloud(limit = 50, minCount = 1)

// Usage
const tagCloud = await fetchTagCloud(50, 2);
console.log('Top tags:', tagCloud.tags);

// Tag cloud object
{
    tags: {
        "bitcoin": 42,
        "tutorial": 38,
        "music": 35,
        "comedy": 28
    },
    totalTags: 150,
    uniqueVideos: 75
}
```

#### Search Videos by Tag

```javascript
/**
 * Search videos by tag(s)
 * @param {string|Array<string>} tags - Tag value(s) to search for
 * @param {string} operator - 'AND' or 'OR' (default: 'OR')
 * @returns {Promise<Array<string>>} Array of video event IDs
 */
async function searchVideosByTag(tags, operator = 'OR')

// Usage - Single tag
const videoIds = await searchVideosByTag('bitcoin');

// Usage - Multiple tags (OR)
const videoIds = await searchVideosByTag(['bitcoin', 'ethereum'], 'OR');

// Usage - Multiple tags (AND)
const videoIds = await searchVideosByTag(['bitcoin', 'tutorial'], 'AND');
```

#### Display Video Tags UI

```javascript
/**
 * Display tag input and existing tags for a video
 * @param {string} containerId - Container element ID
 * @param {string} videoEventId - Video event ID
 */
async function displayVideoTags(containerId, videoEventId)

// Usage in HTML
<div id="tags-video123"></div>

<script>
await displayVideoTags('tags-video123', videoEventId);
</script>
```

#### Display Tag Cloud UI

```javascript
/**
 * Display tag cloud
 * @param {string} containerId - Container element ID
 * @param {number} limit - Number of tags to display (default: 50)
 */
async function displayTagCloud(containerId, limit = 50)

// Usage in HTML
<div id="tag-cloud"></div>

<script>
await displayTagCloud('tag-cloud', 50);
</script>
```

#### Tag Naming Conventions

**Recommended:**
- Use lowercase: `bitcoin`, `tutorial`, `music`
- Use hyphens for multi-word: `machine-learning`, `web-development`
- Use underscores for compound: `video_game`, `how_to`
- Keep tags concise (1-3 words max)
- Avoid special characters except hyphens and underscores

**Examples:**
- ✅ `bitcoin`, `crypto`, `tutorial`, `music`, `comedy`
- ✅ `machine-learning`, `web-development`, `cooking-tips`
- ❌ `Bitcoin` (should be lowercase)
- ❌ `bitcoin tutorial` (use hyphen: `bitcoin-tutorial`)
- ❌ `bitcoin!` (no special chars)

#### API Endpoints

**GET /api/video/tags**
- Get tag cloud statistics
- Query params: `limit`, `min_count`

**GET /api/video/tags/{video_id}**
- Get all tags for a specific video

**GET /youtube?tag={tag_value}**
- Filter videos by tag
- Query params: `tag`, `tags` (comma-separated OR), `tags_and` (comma-separated AND)

---

## Social Graph & N² Network

### 1. N² Network Discovery

#### Fetch N² Network

```javascript
/**
 * Get N² network graph (friends + friends of friends)
 * Calls /api/getN2 endpoint
 */
async function fetchN2Network(pubkeyHex, range = 'default')

// Usage
const response = await fetch(`/api/getN2?hex=${userPubkey}&range=default`);
const network = await response.json();

console.log(`N1 (friends): ${network.total_n1}`);
console.log(`N2 (friends of friends): ${network.total_n2}`);

// Network object
{
    center_pubkey: "...",
    total_n1: 50,
    total_n2: 450,
    total_nodes: 501,
    range_mode: "default",  // "default" or "full"
    nodes: [
        {
            pubkey: "...",
            level: 1,  // 0=center, 1=N1, 2=N2
            is_follower: true,
            is_followed: true,
            mutual: true,
            connections: ["pubkey1", "pubkey2"]
        }
    ],
    connections: [
        { from: "pubkey1", to: "pubkey2" }
    ],
    timestamp: "2025-11-06T12:00:00",
    processing_time_ms: 1234
}
```

#### Filter Videos by N² Network

```javascript
/**
 * Get videos from N² network
 * Combines /youtube API with /api/getN2
 */
async function getN2Videos(pubkeyHex)

// Usage
const network = await fetchN2Network(userPubkey);
const allVideos = await fetch('/youtube').then(r => r.json());

// Filter videos from N1/N2
const n2Pubkeys = new Set(network.nodes.map(n => n.pubkey));
const n2Videos = allVideos.filtered_videos.filter(v => 
    n2Pubkeys.has(v.author_pubkey)
);

console.log(`${n2Videos.length} videos from your network`);
```

---

### 2. UMAP Geographic Links

#### Fetch UMAP Geolinks

```javascript
/**
 * Get adjacent UMAP coordinates and their pubkeys
 * Calls /api/umap/geolinks endpoint
 */
async function fetchUMAPGeolinks(lat, lon)

// Usage
const response = await fetch(`/api/umap/geolinks?lat=48.8566&lon=2.3522`);
const geolinks = await response.json();

console.log(`Adjacent UMAPs: ${geolinks.total_adjacent}`);

// Geolinks object
{
    success: true,
    message: "UMAP geolinks retrieved successfully",
    umap_coordinates: { lat: 48.86, lon: 2.35 },
    umaps: {
        "N": "pubkey_north",
        "NE": "pubkey_northeast",
        "E": "pubkey_east",
        "SE": "pubkey_southeast",
        "S": "pubkey_south",
        "SW": "pubkey_southwest",
        "W": "pubkey_west",
        "NW": "pubkey_northwest"
    },
    sectors: {...},  // Same structure, 0.1° precision
    regions: {...},  // Same structure, 1° precision
    total_adjacent: 24,
    timestamp: "2025-11-06T12:00:00",
    processing_time_ms: 123
}
```

#### Filter Videos by UMAP

```javascript
/**
 * Get videos from specific UMAP
 */
async function getUMAPVideos(lat, lon, radius = 5)

// Usage
const videos = await fetch(
    `/youtube?lat=${lat}&lon=${lon}&radius=${radius}`
).then(r => r.json());

console.log(`${videos.total_videos} videos within ${radius}km`);
```

---

## UMAP Geographic Chat (NIP-28 Extension)

### 1. Overview

The UMAP chat system provides **location-based discussion rooms** using NIP-28 (Public Chat) combined with UMAP DIDs (NIP-101). Each geographic cell (0.01° × 0.01°) can have its own decentralized chat channel.

**Key Features:**
- Geographic chat rooms tied to real-world locations
- Based on UMAP DID identities (kind 30800)
- Uses NIP-28 channel messages (kind 42)
- Automatic UMAP discovery by coordinates
- Fallback to generic IDs if no DID exists

### 2. Initialize UMAP Chat

```javascript
/**
 * Initialize UMAP chat system
 * Searches for UMAP DID and sets up channel
 * Automatically fetches user's GPS coordinates if authenticated
 * @returns {Promise<void>}
 */
async function initUMAPChat()

// Usage
await initUMAPChat();
// Sets global UMAPChat object:
// - UMAPChat.currentUMAP { lat, lon } (from /api/myGPS or default 0.00, 0.00)
// - UMAPChat.channelId (UMAP DID npub or fallback)
// - UMAPChat.umapDID (full DID document if found)

// Behavior:
// 1. If user is authenticated (NIP-42), fetches GPS from /api/myGPS
// 2. Uses retrieved coordinates to find local UMAP DID
// 3. Falls back to default (0.00, 0.00) if GPS not available
```

### 2b. Get User GPS Coordinates (API)

```javascript
/**
 * Fetch authenticated user's GPS coordinates
 * Backend endpoint: GET /api/myGPS
 * Requires: Valid NIP-42 authentication
 * @param {string} npub - User's NOSTR public key
 * @returns {Promise<object>} GPS data
 */

// Usage
const response = await fetch(`/api/myGPS?npub=${userPubkey}`);
const gpsData = await response.json();

if (gpsData.success) {
    console.log('Coordinates:', gpsData.coordinates);
    // { lat: 48.20, lon: -2.48 }
    
    console.log('UMAP key:', gpsData.umap_key);
    // "48.20,-2.48"
    
    console.log('Email:', gpsData.email);
    // "user@example.com"
}

// Security:
// - Requires valid NIP-42 authentication (kind 22242 event on relay)
// - Only returns coordinates for the authenticated user
// - GPS file location: ~/.zen/game/nostr/{email}/GPS
// - Format: LAT=48.20; LON=-2.48;

// Response (success):
{
    "success": true,
    "coordinates": { "lat": 48.20, "lon": -2.48 },
    "umap_key": "48.20,-2.48",
    "email": "user@example.com",
    "message": "GPS coordinates retrieved successfully",
    "timestamp": "2025-11-06T23:00:00Z"
}

// Response (error 403 - not authenticated):
{
    "error": "authentication_required",
    "message": "NIP-42 authentication required to access GPS coordinates",
    "hint": "Please connect your NOSTR wallet and send an authentication event (kind 22242)"
}

// Response (error 404 - GPS not found):
{
    "error": "gps_not_found",
    "message": "GPS coordinates not found for this user",
    "hint": "GPS coordinates are set during MULTIPASS registration"
}
```

### 3. Discover UMAP DID

```javascript
/**
 * Fetch UMAP DID (kind 30800) for geographic coordinates
 * @param {number} lat - Latitude (rounded to 0.01°)
 * @param {number} lon - Longitude (rounded to 0.01°)
 * @returns {Promise<void>}
 */
async function fetchUMAPDIDForChat(lat, lon)

// Usage
await fetchUMAPDIDForChat(48.86, 2.35);

// Result stored in UMAPChat:
if (UMAPChat.umapDID) {
    console.log('Found DID:', UMAPChat.channelId); // npub1abc...
} else {
    console.log('No DID, using fallback:', UMAPChat.channelId); // UMAP_48.86_2.35
}
```

### 4. Subscribe to Messages

```javascript
/**
 * Load chat messages for current UMAP
 * @returns {Promise<void>}
 */
async function loadChatMessages()

// Usage
await loadChatMessages();

// Subscribes to NIP-28 messages (kind 42) filtered by channel ID
// Filter: { kinds: [42], "#e": [UMAPChat.channelId] }
```

### 5. Send Message

```javascript
/**
 * Send message to UMAP chat channel
 * @returns {Promise<void>}
 */
async function sendChatMessage()

// Usage
const input = document.getElementById('chatInput');
input.value = 'Hello UMAP!';
await sendChatMessage();

// Creates kind 42 event:
{
  kind: 42,
  tags: [
    ["e", UMAPChat.channelId, "", "root"],  // Channel reference
    ["g", "48.86,2.35"]                      // Geographic tag
  ],
  content: "Hello UMAP!"
}
```

### 6. Change UMAP (Switch Room)

```javascript
/**
 * Switch to a different UMAP chat room
 * @returns {Promise<void>}
 */
async function showUMAPSelector()

// Usage
await showUMAPSelector();
// Prompts user for new coordinates
// Re-fetches UMAP DID
// Reloads messages for new channel
```

### 7. Display Chat Message

```javascript
/**
 * Display a chat message in the UI
 * @param {object} event - NOSTR event (kind 42)
 */
function displayChatMessage(event)

// Usage - Automatic
// Called by subscription when new messages arrive
```

### 8. UMAP Chat Object Structure

```javascript
// Global state object
window.UMAPChat = {
    currentUMAP: { lat: 0.00, lon: 0.00 },
    channelId: '',        // UMAP DID npub or fallback ID
    umapDID: null,        // Full DID document (kind 30800)
    subscription: null,   // Relay subscription object
    activeUsers: new Set() // Track unique pubkeys in channel
};

// Example - After initialization and message loading
{
    currentUMAP: { lat: 48.86, lon: 2.35 },
    channelId: "npub1abc123...xyz",
    umapDID: {
        id: "event_id",
        pubkey: "abc123...",
        kind: 30800,
        content: "{...DID document...}"
    },
    subscription: { unsub: function() {...} },
    activeUsers: Set(3) { "abc123...", "def456...", "ghi789..." }
}

// Access user count
console.log(`Active users: ${UMAPChat.activeUsers.size}`);
```

### 8b. Track Active Users

```javascript
/**
 * Active users are automatically tracked when messages are received
 * The count is displayed in real-time in the UI badge
 */

// Users are added when:
// 1. Messages (kind 42) are received - event.pubkey is added to Set
// 2. User sends a message - their pubkey is added

// UI updates automatically via updateUMAPChatUI()
// Badge: <i class="bi bi-people-fill"></i> 3

// Reset on channel change:
UMAPChat.activeUsers.clear();  // Called in loadChatMessages()
```

### 9. Complete Example - UMAP Chat Integration

```html
<!DOCTYPE html>
<html>
<head>
    <title>UMAP Chat Demo</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css" rel="stylesheet">
</head>
<body>
    <div class="container mt-4">
        <h1>Geographic Chat Room</h1>
        
        <div class="mb-3">
            <div class="d-flex align-items-center gap-2">
                <span class="badge bg-secondary">
                    <i class="bi bi-geo-alt"></i> UMAP: <strong id="currentUMAP">0.00, 0.00</strong>
                </span>
                <button class="btn btn-sm btn-outline-secondary" onclick="showUMAPSelector()">
                    <i class="bi bi-pencil"></i> Change
                </button>
                <span class="badge bg-info ms-auto" title="Active users in this UMAP channel">
                    <i class="bi bi-people-fill"></i> <span id="channelUsersCount">0</span>
                </span>
            </div>
        </div>
        
        <div class="mb-2">
            <small class="text-muted">Channel: <code id="channelId">...</code></small>
        </div>
        
        <div id="chatMessages" style="height: 400px; overflow-y: auto; border: 1px solid #ddd; padding: 10px;"></div>
        
        <div class="input-group mt-2">
            <input type="text" id="chatInput" class="form-control" placeholder="Type a message...">
            <button class="btn btn-primary" onclick="sendChatMessage()">
                <i class="bi bi-send"></i> Send
            </button>
        </div>
    </div>
    
    <script src="{{ myIPFS }}/ipns/copylaradio.com/nostr.bundle.js"></script>
    <script src="{{ myIPFS }}/ipns/copylaradio.com/common.js"></script>
    
    <script>
        // Initialize on page load
        window.addEventListener('load', async () => {
            // Connect to relay
            await connectToRelay();
            
            // Connect user (for authentication)
            const pubkey = await connectNostr();
            
            if (pubkey) {
                // Initialize UMAP chat (will fetch GPS if authenticated)
                await initUMAPChat();
                
                // Load messages (will populate activeUsers count)
                await loadChatMessages();
                
                console.log('Chat initialized with', UMAPChat.activeUsers.size, 'active users');
            }
        });
    </script>
</body>
</html>
```

### 10. Best Practices

✅ **Use UMAP DID as Channel ID when available:**
```javascript
// Good - Uses DID-based channel
if (UMAPChat.umapDID) {
    channelId = NostrTools.nip19.npubEncode(UMAPChat.umapDID.pubkey);
}
```

✅ **Always include geographic tag:**
```javascript
tags.push(["g", `${lat.toFixed(2)},${lon.toFixed(2)}`]);
```

✅ **Round coordinates to 0.01° precision:**
```javascript
lat = Math.round(lat * 100) / 100;  // 48.8566 -> 48.86
lon = Math.round(lon * 100) / 100;  // 2.3522 -> 2.35
```

✅ **Unsubscribe when changing UMAP:**
```javascript
if (UMAPChat.subscription) {
    UMAPChat.subscription.unsub();
}
```

✅ **Handle missing DIDs gracefully:**
```javascript
if (!UMAPChat.umapDID) {
    console.log('No DID found, using fallback channel ID');
    channelEl.title = 'No UMAP DID registered for this location';
}
```

### 11. Integration with ORE System

UMAP chats are part of the larger ORE ecosystem:

**Environmental Compliance Discussions:**
```javascript
// Fetch ORE contracts for current UMAP
const contracts = await fetchOREContractsForUMAP(
    UMAPChat.currentUMAP.lat,
    UMAPChat.currentUMAP.lon
);

// Discuss in UMAP chat
await sendChatMessage(`Found ${contracts.length} ORE contracts here!`);
```

**Flora Observations:**
```javascript
// Share plant identification in local UMAP
await sendChatMessage('🌱 Just identified a Quercus robur (Oak tree) here!');
```

**Verification Meetings:**
```javascript
// Announce ORE verification session
await sendChatMessage('📅 ORE verification meeting tomorrow at 10am in this UMAP');
```

See **NIP-28 UMAP Extension** (`28-umap-extension.md`) for full protocol specification.

---

## UPlanet ORE & Flora

### 1. Flora Statistics (Plant Observations)

#### Fetch User Flora Stats

```javascript
/**
 * Fetch user's flora observation statistics
 * @param {string} pubkey - User's hex pubkey
 * @param {Array} relays - Relay URLs (optional)
 * @returns {Promise<object>} Flora stats
 */
async function fetchUserFloraStats(pubkey, relays = null)

// Usage
const stats = await fetchUserFloraStats(userPubkey);
console.log(`Trees: ${stats.totalTrees}`);
console.log(`Species: ${stats.speciesCount}`);
console.log(`Observations: ${stats.totalMessages}`);

// Stats object
{
    totalTrees: 42,
    totalMessages: 150,
    speciesCount: 15,
    speciesList: ['Quercus', 'Fagus', ...],
    umapCount: 8,
    umapList: ['48.86_2.35', ...],
    floraScore: 850,
    badges: ['seedling', 'gardener'],
    progress: {
        nextBadge: 'botanist',
        progressPercent: 65,
        nextBadgeThreshold: 1000
    }
}
```

#### Calculate Flora Badges

```javascript
/**
 * Calculate badge levels from flora stats
 * @param {object} stats - Flora statistics
 * @returns {Array<string>} Badge names
 */
function calculateFloraBadges(stats)

// Usage
const badges = calculateFloraBadges(stats);
// Returns: ['seedling', 'gardener', 'botanist']

// Badge thresholds
{
    'seedling': 0,      // First observation
    'gardener': 100,    // 100 flora score
    'botanist': 500,    // 500 flora score
    'ecologist': 1000,  // 1000 flora score
    'naturalist': 2500  // 2500 flora score
}
```

---

### 2. ORE Verification (Environmental Compliance)

#### Fetch ORE Contracts for UMAP

```javascript
/**
 * Fetch active ORE contracts for UMAP
 * @param {number} lat - Latitude
 * @param {number} lon - Longitude
 * @param {Array} relays - Relay URLs (optional)
 * @returns {Promise<Array>} ORE contracts (Kind 30312)
 */
async function fetchOREContractsForUMAP(lat, lon, relays = null)

// Usage
const contracts = await fetchOREContractsForUMAP(48.8566, 2.3522);
contracts.forEach(contract => {
    console.log(`Contract: ${contract.title}`);
    console.log(`Requirements: ${contract.minTrees} trees, ${contract.minSpecies} species`);
    console.log(`Reward: ${contract.reward} Ğ1`);
});

// Contract object (Kind 30312)
{
    id: "event_id",
    title: "Paris UMAP Biodiversity",
    description: "Verify biodiversity in Paris center",
    latitude: 48.86,
    longitude: 2.35,
    minTrees: 50,
    minSpecies: 10,
    reward: 100,  // Ğ1
    deadline: 1735689600,
    verified: false,
    verifierPubkey: null
}
```

#### Check UMAP ORE Status

```javascript
/**
 * Check if UMAP has active ORE contracts
 * @returns {Promise<object>} Status object
 */
async function checkUMAPOREStatus(lat, lon, relays = null)

// Usage
const status = await checkUMAPOREStatus(48.8566, 2.3522);
if (status.hasActiveContracts) {
    console.log(`${status.activeCount} active contracts`);
    console.log(`Potential reward: ${status.totalReward} Ğ1`);
}

// Status object
{
    hasActiveContracts: true,
    activeCount: 3,
    totalReward: 250,
    contracts: [...]
}
```

#### Publish ORE Verification

```javascript
/**
 * Publish ORE verification meeting (Kind 30313)
 * @param {number} lat - Latitude
 * @param {number} lon - Longitude
 * @param {object} floraStats - Flora statistics
 * @param {string} notes - Verification notes
 * @returns {Promise<object>} Result object
 */
async function publishOREVerification(lat, lon, floraStats, notes = '')

// Usage
const floraStats = await fetchFloraStatsForUMAP(48.8566, 2.3522);
const result = await publishOREVerification(
    48.8566,
    2.3522,
    floraStats,
    'Verified biodiversity for Paris UMAP - excellent tree diversity'
);

if (result.success) {
    console.log('Verification published:', result.eventId);
}
```

---

## FastAPI Backend

### Authentication Endpoints

#### POST /g1nostr - Create MULTIPASS Account

```python
# Create Ğ1/NOSTR account
POST /g1nostr
Form Data:
    email: str
    lang: str
    lat: str
    lon: str
    salt: str (optional)
    pepper: str (optional)

Response: HTML page with account details
```

#### POST /api/test-nostr - Test NIP-42 Auth

```python
# Test NOSTR authentication
POST /api/test-nostr
Form Data:
    npub: str

Response JSON:
{
    "status": "success",
    "message": "NIP-42 authentication successful",
    "npub": "npub1...",
    "hex": "60c1133d...",
    "relay": "wss://relay.copylaradio.com"
}
```

---

### File Upload Endpoints

#### POST /api/fileupload - Upload File to IPFS

```python
# Upload file to IPFS with NIP-42 auth
POST /api/fileupload
Form Data:
    file: File
    npub: str (NOSTR pubkey for authentication)

Response JSON:
{
    "success": true,
    "message": "File uploaded successfully to IPFS",
    "file_path": "/path/to/file.mp4",
    "file_type": "video",
    "target_directory": "/path/to/uDRIVE/Videos",
    "new_cid": "QmHash...",
    "thumbnail_ipfs": "QmThumb...",
    "gifanim_ipfs": "QmGif...",
    "info": "QmInfo...",
    "timestamp": "2025-11-06T12:00:00",
    "auth_verified": true
}
```

#### POST /api/delete - Delete File from uDRIVE

```python
# Delete file with NIP-42 auth
POST /api/delete
JSON Body:
{
    "file_path": "/path/to/file.mp4",
    "npub": "npub1..."
}

Response JSON:
{
    "success": true,
    "message": "File deleted successfully",
    "deleted_file": "/path/to/file.mp4",
    "new_cid": "QmNewCID...",
    "timestamp": "2025-11-06T12:00:00",
    "auth_verified": true
}
```

---

### Video Endpoints

#### POST /webcam - Publish Video to NOSTR

```python
# Publish video as NOSTR event (Kind 21/22)
POST /webcam
Form Data:
    player: str (email)
    ipfs_cid: str (IPFS CID from /api/fileupload)
    thumbnail_ipfs: str (optional)
    gifanim_ipfs: str (optional)
    info_cid: str (optional)
    file_hash: str (SHA-256 hash)
    mime_type: str (default: "video/webm")
    upload_chain: str (provenance chain)
    duration: str (seconds)
    video_dimensions: str (e.g., "1920x1080")
    title: str
    description: str
    npub: str
    publish_nostr: str ("true" or "false")
    latitude: str
    longitude: str

Response: HTML page with success/error message
```

#### GET /youtube - List Videos

```python
# Get videos with filters
GET /youtube?channel=MyChannel&search=bitcoin&lat=48.8566&lon=2.3522&radius=5

Query Parameters:
    html: str (optional, "1" for HTML response)
    channel: str (filter by channel)
    search: str (search in titles)
    keyword: str (filter by keywords, comma-separated)
    date_from: str (YYYY-MM-DD)
    date_to: str (YYYY-MM-DD)
    duration_min: int (seconds)
    duration_max: int (seconds)
    sort_by: str ("date", "duration", "title", "channel")
    lat: float (latitude for geographic filter)
    lon: float (longitude)
    radius: float (radius in km)
    video: str (specific video ID for theater mode)

Response JSON:
{
    "success": true,
    "total_videos": 42,
    "channels": {...},
    "filtered_videos": [...]
}
```

#### GET /theater - Theater Mode Modal

```python
# Open video in theater mode
GET /theater?video={event_id_or_cid}

Query Parameters:
    video: str (video event ID or IPFS CID)

Response: HTML template (theater-modal.html)
```

---

### User & Location Endpoints

#### GET /api/myGPS - Get User GPS Coordinates

```python
# Get authenticated user's GPS coordinates (requires NIP-42)
GET /api/myGPS?npub={npub_or_hex}

Query Parameters:
    npub: str (user's NOSTR public key - hex or npub format)

Response JSON (success):
{
    "success": true,
    "coordinates": {
        "lat": 48.20,
        "lon": -2.48
    },
    "umap_key": "48.20,-2.48",
    "email": "user@example.com",
    "message": "GPS coordinates retrieved successfully",
    "timestamp": "2025-11-06T23:00:00Z"
}

Response JSON (error 403 - not authenticated):
{
    "error": "authentication_required",
    "message": "NIP-42 authentication required to access GPS coordinates",
    "hint": "Please connect your NOSTR wallet and send an authentication event (kind 22242)"
}

Response JSON (error 404 - GPS not found):
{
    "error": "gps_not_found",
    "message": "GPS coordinates not found for this user",
    "hint": "GPS coordinates are set during MULTIPASS registration"
}

Security:
    - Requires valid NIP-42 authentication (kind 22242)
    - Verifies authentication by calling verify_nostr_auth(npub, force_check=True)
    - Only returns coordinates for the authenticated user
    - Does not expose coordinates of other users
    
Storage:
    - GPS file location: ~/.zen/game/nostr/{email}/GPS
    - Format: LAT=48.20; LON=-2.48;
    - Set during MULTIPASS registration (/g1nostr endpoint)
    
Use Case:
    - Automatic UMAP chat room initialization
    - Location-based features (ORE verification, flora observations)
    - Geographic content filtering
```

---

### Social Graph Endpoints

#### GET /api/getN2 - N² Network Graph

```python
# Get N² network (friends + friends of friends)
GET /api/getN2?hex={pubkey_hex}&range=default

Query Parameters:
    hex: str (user's hex public key)
    range: str ("default" or "full")
    output: str ("json" or "html")

Response JSON:
{
    "center_pubkey": "...",
    "total_n1": 50,
    "total_n2": 450,
    "total_nodes": 501,
    "range_mode": "default",
    "nodes": [...],
    "connections": [...],
    "timestamp": "2025-11-06T12:00:00",
    "processing_time_ms": 1234
}
```

#### GET /api/umap/geolinks - UMAP Geographic Links

```python
# Get adjacent UMAP coordinates and their pubkeys
GET /api/umap/geolinks?lat=48.8566&lon=2.3522

Query Parameters:
    lat: float (latitude)
    lon: float (longitude)

Response JSON:
{
    "success": true,
    "message": "UMAP geolinks retrieved successfully",
    "umap_coordinates": {"lat": 48.86, "lon": 2.35},
    "umaps": {...},      # 8 adjacent UMAPs (0.01°)
    "sectors": {...},    # 8 adjacent sectors (0.1°)
    "regions": {...},    # 8 adjacent regions (1°)
    "total_adjacent": 24,
    "timestamp": "2025-11-06T12:00:00",
    "processing_time_ms": 123
}
```

---

### Oracle & Permit System

#### POST /api/permit/define - Create Permit Definition

```python
# Define a new permit type (Kind 30500)
POST /api/permit/define
JSON Body:
{
    "id": "tree-expert",
    "name": "Tree Expert Certification",
    "description": "Certified to identify tree species",
    "min_attestations": 5,
    "required_license": null,
    "valid_duration_days": 365,
    "revocable": true,
    "verification_method": "peer_attestation",
    "metadata": {}
}

Response JSON:
{
    "success": true,
    "message": "Permit definition created",
    "definition_id": "tree-expert",
    "event_id": "..."
}
```

#### POST /api/permit/request - Request Permit

```python
# Apply for a permit (Kind 30501)
POST /api/permit/request
JSON Body:
{
    "permit_definition_id": "tree-expert",
    "applicant_npub": "npub1...",
    "statement": "I have 5 years of forestry experience",
    "evidence": [
        "https://example.com/certificate.pdf",
        "ipfs://QmHash..."
    ]
}

Response JSON:
{
    "success": true,
    "message": "Permit request created",
    "request_id": "req_abc123",
    "event_id": "..."
}
```

#### POST /api/permit/attest - Attest Permit Request

```python
# Provide attestation for permit request (Kind 30502)
POST /api/permit/attest
JSON Body:
{
    "request_id": "req_abc123",
    "attester_npub": "npub1...",
    "statement": "I confirm this person is qualified",
    "attester_license_id": "lic_xyz789"  # Optional
}

Response JSON:
{
    "success": true,
    "message": "Attestation recorded",
    "attestation_id": "att_def456",
    "event_id": "..."
}
```

#### GET /api/permit/status/{request_id} - Check Permit Status

```python
# Check status of permit request
GET /api/permit/status/req_abc123

Response JSON:
{
    "request_id": "req_abc123",
    "status": "pending",  # "pending", "approved", "rejected", "expired"
    "attestation_count": 3,
    "required_attestations": 5,
    "credential_id": null,
    "created_at": "2025-11-06T12:00:00",
    "expires_at": null
}
```

---

## Complete Examples

### Example 1: Simple Video Upload & Publish

```html
<!DOCTYPE html>
<html>
<head>
    <title>Upload Video</title>
</head>
<body>
    <h1>Upload Video to NostrTube</h1>
    
    <button onclick="MyApp.connect()">Connect NOSTR</button>
    <div id="user-info"></div>
    
    <input type="file" id="video-file" accept="video/*">
    <input type="text" id="video-title" placeholder="Title">
    <button onclick="MyApp.uploadVideo()">Upload</button>
    
    <div id="status"></div>
    
    <!-- Load libraries in correct order -->
    <script src="{{ myIPFS }}/ipns/copylaradio.com/nostr.bundle.js"></script>
    <script src="{{ myIPFS }}/ipns/copylaradio.com/common.js"></script>
    
    <script>
        // ✅ Use namespace pattern to avoid conflicts
        window.MyApp = {
            userPubkey: null,
            userNpub: null,
            userEmail: null,
            
            async connect() {
                // Use common.js function
                const pubkey = await connectNostr();
                
                if (pubkey) {
                    // Store in namespace
                    this.userPubkey = pubkey;
                    this.userNpub = window.userNpub;  // Copy from global
                    
                    const name = await getUserDisplayName(pubkey);
                    const email = await fetchUserEmailWithFallback(pubkey);
                    this.userEmail = email || 'unknown@example.com';
                    
                    document.getElementById('user-info').innerHTML = 
                        `Connected: ${name} (${this.userEmail})`;
                    
                    showNotification({ 
                        message: 'Connected successfully!', 
                        type: 'success' 
                    });
                }
            },
            
            async uploadVideo() {
                if (!this.userPubkey) {
                    showNotification({ 
                        message: 'Please connect first', 
                        type: 'error' 
                    });
                    return;
                }
                
                const fileInput = document.getElementById('video-file');
                const file = fileInput.files[0];
                if (!file) {
                    showNotification({ 
                        message: 'Please select a video', 
                        type: 'warning' 
                    });
                    return;
                }
                
                const title = document.getElementById('video-title').value || 'Untitled';
                
                // Step 1: Upload to IPFS
                showNotification({ 
                    message: 'Uploading to IPFS...', 
                    type: 'info',
                    duration: 0
                });
                
                const formData = new FormData();
                formData.append('file', file);
                formData.append('npub', this.userNpub || this.userPubkey);
                
                const uploadResponse = await fetch(`${window.uSPOT}/api/fileupload`, {
                    method: 'POST',
                    body: formData
                });
                
                const uploadResult = await uploadResponse.json();
                
                if (!uploadResult.success) {
                    showNotification({ 
                        message: 'Upload failed: ' + uploadResult.message, 
                        type: 'error' 
                    });
                    return;
                }
                
                // Step 2: Publish to NOSTR
                showNotification({ 
                    message: 'Publishing to NOSTR...', 
                    type: 'info',
                    duration: 0
                });
                
                const publishFormData = new FormData();
                publishFormData.append('player', this.userEmail);
                publishFormData.append('ipfs_cid', uploadResult.new_cid);
                publishFormData.append('thumbnail_ipfs', uploadResult.thumbnail_ipfs || '');
                publishFormData.append('info_cid', uploadResult.info || '');
                publishFormData.append('title', title);
                publishFormData.append('description', '');
                publishFormData.append('npub', this.userNpub || this.userPubkey);
                publishFormData.append('publish_nostr', 'true');
                
                const publishResponse = await fetch(`${window.uSPOT}/webcam`, {
                    method: 'POST',
                    body: publishFormData
                });
                
                if (publishResponse.ok) {
                    showNotification({ 
                        message: 'Video published successfully!', 
                        type: 'success' 
                    });
                    
                    // Open in theater mode
                    window.open(`${window.uSPOT}/theater?video=${uploadResult.new_cid}`, '_blank');
                } else {
                    showNotification({ 
                        message: 'Publishing failed', 
                        type: 'error' 
                    });
                }
            }
        };
        
        // Auto-initialize on load
        window.addEventListener('load', () => {
            console.log('App initialized');
            console.log('Infrastructure:', {
                api: window.uSPOT,
                ipfs: window.myIPFS,
                relay: window.relayUrl
            });
        });
    </script>
</body>
</html>
```

---

### Example 2: Comments Section

```html
<!DOCTYPE html>
<html>
<head>
    <title>Page with Comments</title>
</head>
<body>
    <h1>My Article</h1>
    <p>This is an article with NOSTR comments.</p>
    
    <!-- Comments will be injected here -->
    <div id="nostr-comments"></div>
    
    <script src="/ipns/copylaradio.com/nostr.bundle.js"></script>
    <script src="/ipns/copylaradio.com/common.js"></script>
    
    <script>
        // Automatically display comments for current page
        displayComments('nostr-comments');
    </script>
</body>
</html>
```

---

### Example 3: Video Gallery with N² Filter

```html
<!DOCTYPE html>
<html>
<head>
    <title>Video Gallery</title>
    <style>
        .video-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
            padding: 20px;
        }
        .video-card {
            border: 1px solid #ddd;
            border-radius: 8px;
            overflow: hidden;
            cursor: pointer;
        }
        .video-card img {
            width: 100%;
            height: 180px;
            object-fit: cover;
        }
        .video-info {
            padding: 12px;
        }
    </style>
</head>
<body>
    <h1>Videos from My Network</h1>
    
    <button onclick="loadN2Videos()">Load N² Videos</button>
    <div id="video-grid" class="video-grid"></div>
    
    <script src="/ipns/copylaradio.com/nostr.bundle.js"></script>
    <script src="/ipns/copylaradio.com/common.js"></script>
    
    <script>
        async function loadN2Videos() {
            // Connect to NOSTR
            const pubkey = await ensureNostrConnection();
            if (!pubkey) return;
            
            showNotification({ 
                message: 'Loading videos from your network...', 
                type: 'info',
                duration: 0
            });
            
            // Fetch N² network
            const networkResponse = await fetch(`/api/getN2?hex=${pubkey}&range=default`);
            const network = await networkResponse.json();
            
            // Get N² pubkeys
            const n2Pubkeys = new Set(network.nodes.map(n => n.pubkey));
            
            // Fetch all videos
            const videosResponse = await fetch('/youtube');
            const videos = await videosResponse.json();
            
            // Filter by N² network
            const n2Videos = videos.filtered_videos.filter(v => 
                n2Pubkeys.has(v.author_pubkey)
            );
            
            // Display videos
            const grid = document.getElementById('video-grid');
            grid.innerHTML = '';
            
            n2Videos.forEach(video => {
                const card = document.createElement('div');
                card.className = 'video-card';
                card.innerHTML = `
                    <img src="${video.thumbnail}" alt="${video.title}">
                    <div class="video-info">
                        <h3>${video.title}</h3>
                        <p>${video.uploader}</p>
                        <span>${video.duration}</span>
                    </div>
                `;
                card.onclick = () => {
                    window.open(`/theater?video=${video.id}`, '_blank');
                };
                grid.appendChild(card);
            });
            
            showNotification({ 
                message: `Loaded ${n2Videos.length} videos from your network`, 
                type: 'success' 
            });
        }
    </script>
</body>
</html>
```

---

### Example 4: ORE Verification Dashboard

```html
<!DOCTYPE html>
<html>
<head>
    <title>ORE Verification</title>
</head>
<body>
    <h1>UPlanet ORE Verification</h1>
    
    <input type="number" id="lat" placeholder="Latitude" value="48.8566">
    <input type="number" id="lon" placeholder="Longitude" value="2.3522">
    <button onclick="checkORE()">Check ORE Status</button>
    
    <div id="ore-status"></div>
    <div id="flora-stats"></div>
    
    <button onclick="publishVerification()" style="display:none;" id="verify-btn">
        Publish Verification
    </button>
    
    <script src="/ipns/copylaradio.com/nostr.bundle.js"></script>
    <script src="/ipns/copylaradio.com/common.js"></script>
    
    <script>
        let currentFloraStats = null;
        
        async function checkORE() {
            const lat = parseFloat(document.getElementById('lat').value);
            const lon = parseFloat(document.getElementById('lon').value);
            
            // Check ORE contracts
            const status = await checkUMAPOREStatus(lat, lon);
            
            const statusDiv = document.getElementById('ore-status');
            if (status.hasActiveContracts) {
                statusDiv.innerHTML = `
                    <h2>Active ORE Contracts</h2>
                    <p>${status.activeCount} contracts</p>
                    <p>Total potential reward: ${status.totalReward} Ğ1</p>
                `;
                
                // Fetch flora stats
                const pubkey = await ensureNostrConnection();
                if (pubkey) {
                    currentFloraStats = await fetchFloraStatsForUMAP(lat, lon);
                    
                    const statsDiv = document.getElementById('flora-stats');
                    statsDiv.innerHTML = `
                        <h2>Your Flora Statistics</h2>
                        <p>Trees: ${currentFloraStats.totalTrees}</p>
                        <p>Species: ${currentFloraStats.speciesCount}</p>
                        <p>Flora Score: ${currentFloraStats.floraScore}</p>
                    `;
                    
                    // Check if eligible
                    const contract = status.contracts[0];
                    if (currentFloraStats.totalTrees >= contract.minTrees &&
                        currentFloraStats.speciesCount >= contract.minSpecies) {
                        document.getElementById('verify-btn').style.display = 'block';
                    }
                }
            } else {
                statusDiv.innerHTML = '<p>No active ORE contracts for this UMAP</p>';
            }
        }
        
        async function publishVerification() {
            const lat = parseFloat(document.getElementById('lat').value);
            const lon = parseFloat(document.getElementById('lon').value);
            
            const result = await publishOREVerification(
                lat,
                lon,
                currentFloraStats,
                'Biodiversity verification for UMAP'
            );
            
            if (result.success) {
                showNotification({ 
                    message: 'Verification published!', 
                    type: 'success' 
                });
            }
        }
    </script>
</body>
</html>
```

---

## Best Practices

### 1. Authentication

✅ **Always check authentication before actions:**
```javascript
const pubkey = await ensureNostrConnection();
if (!pubkey) {
    showNotification({ message: 'Please connect first', type: 'warning' });
    return;
}
```

✅ **Use NIP-42 for all uploads:**
```javascript
formData.append('npub', userPubkey);
```

✅ **Cache user profiles:**
```javascript
const name = await getUserDisplayName(pubkey, cached = true);
```

---

### 2. Error Handling

✅ **Always handle errors gracefully:**
```javascript
try {
    const result = await publishNote(content);
    if (result.success) {
        showNotification({ message: 'Published!', type: 'success' });
    }
} catch (error) {
    console.error('Error:', error);
    showNotification({ message: 'Error: ' + error.message, type: 'error' });
}
```

✅ **Provide user feedback:**
```javascript
showNotification({ message: 'Processing...', type: 'info', duration: 0 });
// ... do work ...
showNotification({ message: 'Done!', type: 'success' });
```

---

### 3. Performance

✅ **Use silent mode for background operations:**
```javascript
await publishNote('', tags, 3, { silent: true });
```

✅ **Batch relay operations:**
```javascript
const relays = ['wss://relay1.com', 'wss://relay2.com'];
await publishNote(content, tags, 1, { relays, timeout: 5000 });
```

✅ **Cache network data:**
```javascript
const network = await fetchN2Network(pubkey);
localStorage.setItem('n2_network', JSON.stringify(network));
```

---

### 4. UI/UX

✅ **Use toast notifications instead of alerts:**
```javascript
// ❌ Bad
alert('Video uploaded!');

// ✅ Good
showNotification({ message: 'Video uploaded!', type: 'success' });
```

✅ **Update button states:**
```javascript
updateButtonState(button, { text: 'Published!', icon: '✅', duration: 2000 });
```

✅ **Show progress indicators:**
```javascript
showNotification({ message: 'Uploading...', type: 'info', duration: 0 });
```

---

### 5. Security

✅ **Validate user input:**
```javascript
const title = document.getElementById('title').value.trim();
if (!title || title.length > 200) {
    showNotification({ message: 'Invalid title', type: 'error' });
    return;
}
```

✅ **Use XSS protection (automatic in showNotification):**
```javascript
showNotification({ message: userInput, type: 'info' });
// Content is automatically escaped
```

✅ **Verify NOSTR signatures:**
```javascript
const isValid = await verifySignature(event);
```

---

## Resources

### Documentation
- **NIP-28**: Public Chat - https://github.com/nostr-protocol/nips/blob/master/28.md
- **NIP-28 UMAP Extension**: Geographic Chat Rooms - `nostr-nips/28-umap-extension.md`
- **NIP-71**: Video Events - https://github.com/nostr-protocol/nips/blob/master/71.md
- **NIP-101**: UPlanet Protocol - https://github.com/papiche/NIP-101
- **NIP-42**: Authentication - https://github.com/nostr-protocol/nips/blob/master/42.md
- **NIP-22**: Comments - https://github.com/nostr-protocol/nips/blob/master/22.md
- **ORE System**: `ORE_SYSTEM.md` - Environmental compliance system

### Repositories
- **Astroport.ONE**: https://github.com/papiche/Astroport.ONE
- **NIP-101**: https://github.com/papiche/NIP-101
- **NOSTR NIPs**: https://github.com/nostr-protocol/nips

### Support
- Open issues on GitHub
- Join the UPlanet NOSTR community
- Contact: support.qo-op.com

---

## License

This documentation is part of the Astroport.ONE project and follows the project's licensing terms.

