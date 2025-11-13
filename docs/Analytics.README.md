# UPlanet Analytics System Documentation

## Overview

The UPlanet Analytics System (`astro.js`) provides a standardized way to collect and send analytics data in the UPlanet ecosystem. It supports multiple modes of operation depending on which libraries are loaded, from simple HTTP-based analytics to decentralized NOSTR events with optional encryption.

**Related NIPs:**
- [NIP-10000: UPlanet Analytics Events](/papiche/nostr-nips/blob/NIP-101/10000-analytics-extension.md) - Unencrypted analytics events
- [NIP-10001: Encrypted UPlanet Analytics Events](/papiche/nostr-nips/blob/NIP-101/10001-encrypted-analytics-extension.md) - Encrypted analytics events

---

## Modes of Operation

### Mode 1: Standalone (astro.js only)

When `astro.js` is loaded **alone**, it provides basic HTTP-based analytics functionality.

#### Available Functions

- **`uPlanetAnalytics.send(data, includeContext)`**
  - Sends analytics data via HTTP POST to `/ping` endpoint
  - Automatically calculates uSPOT URL from current page URL
  - Handles URL transformations (ipfs.domain → u.domain, localhost → localhost:54321)
  - Returns `Promise<boolean>`

- **`uPlanetAnalytics.sendWithContext(data)`**
  - Convenience method that automatically includes page context
  - Includes: URL, viewport, user agent, referer, timestamp
  - Returns `Promise<boolean>`

- **`uPlanetAnalytics.autoSend(data, includeContext)`**
  - Automatically sends analytics when DOM is ready
  - Useful for page view tracking
  - Returns `void`

- **`uPlanetAnalytics.getUSPOTBaseURL()`**
  - Calculates the correct uSPOT base URL
  - Handles URL transformations automatically
  - Returns `string`

- **`uPlanetAnalytics.getPageContext()`**
  - Gathers automatic page context data
  - Returns `Object` with timestamp, URL, viewport, user agent, referer

#### Example Usage

```html
<!-- Load astro.js -->
<script src="https://ipfs.copylaradio.com/ipns/copylaradio.com/astro.js"></script>

<script>
  // Basic analytics
  uPlanetAnalytics.send({
    type: 'page_view',
    source: 'email',
    email: 'user@example.com'
  });

  // With automatic page context
  uPlanetAnalytics.sendWithContext({
    type: 'multipass_card_usage',
    email: 'user@example.com',
    g1pubnostr: 'G1PUB...'
  });

  // Auto-send on page load
  uPlanetAnalytics.autoSend({
    type: 'page_view',
    source: 'web'
  });
</script>
```

#### Data Flow

```
User Action → uPlanetAnalytics.send()
    ↓
Calculate uSPOT URL (ipfs.domain → u.domain)
    ↓
HTTP POST to /ping endpoint
    ↓
Backend stores analytics
```

#### Limitations

- ❌ No NOSTR integration (no decentralized storage)
- ❌ No encryption support
- ❌ Analytics stored on centralized server only
- ✅ Simple and lightweight
- ✅ Works everywhere (no dependencies)

---

### Mode 2: With common.js (NOSTR Integration)

When `astro.js` is loaded **after** `common.js`, it gains NOSTR integration capabilities.

#### Additional Functions Available

- **`uPlanetAnalytics.isNostrAvailable()`**
  - Checks if NOSTR connection is available
  - Returns `boolean`

- **`uPlanetAnalytics.sendAsNostrEvent(data, includeContext)`**
  - Sends analytics as NOSTR event (kind 10000)
  - Requires: `common.js` loaded + NOSTR connected
  - Falls back to HTTP `/ping` if NOSTR unavailable
  - Returns `Promise<boolean>`
  - **See:** [NIP-10000](/papiche/nostr-nips/blob/NIP-101/10000-analytics-extension.md)

- **`uPlanetAnalytics.smartSend(data, includeContext, preferNostr, preferEncrypted, preferIPFS)`**
  - Automatically selects best available method
  - Tries encrypted NOSTR → unencrypted NOSTR → HTTP `/ping`
  - Returns `Promise<boolean>`

#### Example Usage

```html
<!-- Load common.js first (for NOSTR connection) -->
<script src="https://ipfs.copylaradio.com/ipns/copylaradio.com/common.js"></script>
<!-- Then load astro.js -->
<script src="https://ipfs.copylaradio.com/ipns/copylaradio.com/astro.js"></script>

<script>
  // Smart send: automatically uses NOSTR if available
  uPlanetAnalytics.smartSend({
    type: 'page_view',
    source: 'email',
    email: 'user@example.com'
  });

  // Force NOSTR event (requires NOSTR connection)
  uPlanetAnalytics.sendAsNostrEvent({
    type: 'button_click',
    button_id: 'myButton'
  });
</script>
```

#### Data Flow

```
User Action → uPlanetAnalytics.smartSend()
    ↓
Check if NOSTR available (via common.js)
    ↓
YES → Send as NOSTR event (kind 10000)
    ↓
NOSTR Relay stores event
    ↓
NO → Fallback to HTTP POST /ping
```

