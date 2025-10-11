# DID (Decentralized Identifier) Implementation in make_NOSTRCARD.sh

## Overview

The `make_NOSTRCARD.sh` script now generates W3C-compliant DID (Decentralized Identifier) documents following the [W3C DID 1.0 specification](https://www.w3.org/TR/did-1.0/).

## What is a DID?

A DID (Decentralized Identifier) is a new type of identifier that enables verifiable, decentralized digital identity. DIDs are:
- **Decentralized**: No central authority required
- **Cryptographically verifiable**: Secured by public/private key cryptography
- **Persistent**: Not dependent on any centralized registry
- **Interoperable**: Work across different systems and platforms

## Implementation Details

### DID Method: `did:nostr:`

We use a custom DID method `did:nostr:` based on the NOSTR protocol's hexadecimal public key:

```
did:nostr:{HEX_PUBLIC_KEY}
```

Example: `did:nostr:a1b2c3d4e5f6...`

### DID Document Structure

The generated DID document includes:

#### 1. **Identity Information**
- Main DID identifier (`did:nostr:{HEX}`)
- Alternative identifiers (`alsoKnownAs`):
  - Email address
  - G1/Duniter identifier
  - IPNS storage location

#### 2. **Verification Methods**
Four cryptographic keys for different purposes:

- **NOSTR Key**: Ed25519 key for NOSTR protocol authentication
- **G1/Duniter Key**: Ed25519 key for Duniter/G1 blockchain
- **Bitcoin Key**: ECDSA Secp256k1 key for Bitcoin transactions
- **Monero Key**: Monero-specific cryptographic key

#### 3. **Authentication & Authorization**
- `authentication`: Keys that can authenticate as this DID
- `assertionMethod`: Keys that can create verifiable credentials
- `keyAgreement`: Keys for encrypted communication

#### 4. **Service Endpoints**
Decentralized services associated with this identity:

- **NOSTR Relay**: Primary NOSTR protocol endpoint
- **uDRIVE**: Personal cloud storage and app platform
- **uSPOT**: UPlanet wallet and credential service

#### 5. **Metadata**
Additional information about the identity:
- Creation/update timestamps
- UPlanet affiliation
- Geographic coordinates
- Language preference
- User handle

## File Locations

When running `make_NOSTRCARD.sh` for an email address, the following DID-related files are created:

```
~/.zen/game/nostr/{EMAIL}/
├── did.json                                    # Main DID document (root access)
└── APP/
    └── uDRIVE/
        └── .well-known/
            └── did.json                        # Standard W3C DID resolution endpoint (copy)
```

**Note**: Both files contain identical DID documents. The file is created once at the root level and then copied to the `.well-known` directory for W3C standards compliance.

## DID Resolution

The DID document is accessible at **two locations** for maximum compatibility:

### 1. Direct Root Access
```
{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/did.json
```
**Purpose**: Quick direct access to the DID document at the user's root IPNS directory.

**Example**:
```
http://127.0.0.1:8080/ipns/k51qzi5uqu5dgy..../user@example.com/did.json
https://ipfs.copylaradio.com/ipns/k51qzi5uqu5dgy..../user@example.com/did.json
```

### 2. Standard W3C .well-known Path
```
{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/APP/uDRIVE/.well-known/did.json
```
**Purpose**: Follows the W3C `.well-known` convention for DID resolution, making it compatible with standard DID resolvers and discovery tools.

**Example**:
```
http://127.0.0.1:8080/ipns/k51qzi5uqu5dgy..../user@example.com/APP/uDRIVE/.well-known/did.json
https://ipfs.copylaradio.com/ipns/k51qzi5uqu5dgy..../user@example.com/APP/uDRIVE/.well-known/did.json
```

### 3. Resolution Strategy
Both locations contain the **same DID document**. The dual-location approach ensures:
- ✅ **Compatibility** with W3C standards (`.well-known` path)
- ✅ **Simplicity** for direct access (root path)
- ✅ **Discoverability** by automated DID resolvers
- ✅ **Flexibility** for different use cases

## Integration with NOSTR

The DID is integrated into the NOSTR ecosystem in several ways:

### 1. Profile Description
The DID identifier is included in the NOSTR profile description:
```
DID: did:nostr:{HEX}
```

### 2. NOSTR Events
NOSTR events include the DID as a tag:
```json
{
  "tags": [
    ["p", "{HEX_PUBLIC_KEY}"],
    ["i", "did:nostr:{HEX}"]
  ]
}
```

### 3. Welcome Message
The initial NOSTR message includes:
- DID identifier (`did:nostr:{HEX}`)
- Direct link to the DID document (`{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/did.json`)
- QR codes for wallet and identity access

## Example DID Document

```json
{
  "@context": [
    "https://www.w3.org/ns/did/v1",
    "https://w3id.org/security/suites/ed25519-2020/v1",
    "https://w3id.org/security/suites/x25519-2020/v1"
  ],
  "id": "did:nostr:a1b2c3d4...",
  "alsoKnownAs": [
    "mailto:user@example.com",
    "did:g1:AbCdEf123...",
    "ipns://QmXyz..."
  ],
  "verificationMethod": [
    {
      "id": "did:nostr:a1b2c3d4...#nostr-key",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:nostr:a1b2c3d4...",
      "publicKeyMultibase": "npub1...",
      "publicKeyHex": "a1b2c3d4..."
    },
    {
      "id": "did:nostr:a1b2c3d4...#g1-key",
      "type": "Ed25519VerificationKey2020",
      "controller": "did:nostr:a1b2c3d4...",
      "publicKeyBase58": "AbCdEf123...",
      "blockchainAccountId": "duniter:g1:AbCdEf123..."
    }
  ],
  "authentication": [
    "did:nostr:a1b2c3d4...#nostr-key",
    "did:nostr:a1b2c3d4...#g1-key"
  ],
  "service": [
    {
      "id": "did:nostr:a1b2c3d4...#nostr-relay",
      "type": "NostrRelay",
      "serviceEndpoint": "wss://relay.example.com"
    },
    {
      "id": "did:nostr:a1b2c3d4...#ipns-storage",
      "type": "DecentralizedWebNode",
      "serviceEndpoint": "https://ipfs.io/ipns/QmXyz..."
    }
  ]
}
```

## Usage

The DID document is automatically generated when creating a NOSTR card:

```bash
./make_NOSTRCARD.sh user@example.com picture.png 48.85 2.35
```

No additional parameters are needed. The script will:
1. Generate all cryptographic keys
2. Create the DID document
3. Publish it to IPNS
4. Include it in the NOSTR profile
5. Send it in the welcome message

## Benefits

### For Users
- **Single Identity**: One DID covers multiple blockchains and protocols
- **Verifiable**: Cryptographically provable identity
- **Portable**: Can be used across different platforms
- **Privacy-Preserving**: No centralized registry

### For Developers
- **Standard-Compliant**: Follows W3C specifications
- **Interoperable**: Works with other DID-compatible systems
- **Extensible**: Easy to add new verification methods or services
- **Discoverable**: Standard `.well-known` endpoint

## Security Considerations

1. **Key Management**: Private keys are never included in the DID document
2. **Access Control**: The `.secret.disco` file remains encrypted and protected
3. **SSSS Protection**: Secret sharing ensures key recovery without single point of failure
4. **Multiple Keys**: Different keys for different purposes (authentication, encryption, signing)

## Future Enhancements

Potential improvements:
- Add support for DID rotation/updates
- Implement DID delegation mechanisms
- Add verifiable credentials support
- Create DID resolution service
- Implement cross-chain identity linking

## Standards Compliance

This implementation follows:
- [W3C DID Core v1.0](https://www.w3.org/TR/did-core/)
- [W3C DID Specification Registries](https://www.w3.org/TR/did-spec-registries/)
- [Ed25519 Signature 2020](https://w3c-ccg.github.io/lds-ed25519-2020/)
- [NOSTR Protocol (NIP-01)](https://github.com/nostr-protocol/nips/blob/master/01.md)

## References

- [W3C DID 1.0 Specification](https://www.w3.org/TR/did-1.0/)
- [DID Method Registry](https://www.w3.org/TR/did-spec-registries/#did-methods)
- [NOSTR Protocol](https://github.com/nostr-protocol/nostr)
- [IPFS/IPNS Documentation](https://docs.ipfs.tech/)
- [Duniter/G1 Documentation](https://duniter.org/)

---

**Created**: October 2025  
**Last Updated**: October 2025  
**Maintainer**: UPlanet / Astroport.ONE Team

