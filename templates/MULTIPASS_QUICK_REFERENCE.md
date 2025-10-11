# 🎫 MULTIPASS Quick Reference Card

## What is a MULTIPASS?

Your **MULTIPASS** is your universal decentralized identity card. It gives you:
- ✅ A NOSTR social identity (npub/nsec)
- ✅ Cryptocurrency wallets (G1, Bitcoin, Monero)
- ✅ Personal cloud storage (uDRIVE)
- ✅ Access from any UPlanet terminal worldwide

## Your QR Codes

### 1. 🔑 SSSS Key (Secret)
**Keep this safe!** This is your master authentication key.
- Print it and keep it secure
- Use it to login from any terminal
- Combined with PASS codes for different access levels

### 2. 👛 G1 Wallet QR
Your public G1/Duniter wallet address
- Share this to receive payments
- Scan to check your balance

### 3. 💾 uDRIVE QR
Direct access to your personal cloud storage
- Scan to access your files
- Upload photos, documents, apps

### 4. 👤 Profile QR
Your NOSTR profile viewer
- Share this to show your social profile
- Others can follow you on NOSTR

## PASS Codes

When you scan your **SSSS Key**, you can enter a 4-digit PASS code:

| PASS | What it does | When to use |
|------|--------------|-------------|
| _(none)_ | **Quick Message** - Simple NOSTR messaging | Public terminals, quick tasks |
| `0000` | **Resiliation** - Cancel your MULTIPASS | Lost device, stolen key |
| `1111` | **Full Access** - Opens astro messenger interface | Trusted terminals, your devices |
| `2222` | **N² Network** - Visualize your social graph | View connections, explore network |
| `xxxx` | **New Application** - Activate delegated tasks to your MULTIPASS | more to come... |

## How to Use Your MULTIPASS

### Everyday Login (PASS 1111)
1. Go to any UPlanet terminal
2. Scan your **SSSS Key QR code**
3. Enter PASS code: `1111`
4. ✨ Full access granted - Your nsec is ready!

### Emergency Recovery (PASS 0000)
1. If you lost everything, don't panic!
2. Go to any UPlanet terminal
3. Scan your **SSSS Key QR code** (from printed backup)
4. Enter PASS code: `0000`
5. ✨ New MULTIPASS created with same identity!
6. Check your email for new credentials

### Quick Message (No PASS)
1. Need to send a quick NOSTR note?
2. Scan your **SSSS Key QR code**
3. Press Enter (don't enter PASS)
4. ✨ Simple interface opens

## Security Tips

### ✅ DO
- ✅ Print your SSSS QR code on paper
- ✅ Store it somewhere safe (like a passport)
- ✅ Use PASS 1111 only on trusted devices
- ✅ Remember your PASS codes
- ✅ Log out when done (close browser tab)

### ❌ DON'T
- ❌ Never share your SSSS QR code online
- ❌ Don't save PASS codes on your phone
- ❌ Don't use PASS 1111 on public computers
- ❌ Never screenshot your nsec key
- ❌ Don't leave terminals unattended while logged in

## Important Features

### 🔒 Zero Browser Storage
- Your nsec is **never** saved in the browser
- Everything erases when you close the tab
- Re-scan your SSSS QR to reconnect
- This protects you from hacks and malware

### 🌍 Works Anywhere
- Any UPlanet Astroport worldwide
- Any computer with internet
- No app installation needed
- Just your SSSS QR code

### 💾 Personal Cloud (uDRIVE)
- Unlimited IPFS storage
- Upload from web or API
- Share files via IPFS links
- Persistent across sessions

### 🔗 Blockchain Integration
- NOSTR for social networking
- G1 for currency transactions
- Bitcoin & Monero addresses included
- DID document for interoperability

## Your MULTIPASS Info

```
Email:         _________________@_________________
Created:       _____ / _____ / _____
UPlanet:       ____________________
Location:      Lat: ________  Lon: ________

NOSTR (npub):  npub1_________________________
G1 Wallet:     _________________________________
IPNS Vault:    /ipns/k51qzi5uqu5d_____________

DID:           did:nostr:_____________________
```

## Access Your Services

### Check Balance
```
{uSPOT}/check_balance?g1pub={your_email}
```

### Access uDRIVE
```
{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/APP/uDRIVE
```

### View DID Document
```
{myIPFS}/ipns/{NOSTRNS}/{EMAIL}/did.json
```

### NOSTR Relay
```
wss://relay.copylaradio.com
```

## Troubleshooting

### "Existing MULTIPASS" error?
→ You already have one! Use PASS 0000 to regenerate if needed.

### "Bad PASS" error?
→ Check your PASS code. Re-scan QR if corrupted.

### nsec not filling automatically?
→ Refresh page, or use default (no PASS) to verify SSSS works.

### Lost your SSSS QR?
→ If printed backup is lost, contact your UPlanet operator.
→ Use PASS 0000 on any terminal if you have access.

## Need Help?

- 📧 Email: support@qo-op.com
- 🌐 Visit your local UPlanet Astroport
- 📖 Full docs: MULTIPASS_SYSTEM.md

---

**🎫 Welcome to the decentralized future!**

Your MULTIPASS is more than a login - it's your sovereign digital identity. No company owns it. No government controls it. It's yours, forever.

**Print this card and keep it with your SSSS QR code!**