#### Benefits

- ✅ **Decentralized storage**: Analytics stored on NOSTR relays
- ✅ **Verifiable**: Cryptographically signed by user
- ✅ **Queryable**: Can query analytics via NOSTR filters
- ✅ **User control**: User chooses which relays store data
- ✅ **Graceful fallback**: Falls back to HTTP if NOSTR unavailable

#### NOSTR Event Structure (kind 10000)

```json
{
  "kind": 10000,
  "content": "{\"type\":\"page_view\",\"source\":\"email\",...}",
  "tags": [
    ["t", "analytics"],
    ["t", "page_view"],
    ["source", "email"],
    ["email", "user@example.com"]
  ],
  "created_at": 1704110400,
  "pubkey": "user_pubkey_hex",
  "id": "event_id_hex",
  "sig": "signature"
}
```

**See:** [NIP-10000: UPlanet Analytics Events](/papiche/nostr-nips/blob/NIP-101/nostr-nips/10000-analytics-extension.md)

---

### Mode 3: With common.js + nostr.bundle.js (Encrypted Analytics)

When `astro.js` is loaded **after** `common.js` and `nostr.bundle.js`, it gains encryption capabilities.

#### Additional Functions Available

- **`uPlanetAnalytics.isEncryptionAvailable()`**
  - Checks if encryption is available (NostrTools + user private key)
  - Returns `boolean`

- **`uPlanetAnalytics.sendEncryptedAsNostrEvent(data, includeContext, useIPFS)`**
  - Sends encrypted analytics as NOSTR event (kind 10001)
  - Requires: `nostr.bundle.js` + `common.js` + user private key
  - Uses NIP-44 encryption (ChaCha20-Poly1305)
  - Only user can decrypt their own analytics
  - Returns `Promise<boolean>`
  - **See:** [NIP-10001](/papiche/nostr-nips/blob/NIP-101/10001-encrypted-analytics-extension.md)

- **`uPlanetAnalytics.sendEncryptedAsNostrEventWithIPFS(data, includeContext)`**
  - Uploads analytics to IPFS, encrypts only CID
  - Useful for large data (> 50 KB)
  - Returns `Promise<boolean>`

#### Example Usage

```html
<!-- Load nostr.bundle.js (for encryption) -->
<script src="https://ipfs.copylaradio.com/ipns/copylaradio.com/nostr.bundle.js"></script>
<!-- Load common.js (for NOSTR connection) -->
<script src="https://ipfs.copylaradio.com/ipns/copylaradio.com/common.js"></script>
<!-- Load astro.js -->
<script src="https://ipfs.copylaradio.com/ipns/copylaradio.com/astro.js"></script>

<script>
  // Encrypted analytics (Approach A: Direct encryption - default)
  uPlanetAnalytics.sendEncryptedAsNostrEvent({
    type: 'page_view',
    source: 'web',
    current_url: window.location.href
  });

  // Encrypted analytics (Approach B: IPFS + CID)
  uPlanetAnalytics.sendEncryptedAsNostrEvent({
    type: 'page_view',
    source: 'web'
  }, true, true);  // includeContext=true, useIPFS=true

  // Smart send with encryption preference
  uPlanetAnalytics.smartSend({
    type: 'navigation_history',
    source: 'web'
  }, true, true, true);  // includeContext, preferNostr, preferEncrypted
</script>
```

#### Data Flow

```
User Action → uPlanetAnalytics.sendEncryptedAsNostrEvent()
    ↓
Separate public and sensitive data
    ↓
Encrypt sensitive data with NIP-44 (user's own pubkey)
    ↓
Send as NOSTR event (kind 10001)
    ↓
NOSTR Relay stores encrypted event
    ↓
Only user can decrypt (with their private key)
```

#### Benefits

- ✅ **Privacy**: Only user can decrypt their analytics
- ✅ **Self-ownership**: User controls encrypted data on their relays
- ✅ **History**: Complete encrypted navigation history
- ✅ **Performance**: Hybrid approach (public data in tags, sensitive data encrypted)
- ✅ **10x faster decryption**: Only encrypts sensitive data (~500 bytes - 2 KB)

#### Encryption Approaches

**Approach A: Direct Encryption** (default, recommended for analytics ~3-5 KB)
- Encrypts sensitive data directly in NOSTR event content
- No IPFS needed
- Simpler and faster

**Approach B: IPFS + CID** (for large data > 50 KB)
- Uploads data to IPFS, encrypts only CID
- Same technique as [NIP-A0 Encryption Extension](/papiche/nostr-nips/blob/NIP-101/A0-encryption-extension.md)
- Ultra-fast decryption (CID only)

**See:** [NIP-10001: Encrypted UPlanet Analytics Events](/papiche/nostr-nips/blob/NIP-101/10001-encrypted-analytics-extension.md)

---

## Function Reference

### Core Functions (Available in all modes)

