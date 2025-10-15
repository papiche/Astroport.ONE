# MULTIPASS System Documentation

## Overview

The **MULTIPASS** is a universal decentralized identity system that allows users to:
- Create a complete cryptographic identity from a single email address
- Access their identity from any UPlanet terminal without storing credentials
- Use secure PASS codes to control access levels and regenerate lost credentials
- Manage a personal decentralized storage space (uDRIVE)
- Interact with multiple blockchain networks (NOSTR, G1/Duniter, Bitcoin, Monero)

## What is a MULTIPASS?

A MULTIPASS is the evolution of the NOSTRCARD concept. It combines:

1. **NOSTR Identity** - A complete NOSTR keypair (npub/nsec) for social networking
2. **Blockchain Wallets** - Multiple cryptocurrency addresses (G1, Bitcoin, Monero)
3. **IPNS Storage** - Personal persistent storage vault (uDRIVE) **limited to 10GB**
4. **DID Document** - W3C-compliant Decentralized Identifier for interoperability
5. **SSSS Security** - Shamir Secret Sharing Scheme (2-of-3) for key recovery
6. **QR Codes** - Multiple QR codes for easy access and authentication

### MULTIPASS vs ZEN Card

| Feature | MULTIPASS IPFS | ZEN Card |
|---------|----------------|----------|
| **Identité** | NOSTR + DID | NOSTR + DID + Primo-transaction |
| **Stockage Public** | uDRIVE 10GB (IPFS/IPNS) | uDRIVE 10GB (IPFS/IPNS) |
| **Stockage Privé** | ❌ Non inclus | ✅ NextCloud illimité |
| **Vidéo Privée** | ❌ Non inclus | ✅ PeerTube illimité |
| **Accès SSH** | ❌ Non inclus | ✅ Accès relais essaim |
| **Coût** | Gratuit | 1Ẑ/semaine (≈0.1Ğ1) |
| **Authentification** | SSSS (2/3 parts) | SSSS + Primo-Ğ1 |
| **Usage** | Web3 public, partage | Collaboration privée |

**En résumé** :
- **MULTIPASS IPFS** = Identité + 10GB public (gratuit)
- **ZEN Card** = MULTIPASS + Stockage privé illimité (payant)

## Creation

### Using make_NOSTRCARD.sh

```bash
# Basic creation
./make_NOSTRCARD.sh user@example.com

# With language preference
./make_NOSTRCARD.sh user@example.com en

# With GPS coordinates
./make_NOSTRCARD.sh user@example.com fr 48.8566 2.3522

# With custom salt and pepper (advanced)
./make_NOSTRCARD.sh user@example.com en 48.8566 2.3522 "mysalt123" "mypper456"
```

### What Gets Created

When you create a MULTIPASS, the following files are generated in `~/.zen/game/nostr/{EMAIL}/`:

```
{EMAIL}/
├── did.json                           # W3C DID document
├── .nostr.zine.html                   # MULTIPASS ZINE (email sent to user)
├── NPUB                               # NOSTR public key (npub format)
├── HEX                                # NOSTR public key (hex format)
├── G1PUBNOSTR                         # G1/Duniter public key
├── BITCOIN                            # Bitcoin address
├── MONERO                             # Monero address
├── NOSTRNS                            # IPNS key identifier
├── TODATE                             # Creation date
├── LANG                               # Language preference
├── GPS                                # GPS coordinates
├── MULTIPASS.QR.png                   # G1 wallet QR code
├── IPNS.QR.png                        # uDRIVE access QR code
├── ._SSSSQR.png                       # SSSS secret key QR code
├── PROFILE.QR.png                     # NOSTR profile viewer QR code
├── .secret.disco                      # Encrypted DISCO seed (600 perms)
├── .ssss.head.player.enc              # SSSS part 1 (encrypted with G1PUB)
├── .ssss.mid.captain.enc              # SSSS part 2 (encrypted with CAPTAING1PUB)
├── ssss.tail.uplanet.enc              # SSSS part 3 (encrypted with UPLANETG1PUB)
└── APP/
    └── uDRIVE/
        ├── .well-known/
        │   └── did.json               # Standard DID resolution endpoint
        ├── Apps/
        │   └── Cesium.v1/             # G1 Cesium+ wallet app
        └── Documents/
            └── README.{YOUSER}.md     # Welcome documentation
```

