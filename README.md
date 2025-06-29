# Astroport.ONE: Your Decentralized Portal to a New Digital Frontier

[FR](README.fr.md) - [ES](README.es.md)

**Welcome to Astroport.ONE!** Imagine a digital world where you are in control, where data is secure, payments are seamless, and community thrives beyond borders. Astroport.ONE is building this future, and you are invited to be a part of it.

**What is Astroport.ONE?**

Astroport.ONE is a revolutionary platform designed to empower individuals and communities in the Web3 era. It's more than just software; it's a toolkit for creating your own decentralized digital embassy - a **Station** - where you can manage your digital identity, participate in a decentralized economy using the Ğ1 (June) cryptocurrency, and contribute to a global network of interconnected stations.

**Think of Astroport.ONE as:**

*   **Your Personal Data Haven:** Store and manage your data securely thanks to the InterPlanetary File System (IPFS), ensuring it is censorship-resistant and always accessible.
*   **A Commission-Free Payment System:** Use the Ğ1 (June) cryptocurrency for peer-to-peer transactions without intermediaries or fees, fostering a fair and equitable economy.
*   **A Digital Community Builder:** Connect with other Astroport.ONE Stations and users worldwide, sharing information, resources, and building trust-based networks.
*   **A "Construction Guide" for the Decentralized Web:** Leverage our open-source tools and software to create and deploy your own Web3 applications and services.

## Essential Features: The Power of Astroport.ONE

*   **ZenCard and AstroID: Your Access Keys**

    *   **ZenCard**: An innovative payment system based on the simplicity and security of QR Codes.
    *   **AstroID**: Your digital identity, inviolable and under your complete control.

*   **Decentralized and Organized Storage**

    *   **IPFS at its Core**: Benefit from distributed storage, resistant to censorship and centralized failures.
    *   **MBR and Allocation Table**: A Tiddlywiki data organization optimized for performance and reliability.

*   **Vœux: The Keywords that Animate AstroBot**

    *   **Vœux System**: More than just wishes, "Vœux" (Vows) are keywords that *you* define in your TiddlyWiki to trigger **AstroBot**, the automated heart of Astroport.ONE. These keywords activate BASH programs, rudimentary smart contracts, that allow you to automate actions, synchronize data, or perform specific tasks within your station. While Vœux can be supported by donations in the Ğ1 free currency, their primary function is to orchestrate automation via AstroBOT, not collaborative funding.

*   **Synchronization and P2P Communication**

    *   **Astroport.ONE Stations**: Your station communicates and synchronizes with a network of digital embassies, ensuring maximum data consistency and availability.
    *   **AstroBot: Intelligence Serving Your Data**: A system of smart contracts in BASH, reacting to events on the Ğ1 network and to "Vœux" to automate and optimize your experience.
    *   **G1PalPay.sh: The Ğ1 Transaction Monitor**: A crucial script that monitors the Ğ1 blockchain in real-time. It allows Astroport.ONE to react to transactions, execute commands based on transaction comments, and manage financial flows within the ecosystem.

## **Who is Astroport.ONE For?**

*   **Individuals seeking digital sovereignty:** Take back control of your data and your online presence.
*   **Communities building decentralized solutions:** Create and manage shared resources and collaborative projects.
*   **Developers and innovators:** Explore the potential of Web3 and build decentralized applications on a robust platform.
*   **Users of the Ğ1 (June) cryptocurrency:** Enhance your Ğ1 experience with secure payments and a thriving ecosystem.
*   **Anyone interested in a freer, safer, and more interconnected digital world.**

## **Get Started with Astroport.ONE:**

**Installation (Linux - Debian/Ubuntu/Mint):**

Setting up your Astroport.ONE Station is easy thanks to our automated installation script:

```bash
bash <(curl -sL https://install.astroport.com)
```

### Running Processes

After installation, you should find the following processes running:

```
/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesys-pubsub
/bin/bash /home/fred/.zen/G1BILLET/G1BILLETS.sh daemon
/bin/bash /home/fred/.zen/Astroport.ONE/12345.sh
/bin/bash /home/fred/.zen/Astroport.ONE/_12345.sh
```

with directories & files in ~/.zen
```
$ ls ~/.zen
Astroport.ONE  [♥Box]  G1BILLET  game  [GPS]  strfry  tmp  UPassport  workspace
```
♥Box contains real external IP for NATed LAN stations
GPS contains Captain account geo location, it is used as "sun time consensus" between ♥Box giving UMAP data priority to closest official relay.

## Usage

### Creating a Player

