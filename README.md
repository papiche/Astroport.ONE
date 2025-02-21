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

### Examples of API Usage

#### Create a Player

```http
GET /?salt=${SALT}&pepper=${PEPPER}&g1pub=${URLENCODEDURL}&email=${PLAYER}
```

#### Read GChange Database Messaging

```http
GET /?salt=${SALT}&pepper=${PEPPER}&messaging=on
```

#### Trigger a Ğ1 Payment

```http
GET /?salt=${SALT}&pepper=${PEPPER}&pay=1&g1pub=DsEx1pS33vzYZg4MroyBV9hCw98j1gtHEhwiZ5tK7ech
```

### UPLANET API Usage

The `UPLANET.sh` API is dedicated to OSM2IPFS and UPlanet Client App applications. It manages UPLANET landings and the creation of ZenCards and AstroIDs.

#### Required Parameters

- `uplanet`: Player's email.
- `zlat`: Latitude with 2 decimal places.
- `zlon`: Longitude with 2 decimal places.
- `g1pub`: (Optional) Origin language (fr, en, ...)

#### Example Request

```http
GET /?uplanet=player@example.com&zlat=48.85&zlon=2.35&g1pub=fr
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `uplanet` | `email`  | **Required**. Player's email       |
| `zlat`    | `decimal`| **Required**. Latitude with 2 decimal places |
| `zlon`    | `decimal`| **Required**. Longitude with 2 decimal places |
| `g1pub`   | `string` | **Optional**. Origin language (fr, en, ...) |

## DOCUMENTATION

https://astroport-1.gitbook.io/astroport.one/

## Contribution

This project is [a selection](https://github.com/papiche/Astroport.solo) of some of the most valuable free and open-source software.

Contributions are welcome on [opencollective.com/monnaie-libre](https://opencollective.com/monnaie-libre#category-BUDGET).

## Stargazers over time

[![Stargazers over time](https://starchart.cc/papiche/Astroport.ONE.svg)](https://starchart.cc/papiche/Astroport.ONE)

## Credits

Thank you to everyone who has contributed to making this software available to all. Do you know [Ğ1](https://monnaie-libre.fr)?

The best cryptocurrency you could dream of.