## SSSS Key System

The MULTIPASS uses **Shamir Secret Sharing Scheme (SSSS)** to split the master secret into 3 parts:
- **2 out of 3 parts are required** to recover the identity
- Part 1: Encrypted with the user's G1 public key (owner)
- Part 2: Encrypted with the Captain's G1 public key (operator)
- Part 3: Encrypted with UPlanet's G1 public key (network)

### SSSS QR Code Format

The SSSS QR code contains:
```
M-{base58_encoded_secret}:{IPNS_vault_key}
```

Example:
```
M-3geE2ktuVKGUoEuv3FQEtiCAZDa69PN2kiT8d4UhAH3RbMkgPbooz7W:k51qzi5uqu5dhwr9cp52nhe7w13y9g58kg4l7m45ojka0tx92s72bise85sjn0
```

This allows the user to scan their SSSS key from anywhere and authenticate without storing any credentials on the device.

## PASS Code System

The PASS code system allows users to control what happens when they authenticate with their SSSS key. The PASS code can be empty or a 4-digit number entered during the authentication process at the MULTIPASS Terminal (`u.copylaradio.com/scan`).

### Available PASS Codes

| PASS Code | Purpose | Action |
|-----------|---------|--------|
| *(empty)* | **Quick Message** | Opens the simple NOSTR message interface (default, most secure for public terminals) |
| `0000` | **Resiliation** | Cancels/regenerates the MULTIPASS - allows the owner to claim a new identity if lost, stolen, or forgotten |
| `1111` | **Full Access** | Opens the complete Astro Base interface (uPlanet Messenger) with the nsec pre-filled and authenticated |
| `xxxx` | **Future** | More PASS codes coming for delegated tasks and advanced features |

### How to Use PASS Codes