To create a player, define the following parameters: email, salt, pepper, lat, lon and PASS.

```bash
~/.zen/Astroport.ONE/command.sh
```

### BASH API

Once your Astroport station is started, the following ports are activated:

- **Port 1234**: Publishes API v1 (/45780, /45781 and /45782 are the response ports)
- **Port 12345**: Publishes the station map.
- **Port 33101**: Commands the creation of G1BILLETS (:33102 allows their retrieval)
- **Ports 8080, 4001 and 5001**: IPFS gateway ports.
- **Port 54321**: Publishes API v2 ([UPassport](https://github.com/papiche/UPassport/)).

![](./OpenPORTS.jpg)


### UPLANET API (Port 54321)

The UPLANET API, provided by UPassport, is a comprehensive interface for managing digital identity and multimedia content within the Astroport.ONE ecosystem. It runs on port 54321 and offers the following endpoints:

#### Core Endpoints

- **`/scan` or `/`**: Main terminal for QR code scanning and UPassport actions
- **`/nostr`**: NOSTR Card management and interactions
- **`/rec`**: OBS Studio recording control and multimedia processing
- **`/webcam`**: Direct webcam recording and processing
- **`/api/upload`**: File upload to IPFS with NIP authentification
- **`/uplanet`**: UPlanet account creation and management

#### UPLANET Account Creation

To create a UPLANET account, send a GET request with the following parameters:

```http
GET /?uplanet=${EMAIL}&zlat=${LATITUDE}&zlon=${LONGITUDE}&g1pub=${LANGUAGE}
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `uplanet` | `email`  | **Required**. Player's email       |
| `zlat`    | `decimal`| **Required**. Latitude with 2 decimal places |
| `zlon`    | `decimal`| **Required**. Longitude with 2 decimal places |
| `g1pub`   | `string` | **Optional**. Origin language (fr, en, ...) |

#### Features

- **Identity Management**: Create and manage UPassports with QR code scanning
- **Multimedia Processing**: Record and process video/audio content
- **IPFS Integration**: Decentralized storage for all content
- **NOSTR Integration**: Publish events and manage NOSTR Cards
- **Ğ1 Integration**: Check balances and process transactions

For more detailed information about the UPLANET API and its capabilities, visit the [UPassport documentation](https://github.com/papiche/UPassport/).


## proto DOCUMENTATION

https://astroport-1.gitbook.io/astroport.one/

## Contribution

FOSS Powered : This project is a selection of some of the most valuable free and open-source software.

By installing Astroport.ONE, you will appear on [UPlanet ORIGIN](https://ipfs.copylaradio.com/ipns/copylaradio) swarm map.

By activating Y level (SSH<->IPFS key twin) or Z level (PGP<->IPFS twins) you can join "UPlanet Ẑen"

> Become part of [Astroport #monnaie-libre](https://opencollective.com/monnaie-libre) DRAGON WoT 
maintained by [CopyLaRadio](https://copylaradio.com) : La coopérative des auto hébergeurs Web2 et Web3 

## Stargazers over time

[![Stargazers over time](https://starchart.cc/papiche/Astroport.ONE.svg)](https://starchart.cc/papiche/Astroport.ONE)

## Credits

Thank you to everyone who has contributed to making this software available to all. Do you know [Ğ1](https://monnaie-libre.fr)?

The best cryptocurrency you could dream of.

## Discover the 3 Main Usage Types

Astroport.ONE offers three main ways to join and benefit from the ecosystem. Each usage is explained in a dedicated Zine (flyer) for easy onboarding:

### 1. [🌐 MULTIPASS](templates/UPlanetZINE/day_/multipass.html)
**Your Digital Identity & AI Assistant**
- Access the decentralized NOSTR social network
- Get your secure digital identity (NOSTR Card)
- Enjoy a personal AI assistant (#BRO)
- 1 Ẑen per week

### 2. [☁️ ZENCARD](templates/UPlanetZINE/day_/zencard.html)
**Liberate Your Cloud & Smartphone**
- 128 GB private NextCloud storage
- Smartphone "de-googling" and digital detox
- All the benefits of MULTIPASS included
- 4 Ẑen per week

### 3. [⚡ CAPTAIN](templates/UPlanetZINE/day_/captain.html)
**Become a Node & Earn Ẑen**
- Transform your PC into a value node
- Join the CopyLaRadio cooperative
- Earn Ẑen by offering MULTIPASS and ZENCARD to others
- Full training and support

> 📄 Click each link to view or print the Zine flyer for that usage!