| Function | Description | Returns |
|----------|-------------|---------|
| `getUSPOTBaseURL()` | Calculate uSPOT base URL | `string` |
| `getPageContext()` | Get automatic page context | `Object` |
| `send(data, includeContext)` | Send analytics via HTTP | `Promise<boolean>` |
| `sendWithContext(data)` | Send with automatic context | `Promise<boolean>` |
| `autoSend(data, includeContext)` | Auto-send on page load | `void` |

### NOSTR Functions (Requires common.js)

| Function | Description | Returns |
|----------|-------------|---------|
| `isNostrAvailable()` | Check if NOSTR is available | `boolean` |
| `sendAsNostrEvent(data, includeContext)` | Send as NOSTR event (kind 10000) | `Promise<boolean>` |
| `smartSend(data, includeContext, preferNostr, preferEncrypted, preferIPFS)` | Auto-select best method | `Promise<boolean>` |

### Encryption Functions (Requires nostr.bundle.js + common.js)

| Function | Description | Returns |
|----------|-------------|---------|
| `isEncryptionAvailable()` | Check if encryption is available | `boolean` |
| `sendEncryptedAsNostrEvent(data, includeContext, useIPFS)` | Send encrypted (kind 10001) | `Promise<boolean>` |
| `sendEncryptedAsNostrEventWithIPFS(data, includeContext)` | Send encrypted via IPFS | `Promise<boolean>` |

---

## URL Transformations

The system automatically transforms URLs to find the correct uSPOT endpoint:

- `https://ipfs.domain.tld` → `https://u.domain.tld`
- `u.domain.tld` → `u.domain.tld` (unchanged)
- `http://127.0.0.1:8080` → `http://127.0.0.1:54321`
- `http://localhost:8080` → `http://localhost:54321`

---

## Data Format

All analytics data follows this structure:

```json
{
  "type": "page_view|button_click|multipass_card_usage|...",
  "source": "email|web|api|...",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "email": "user@example.com",  // optional
  "current_url": "https://...",
  "user_agent": "...",
  "viewport": {
    "width": 1920,
    "height": 1080
  },
  "referer": "https://...",
  "uspot_url": "https://u.domain.tld",
  // ... custom fields
}
```

---

## Error Handling

- All errors are silently caught and logged to `console.debug`
- Analytics system never blocks page functionality
- Graceful fallback: NOSTR → HTTP, encrypted → unencrypted → HTTP
- User experience is never interrupted

---

## Use Cases

### 1. Simple Page Tracking (Standalone)

```html
<script src="astro.js"></script>
<script>
  uPlanetAnalytics.autoSend({
    type: 'page_view',
    source: 'web'
  });
</script>
```

### 2. Email Analytics (Standalone)

```html
<script src="astro.js"></script>
<script>
  uPlanetAnalytics.sendWithContext({
    type: 'multipass_card_usage',
    source: 'email',
    email: 'user@example.com'
  });
</script>
```

### 3. Decentralized Analytics (With common.js)

```html
<script src="common.js"></script>
<script src="astro.js"></script>
<script>
  uPlanetAnalytics.smartSend({
    type: 'page_view',
    source: 'web'
  });
</script>
```

### 4. Private Navigation History (With nostr.bundle.js + common.js)

```html
<script src="nostr.bundle.js"></script>
<script src="common.js"></script>
<script src="astro.js"></script>
<script>
  uPlanetAnalytics.sendEncryptedAsNostrEvent({
    type: 'navigation_history',
    source: 'web',
    current_url: window.location.href
  });
</script>
```

---

## Comparison Table

| Feature | Standalone | + common.js | + nostr.bundle.js |
|---------|-----------|-------------|-------------------|
| HTTP `/ping` | ✅ | ✅ | ✅ |
| NOSTR events (kind 10000) | ❌ | ✅ | ✅ |
| Encrypted events (kind 10001) | ❌ | ❌ | ✅ |
| Decentralized storage | ❌ | ✅ | ✅ |
| User control | ❌ | ✅ | ✅ |
| Privacy (encryption) | ❌ | ❌ | ✅ |
| Dependencies | None | common.js | nostr.bundle.js + common.js |

---

## References

- **Implementation**: `UPlanet/astro.js`
- **NIP-10000**: [UPlanet Analytics Events](/papiche/nostr-nips/blob/NIP-101/10000-analytics-extension.md)
- **NIP-10001**: [Encrypted UPlanet Analytics Events](/papiche/nostr-nips/blob/NIP-101/10001-encrypted-analytics-extension.md)
- **NIP-A0**: [Encryption Extension](/papiche/nostr-nips/blob/NIP-101/A0-encryption-extension.md) (uses same IPFS+CID technique)

---

## Best Practices

1. **Start simple**: Use standalone mode for basic analytics
2. **Add NOSTR**: Load `common.js` for decentralized storage
3. **Add encryption**: Load `nostr.bundle.js` for private analytics
4. **Use smartSend**: Let the system choose the best method automatically
5. **Include context**: Use `sendWithContext()` for automatic page data
6. **Handle errors gracefully**: System already does this, but be aware of fallbacks

---

**Last Updated**: 2024  
**Status**: Production  
**Version**: 1.0.0