1. **Go to a MULTIPASS Terminal**: Visit `u.copylaradio.com/scan` (or your local Astroport's `/scan` endpoint)
2. **Scan your SSSS QR code**: Use the camera to scan your MULTIPASS SSSS QR code
3. **Enter your PASS code** (or leave empty):
   - *(empty)* → Quick Message interface (safest for public terminals)
   - `0000` → Resiliation/Regeneration (emergency recovery)
   - `1111` → Full Astro Base interface with authenticated session
4. **Click OK**: Access is granted based on your PASS code

### MULTIPASS Terminal Interface

The MULTIPASS Terminal (`scan_new.html`) is the primary interface for SSSS authentication. It provides:

- **QR Code Scanner**: Camera-based scanning with automatic detection
- **PASS Code Entry**: Secure PIN entry with optional visibility toggle
- **Multiple Camera Support**: Automatic detection and switching between front/back cameras
- **Real-time Feedback**: Visual indicators for successful scans
- **Zero Storage**: No credentials stored in browser - everything erased on tab close

### Example Usage Scenarios

#### Scenario 1: Daily Use (PASS 1111)
```
User scans SSSS QR → Enters "1111" → Gets full Astro Base interface
↳ Can send NOSTR messages
↳ Can upload to uDRIVE
↳ Can interact with the map
↳ Can manage files
↳ nsec is auto-filled and ready to use
```

#### Scenario 2: Emergency Recovery (PASS 0000)
```
User lost device → Scans SSSS QR on friend's terminal → Enters "0000"
↳ System recognizes regeneration request
↳ Creates new MULTIPASS with same identity
↳ Invalidates old credentials
↳ User receives new ZINE by email
```

#### Scenario 3: Quick Message (Empty PASS) - DEFAULT
```
User scans SSSS QR → Leaves PASS field empty → Clicks OK
↳ Gets simple NOSTR message interface (nostr.html)
↳ Can quickly send a message
↳ Limited functionality (security by design)
↳ Perfect for public terminals
```

**Security Note**: The default mode (empty PASS) is intentionally limited to protect users on untrusted terminals. For full functionality, use PASS `1111` only on devices you trust.

## Security Model

### Key Derivation

All keys are deterministically derived from:
```
DISCO = /?{EMAIL}={SALT}&nostr={PEPPER}
```

This means:
- Same EMAIL + SALT + PEPPER = Same keys
- No keys are stored permanently
- Everything can be regenerated from the SSSS parts

### Encryption Layers

1. **SSSS Splitting** - Secret split into 3 parts (threshold 2-of-3)
2. **Asymmetric Encryption** - Each part encrypted with different keypairs
3. **Base58 Encoding** - QR code payload encoded for transport
4. **IPNS Binding** - Vault key included for verification

### No Browser Storage

The MULTIPASS system is designed with **zero browser storage**:
- nsec is **never** saved in localStorage
- nsec is **never** saved in cookies
- nsec is **never** saved in browser history
- nsec is only kept in JavaScript memory during the session
- When the user closes the tab, everything is **immediately erased**
- To reconnect, the user must scan their SSSS QR again with their PASS code

This prevents:
- Key theft from compromised browsers
- Cross-site scripting (XSS) attacks on stored credentials
- Device loss exposing private keys
- Browser extensions stealing keys
- Forensic recovery of keys from browser data
- Session hijacking attacks

**Architecture**: The SSSS QR code + PASS code system ensures that:
1. The SSSS secret is reconstructed server-side (2-of-3 Shamir scheme)
2. The nsec is derived on-the-fly from SALT + PEPPER
3. The nsec is injected into the page template at render time
4. No persistence layer touches the nsec
5. Everything vanishes when the session ends

This makes the MULTIPASS **mobile-first** and **terminal-agnostic** - you can safely use any device, anywhere, without leaving traces.

## DID Integration

Each MULTIPASS includes a W3C-compliant DID document accessible at:

```
{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/did.json
{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/APP/uDRIVE/Apps/.well-known/did.json
```

The DID document contains:
- Verification methods for all blockchain identities
- Service endpoints (NOSTR relay, IPNS vault, uDRIVE, uSPOT, Cesium)
- Authentication and authorization capabilities
- Metadata (creation date, location, language)

See [DID_IMPLEMENTATION.md](./DID_IMPLEMENTATION.md) for full details.

## uDRIVE Storage (MULTIPASS IPFS)

Each MULTIPASS includes a personal IPFS/IPNS storage space called **uDRIVE** with a **maximum of 10GB**:

```
/ipns/{NOSTRNS}/{EMAIL}/APP/uDRIVE/  (Max 10GB - Public Web3+Web2)
├── Apps/              # Web applications
│   └── Cesium.v1/     # G1 Cesium+ wallet
├── Documents/         # Text files, PDFs (public/shared)
├── Images/            # Photos, graphics (public/shared)
├── Audio/             # Music, podcasts (public/shared)
├── Video/             # Videos, streams (public/shared)
└── .well-known/       # Metadata (DID, etc.)
```

**Architecture à Deux Niveaux** :

### Niveau 1 : MULTIPASS IPFS (Public, 10GB)
- **Stockage** : uDRIVE sur IPFS/IPNS
- **Taille** : Maximum 10GB
- **Accessibilité** : Public (Web3 + Web2)
- **Usage** : Applications, sites web, contenu partageable
- **Authentification** : NOSTR (npub/nsec)

### Niveau 2 : ZEN Card (Privé, Illimité)
- **Stockage** : NextCloud ou PeerTube sur relais d'essaim
- **Taille** : Illimité (dépend de l'Astroport)
- **Accessibilité** : Privé entre relais de confiance
- **Usage** : Fichiers personnels, vidéos privées, collaboration
- **Authentification** : SSSS + Primo-transaction Ğ1

### Uploading to uDRIVE (MULTIPASS)

Users can upload files to their uDRIVE (max 10GB) via:
1. **Web interface** - Drag & drop at `{uSPOT}/upload`
2. **API** - POST to `/api/upload` with NOSTR authentication
3. **From other drives** - Copy from another user's IPFS vault

All uploads require NOSTR authentication (npub or nsec).

### Accessing Private Storage (ZEN Card)

ZEN Card holders access private storage directly:
1. **NextCloud** - Full-featured file sync and share
2. **PeerTube** - Private video hosting and streaming
3. **Direct SSH** - Command-line access to relais d'essaim

Access requires Primo-transaction validation and SSSS key reconstruction.

## Integration with UPlanet

The MULTIPASS is fully integrated with the UPlanet ecosystem:

### UPlanet Services

#### Services Publics (MULTIPASS IPFS)

1. **MULTIPASS Terminal** - Identity authentication
   - Default: `https://u.copylaradio.com/scan`
   - Local: `http://{hostname}:54321/scan`
   - Interface: scan_new.html (QR scanner with PASS codes)
   - **Taille** : Illimité (service d'authentification)

2. **uSPOT** - Wallet and credential service
   - Check balance: `{uSPOT}/check_balance?g1pub={EMAIL}`
   - Send ZEN: `{uSPOT}/zen_send`
   - **Taille** : Illimité (service transactionnel)

3. **uDRIVE** - Personal IPFS storage
   - Access: `{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/APP/uDRIVE`
   - Upload: `{uSPOT}/upload` or API `/api/upload`
   - **Taille** : **Maximum 10GB** (Web3 + Web2 public)

4. **NOSTR Relay** - Decentralized messaging
   - Default relay: `wss://relay.copylaradio.com`
   - Local relay: `ws://127.0.0.1:7777` (development)
   - **Taille** : Illimité (messages éphémères)

5. **IPFS Gateway** - Distributed storage
   - Default: `https://ipfs.copylaradio.com`
   - Local: `http://127.0.0.1:8080`
   - **Taille** : Dépend du pinning

6. **Astroport.ONE** - Control center
   - Default: `https://astroport.copylaradio.com`
   - Local: `http://{hostname}:1234`
   - **Taille** : Interface de gestion

#### Services Privés (ZEN Card)

7. **NextCloud** - Private file sync and share
   - Access: `https://cloud.{astroport-domain}/{username}`
   - Features: Sync, share, collaboration, versioning
   - **Taille** : **Illimité** (selon capacité Astroport)
   - **Authentification** : SSSS + Primo-transaction

8. **PeerTube** - Private video hosting
   - Access: `https://tube.{astroport-domain}/{username}`
   - Features: Upload, streaming, playlists, live
   - **Taille** : **Illimité** (selon capacité Astroport)
   - **Authentification** : SSSS + Primo-transaction

9. **SSH Access** - Direct relais access
   - Command: `ssh {username}@{astroport-domain}`
   - Features: Full shell, docker, automation
   - **Taille** : Dépend des quotas serveur
   - **Authentification** : Clé SSH jumelle Ed25519

### UPlanet Astroport Network

Each Astroport in the UPlanet network can:
- Create MULTIPASS identities for new users
- Authenticate existing MULTIPASS holders
- Provide terminal access for SSSS scanning
- Host local NOSTR relays and IPFS nodes

This creates a truly decentralized identity system where users can access their identity from any UPlanet terminal worldwide.

## Technical Implementation

### Scripts Involved

1. **make_NOSTRCARD.sh** - Creates the MULTIPASS
   - Generates all cryptographic keys
   - Creates QR codes
   - Publishes to IPFS/IPNS
   - Sends ZINE email to user

2. **upassport.sh** - Authenticates MULTIPASS
   - Decodes SSSS secrets (Shamir 2-of-3 reconstruction)
   - Handles PASS codes and routing
   - Opens appropriate interface based on PASS code
   - Generates nsec on-the-fly (never stored)

3. **54321.py** - API backend
   - Handles file uploads to uDRIVE
   - Manages NOSTR authentication
   - Provides REST endpoints (`/upassport`, `/api/upload`, etc.)
   - Integrates with shell scripts
   - Serves web interfaces (scan_new.html, astro_base.html, nostr.html)

4. **scan_new.html** - MULTIPASS Terminal Interface
   - Primary QR scanning interface
   - Camera control and selection
   - PASS code entry with security features
   - Real-time QR detection
   - Visual feedback and guidance

### Key Generation Tools

- **keygen** - Multi-algorithm key generator (NOSTR, Duniter, Bitcoin, Monero, IPFS)
- **nostr2hex.py** - Converts between NOSTR formats (npub/nsec ↔ hex)
- **natools.py** - NaCl encryption/decryption for SSSS parts

### Dependencies

- **IPFS** - Distributed file system
- **ssss** - Shamir Secret Sharing implementation
- **NaCl** - Cryptographic library (Ed25519)
- **silkaj** - G1/Duniter blockchain client
- **nostpy-cli** - NOSTR protocol client

## Best Practices

### For Users

1. **Print your SSSS QR code** - Keep a physical backup (laminate it!)
2. **Remember your PASS codes** - Write them down separately from the QR code
3. **Don't share your SSSS QR** - It's your master authentication key
4. **Use empty PASS on public terminals** - Default quick message mode is safest
5. **Use PASS 1111 on trusted devices only** - Full access on your devices
6. **Use PASS 0000 only for emergencies** - Resiliation invalidates old credentials
7. **Close tabs when done** - Even though nothing is stored, it's good practice
8. **Test your SSSS QR periodically** - Make sure it's not damaged
9. **Understand the 10GB limit** - uDRIVE (MULTIPASS) is limited to 10GB for public content
10. **Upgrade to ZEN Card** - For unlimited private storage (NextCloud/PeerTube)

### For Operators

1. **Keep Astroport services running** - IPFS daemon, NOSTR relay
2. **Secure the Captain keys** - SSSS part 2 is encrypted with it
3. **Monitor UPlanet network** - Ensure connectivity for recovery
4. **Backup NOSTR directories** - `~/.zen/game/nostr/` contains all identities
5. **Provide clear instructions** - Help users understand PASS codes

### For Developers

1. **Never log nsec keys** - Security critical
2. **Validate PASS codes** - Always check format and intent
3. **Use proper encryption** - NaCl for SSSS parts, GPG for DISCO
4. **Test key recovery** - Ensure SSSS reconstruction works
5. **Document new PASS codes** - Update this file when adding new codes

## Future PASS Codes (Planned)

| PASS Code | Purpose | Status |
|-----------|---------|--------|
| `2222` | View N² Network | /api/getN2 |
| `...` | More to come | Planned |

**Implementation**: Each PASS code can trigger different behaviors in `upassport.sh` by routing to specific templates or setting different environment variables. The architecture is extensible - new PASS codes can be added without breaking existing functionality.

## Technical Architecture: PASS Code Flow

### Complete Authentication Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. USER SCANS SSSS QR CODE                                              │
│    Format: M-{base58_secret}:{IPNS_vault}                               │
│    Example: M-3geE2ktu...PbooZ:k51qzi5uqu5d...                          │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. MULTIPASS TERMINAL (scan_new.html)                                   │
│    - QR code detected and decoded                                       │
│    - User enters PASS code (or leaves empty)                            │
│    - JavaScript detects SSSS format (M- or 1- prefix)                   │
│    - PASS code sent as imageData parameter                              │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. API BACKEND (54321.py)                                               │
│    POST /upassport                                                       │
│    - parametre = SSSS QR content                                        │
│    - imageData = PASS code                                              │
│    - Calls: upassport.sh "$SSSS_QR" "$PASS"                            │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. AUTHENTICATION (upassport.sh)                                        │
│    - Decode base58 SSSS secret                                          │
│    - Extract IPNS vault key                                             │
│    - Find local NOSTR card directory                                    │
│    - Decrypt SSSS parts (2-of-3):                                       │
│      • Part 1: Scanned secret (from QR)                                 │
│      • Part 3: Decrypt with UPlanet key                                 │
│    - Combine with ssss-combine → DISCO                                  │
│    - Parse DISCO: /?{EMAIL}={SALT}&nostr={PEPPER}                       │
│    - Derive nsec from SALT + PEPPER                                     │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 5. PASS CODE ROUTING                                                    │
│                                                                          │
│  if [ "$IMAGE" == "1111" ]; then                                        │
│    # PASS 1111: Full Access                                             │
│    → Generate astro_base.html with nsec auto-filled                     │
│    → Inject JavaScript to pre-select nsec mode                          │
│    → User gets full messenger interface                                 │
│                                                                          │
│  elif [ "$IMAGE" == "0000" ]; then                                      │
│    # PASS 0000: Resiliation                                             │
│    → Check G1PRIME balance                                              │
│    → Refund if balance exists                                           │
│    → Allow regeneration                                                 │
│                                                                          │
│  else                                                                    │
│    # Empty PASS: Quick Message (default)                                │
│    → Generate nostr.html with nsec in userNsec variable                │
│    → Simple message interface only                                      │
│  fi                                                                      │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 6. INTERFACE RENDERING                                                  │
│    - HTML template generated with nsec injected                         │
│    - Returned to 54321.py                                               │
│    - Sent back to browser as response                                   │
│    - nsec only in JavaScript memory (no storage)                        │
│    - User interacts with interface                                      │
│    - Tab close = everything erased                                      │
└─────────────────────────────────────────────────────────────────────────┘
```

### Code Location Reference

| Component | File | Key Functions |
|-----------|------|---------------|
| QR Scanner | `UPassport/templates/scan_new.html` | Camera control, PASS entry, SSSS detection |
| API Endpoint | `UPassport/54321.py` | `/upassport` route, form handling |
| Authentication | `UPassport/upassport.sh` | SSSS decode, PASS routing, nsec derivation |
| Full Interface | `UPassport/templates/astro_base.html` | Astro messenger (PASS 1111) |
| Quick Interface | `UPassport/templates/nostr.html` | Simple messages (empty PASS) |
| Card Creation | `Astroport.ONE/tools/make_NOSTRCARD.sh` | MULTIPASS generation, SSSS creation |

### Security Checkpoints

1. **No Client-Side Secret Storage**: SSSS parts are encrypted and split
2. **Server-Side Reconstruction**: Only server can combine SSSS parts
3. **Ephemeral nsec**: Generated on-demand, never persisted
4. **PASS Code Validation**: Wrong PASS = wrong interface (not error, by design)
5. **Memory-Only Session**: JavaScript variables cleared on tab close
6. **No Cookies/LocalStorage**: Zero persistence in browser
7. **Audit Trail**: Logs show authentication attempts (not nsec values)

## Resources

- [W3C DID 1.0 Specification](https://www.w3.org/TR/did-1.0/)
- [NOSTR Protocol](https://github.com/nostr-protocol/nostr)
- [Shamir Secret Sharing](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing)
- [G1 Currency](https://duniter.org/)
- [IPFS Documentation](https://docs.ipfs.io/)

## License

AGPL-3.0 - See LICENSE file for details

## Contact

For support or questions about the MULTIPASS system:
- Email: support@qo-op.com
- UPlanet Network: Visit your local Astroport

---

**Remember**: Your MULTIPASS is your universal decentralized identity. Treat your SSSS QR code like a physical key - keep it safe, but know that with PASS `0000`, you can always destroy and regenerate it if needed.

