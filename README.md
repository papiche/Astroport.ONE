# Introduction

[Astroport DEV Journal](https://pad.p2p.legal/s/AstroportDEVJournal#)

**Embark on a Cosmic Journey with AstroID & ZenCard System and Astroport.ONE**

Are you weary of the constraints of traditional payment systems and concerned about the reliability
of your distributed storage solutions? Look no further! Our revolutionary ZenCard QRCode based Payment System
and Astroport.ONE v1.0 seamlessly blend cutting-edge blockchain technology with interplanetary storage,
offering you a commission-free and secure solution.

**Astroport.ONE v1.0: Decentralized Storage Beyond Borders**

Astroport.ONE isn't just a distributed storage software; it's a reimagining of data management.
Utilizing IPFS and introducing a master boot record (MBR) and allocation table to Tiddlywiki data,
Astroport.ONE organizes information with unprecedented precision. In the UPlanet format system,
the planet is sliced into 0.01° segments, ensuring locally registered Tiddlers with unique signatures.

As a network engineer and system administrator committed to the Common Good, join us in constructing
Astroport.ONE and shaping the future of secure and reliable distributed storage.

**Station Extra-Terrestre Astroport.ONE: Where Innovation Meets Tranquility**

In the midst of this technological revolution, discover the Station Extra-Terrestre Astroport.ONE.
A haven for volunteers striving to live in peace and harmony within a spaceship turned garden,
it unveils a new "Jeu de Société" developed by and for the Astronauts of MadeInZion.

Embark on an exploration of "Voeux," wishes funded collaboratively through donations in the Libre currency G1.
These wishes encapsulate ideas, plans, explanations, and even mistakes, marking the journey toward their realization.

In this digital game manifesting in real life, your digital identity is in your hands, and a new Internet unfolds,
built according to our "Toiles de confiance" (Webs of Trust)!

Join us in this cosmic journey where peace, harmony, and the spirit of exploration reign supreme.
Send your love to the Extraordinary Earthlings at https://qo-op.com.

Welcome to a universe where wishes become reality, and the possibilities are boundless.

[BASH ENGINE FOR A CRYPTO PLAYGROUND](https://pad.p2p.legal/p/G1Fablab#)

## https://astroport.com

With this technology, we each become host and access provider and media sovereign.

**Astroport ONE propels a digital world of interconnected trust webs**.

# Astroport.ONE
Each "Astroport.ONE" station is a digital embassy that communicates and synchronizes with its peers.
Users can "move their account". The last one used during the day becomes the "official station".

The architecture attached to each public key is deployed in the form of "flower petals" according to the circles of trust Ŋ1 and Ŋ2 and the data flows produced by the derived keys.

![N.ONE.2](https://www.copylaradio.com/web/image/6038/ASTROPORT_multiWoTNet.png)

ASTROBOT "Intelligent contract in BASH"
Programs are triggered by "G1Tag" (derived keys) ensures extraction of "G1WordClefs" from "surrounding" Tiddlers.

To trigger the execution of a "personal intelligent contract", simply create a "wish" (Tag=voeu)
At this point, if it exists "ASTROBOT/G1Tag.sh" program will publish the data relating to the Tag concerned on a new "personal IPNS derived key", if not a default "json from all with same wish" is created (see RUNTIME/VOEUX.refresh.sh)

# INSTALLATION (Linux Mint / Ubuntu / DEBIAN)

Tested on "Linux Mint" (Debian like distro compatible), the **hacker way for using & buidling new blockchain services** ...

INSTALL COMMAND

```
bash <(wget -qO- https://raw.githubusercontent.com/papiche/Astroport.ONE/master/install.sh)

```

> TODO: MORE MODULAR INSTALL.
> CREATE adventure explaining it

## DRAGONS WOT

Once you install Astroport.ONE...

If all has gone well, you should find these processes running...

```
/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesys-pubsub
/bin/bash /home/fred/.zen/G1BILLET/G1BILLETS.sh daemon
 \_ /bin/bash /home/fred/.zen/G1BILLET/G1BILLETS.sh daemon
   \_ nc -l -p 33101 -q 1
/bin/bash /home/fred/.zen/Astroport.ONE/12345.sh
 \_ /bin/bash /home/fred/.zen/Astroport.ONE/12345.sh
   \_ nc -l -p 1234 -q 1
/bin/bash /home/fred/.zen/Astroport.ONE/_12345.sh
 \_ nc -l -p 12345 -q 1

```

> Become Official REGIONAL Station
> - follow "PGP/SSH/IPFSNODEID" linking procedure -
> https://pad.p2p.legal/keygen


# DESKTOP

After installation, you should have 3 new shortcuts on your desktop

* Astroport", which opens your station portal: http://astroport.localhost:1234
* REC" allows you to save your files on IPFS and publish their Capusle in your TW.
* G1BILLET" lets you create ZenCards and other useful QRCodes

NB : If you use "Nemo" as file manager. You can "ipfs add" any file (with no space in file name) by right click it.

> TODO : detect OS and FILE MANAGER to adapt desktop linking and right clic action

## How to manage your "Astroport"!

You need to create a "PLAYER".
It is defined by email, salt, pepper, lat, lon and PASS

```
~/.zen/Astroport.ONE/command.sh
```
Browse available functions

A Station can host multiple "PLAYERs and TiddlyWikis".

---

# "BASH API" : "♥BOX"
## http://astroport.localhost:1234

Once your Astroport Station is started:
* port 1234 publishes API (REPONSE PORT TCP 45780 45781 ( up to ... 45790 )
* port 12345 publishes MAP(*) (ESSAIM MAP - BOOSTRAP / STATIONS)
* port 33101 publishes G1BILLETS (REPLY TCP PORT 33102)
* port 8080, 4001 and 5001 are IPFS gateway ports.

List of ports to activate.

![](https://ipfs.asycn.io/ipfs/QmWzwL9fZKDGuqsvDjkA8v9sAcU4zQ4BvjKDRwnZQBT97y)

To add your Station to our swarm, enter the IP of your BOX in the file ``~/.zen/♥Box ````.

exemple
```
frd@scorpio:~ $ cat ~/.zen/♥Box
86.210.184.173

```

⚠ API ASTROPORT = NETCAT SYSTEM ⚠

**Astroport doesn't need a web server to work**. We use the simplest network tool, **netcat**.
Operation gives access to an "API BASH" (classified by the same name as the first GET parameter received in the API directory).

Requests are made in HTTP GET on port 1234, with the response PORT in the loaded page.
Perform a regexp on "url=ADRESSE:PORT" or (♥‿‿♥) to find out which.

Here are some examples of how to do it.

## ANSWER PORT RECOVERY API : (♥‿‿♥)
### CLI (BASH)
```
    # OPEN ASTROPORT HOME PAGE
    curl -so ~/.zen/tmp/${MOATS}/astro.port "http://astroport.localhost:1234/?salt=0&pepper=0&g1pub=_URL_&email=${EMAIL}"

    # GREP NEXT PORT IN PAGE CODE
    TELETUBE=$(cat ~/.zen/tmp/${MOATS}/astro.port | grep "(♥‿‿♥)" | cut -d ':' -f 2 | cut -d '/' -f 3)
    TELEPORT=$(cat ~/.zen/tmp/${MOATS}/astro.port | grep "(♥‿‿♥)" | cut -d ':' -f 3 | cut -d '"' -f 1)

                sleep 30

    # ACCESS TO FINAL RESULT
    curl -so ~/.zen/tmp/${MOATS}/astro.rep "http://$TELETUBE:$TELEPORT"
```
### JS

Exemple :
```
var myURL = 'http://astroport.localhost:1234/?' + query;
async function fetchAstroport(myURL) {
      try {

         let one = await fetch(myURL); // Gets a promise
         var doc =  await one.text();
         var regex = /url='([^']+)/i; // Get response PORT
         var redirectURL = doc.match(regex)[1]

         console.log(redirectURL)

        setTimeout(function() {
                // let two = await fetch(redirectURL);
                // document.mydiv.innerHTML = await two.text(); // Replaces body with response
                window.open( redirectURL, "AstroTab");
        }, 5000);

      } catch (err) {
        console.log('Fetch error:' + err); // Error handling
      }
    }
```

USE "[astro.js](templates/ZenStation/G1PalPay_fichiers/astro.js)"
```
    <script src="https://ipfs.asycn.io/ipfs/Qmae5v9zydax9u6C9ceDijURu5PYdd5avmv4NkenCw7RFv/astro.js"></script>
```

## ➤ SALT API
### ```/?salt=${SALT}&pepper=${PEPPER}&${APPNAME}=${WHAT}&${OBJ}=${VAL}...```

### Créer (ou téléporter) un PLAYER TW : OFFICIAL <3BOX :
```http
GET /?salt=${SALT}&pepper=${PEPPER}&g1pub=${URLENCODEDURL}&email=${PLAYER}
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `g1pub` | `string` | **Required**. Your prefered _URL_ to copy video from |
| `email` | `email` | **Required**. Your email token |

### LOGOUT PLAYER (remove IPNS keys from Station)
```http
GET /?salt=${SALT}&pepper=${PEPPER}&logout=${PLAYER}
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `logout` | `string` | **Required**. Your email token  |

### LOGIN PLAYER (Activate IPNS keys on Station)
```http
GET /?salt=${SALT}&pepper=${PEPPER}&login=${PLAYER}
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `login` | `string` | **Required**. Your email token  |

### Définir le niveau ★ accordé à un "g1friend"
```http
GET /?salt=${SALT}&pepper=${PEPPER}&friend=${G1PUB}&stars=${1:5}
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `friend` | `string` | **Required**. G1PUB token of friend |
| `stars` | `number` | **Required**. Number between 1 to 5 |


### Lire Messagerie de la base "GChange"
```http
GET /?salt=${SALT}&pepper=${PEPPER}&messaging=on
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `messaging` | `string` | **Required**. (on=json) output type |

### Conversion vers adresse IPNS
```http
GET /?salt=${SALT}&pepper=${PEPPER}&getipns=on
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `getipns` | `string` | **Required** on |

### AppName=testcraft : Enregistrer JSON
```http
GET /?salt=${SALT}&pepper=${PEPPER}&testcraft=json&nodeid=_&dataid=$QRHASH
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `testcraft` | `string` | **Required** AppNAME subcommand |
| `${OBJ}` | `${VAL}` | depends on App |

This IPFS object transfer needs that the client is using well configured WebRTC/IPFS relays
Look for example in ```www/upload_to_astroport.html```

```
    '/dns4/wrtc-star1.par.dwebops.pub/tcp/443/wss/p2p-webrtc-star',
    '/dns4/wrtc-star2.sjc.dwebops.pub/tcp/443/wss/p2p-webrtc-star'
```

###  Redirections
* vers Gchange

```/?salt=${SALT}&pepper=${PEPPER}&g1pub=on```

* vers TW

```/?salt=${SALT}&pepper=${PEPPER}&g1pub=astro```

###  Déclencher un Payement de Ğ1 à une G1PUB
```http
GET /?salt=${SALT}&pepper=${PEPPER}&pay=1&g1pub=DsEx1pS33vzYZg4MroyBV9hCw98j1gtHEhwiZ5tK7ech
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `pay` | `integer` | **Required** G1 AMOUNT |
| `g1pub` | `G1PUB` |  **Required**  destination "wallet key" |

## ➤ PLAYER (works only on LAN Station)
### ```/?player=${PLAYER}&${APPNAME}=${WHAT}&${OBJ}=${VAL}...```

###  Exporter Tiddlers.json depuis son TW selon valeur des "tags" ( ici TAG=G1CopierYoutube)
```http
GET /?player=${PLAYER}&moa=json&tag=G1CopierYoutube
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `player` | `string` | **Required**. Your EMAIL token |
| `moa` | `string` | **Required** APP = output format |
| `tag` | `${VAL}` | TW filtering default G1CopierYoutube |

> CAN BE EXTENDED

## ➤ AMZQR : Create a QRCode with "amzqr"
```http
GET /?amzqr=${URLENCODEDSTRING}&logo=${IMAGE}```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `amzqr` | `string` | **Required** the qrcode string |
| `logo` | `string` | **Required** ./images/${IMAGE}.png |

check available "logo.png" in [./images](./images)

## ➤ UPLANET : Create Umap, AstroID & ZenCard for PLAYER (email)
```http
GET /?uplanet=${PLAYER}&zlat=${LAT}&zlon=${LON}&g1pub=${PASS}```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `uplanet` | `email` | **Required** Your EMAIL token |
| `zlat` | `decimal` | **Required** LATITUDE with 2 decimals digits |
| `zlon` | `decimal` | **Required** LONGITUDE with 2 decimals digits |
| `g1pub` | `string` | **Facultative** choose Umap AstroID PASS |

Create à Umap key (LAT/LON), then a PLAYER TW with GPS as Umap IPNS reference
This API is used by OSM2IPFS code.

* [UPlanet Entrance](https://qo-op.com)

### ➤ QRCODE (API SandBox)
```http
GET /?qrcode=${G1PUB} | ${ASTRONAUTENS} | ${PGP_ASTROID_STRING}
```
| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `qrcode` | `string` | **Required**. Your G1PUB or ASTRONAUTENS or PGP_ASTROID token |

> Look for details & extend as you like in [~/.zen/Astroport.ONE/API/QRCODE.sh](API/QRCODE.sh)

## The Art of key derivation, chaining & use

In order to make (a little) clear how we use cryptography,

We choose to use "NaCl" (secret1 / secret) 2 key generation, so it is easy to understand Web3 mechanism.

**(SECRET1/SECRET2) mixing**

* If PLAYER key is (SECRET1 / SECRET2) and G1PUB and EMAIL + TW
    * feed key (SECRET1 / SECRET2 G1PUB)
    * wishes keys are (SECRET2 / WishName EMAIL)
        * sub-wishes are (EMAIL / G1WishName G1PUB)
            * wish-billets are (EMAIL_dice_words / G1WishName G1PUB)

This way PLAYER TW capable of retrieving and never loose its data.
It is writen into IPFS... So recreate the key anywhere makes you get your data from friends you shared it with.

**Cross (G1PUB) keys**

Between PlayerA (AG1PUB) & PlayerB (BG1PUB) obvious communication channel keys are existing :

(AG1PUB / AG1PUB) - A knock on the door
(AG1PUB / BG1PUB) - From A to B channel
(BG1PUB / AG1PUB) - From B to A channel
(BG1PUB / BG1PUB) - B knock on the door

We can use this to implement protocols, for exemple :
To ollow PlayerA / PlayerB to become friends

A write a KNOCK.AG1PUB file + signature using (BG1PUB / BG1PUB) keygen IPNS key,
Then B reply with the same KNOCK at (AG1PUB / AG1PUB) address

A/B - B/A keys can be used as bidirectionnal encrypted data channels.

In a well formed IPFS swarm, we could even send video... Check code in ```/tools/streaming/```


**(LON / LAT) keys**

NaCl keys can be initiated with GPS Geoloc and receive shared informations.
Using the same A/B swapping method, any A place have also a communication channel with B place ;)

**(COUNTRY / ZIP) keys**

For a town key, we could use country code + ZIP code, ... etc
Many public application can be easily addressed like that

As these keys are discoverable, the channel can be hijacked by anyone.
So ASTROBOT while applying ScuttleButt replications will ".chain.ts" data and check for protocol respect.

Data can't be lost, but protocol chain can be break !
In case of some annoyance, we can monitor IPFS protocol to identify which IPFSNODEID key is acting badly and apply reaction based on DEFCON level (look into astrXbian code)

### MAILJET & GPS

In order for "Boostrap Station" to send emails to PLAYERs, we use [mailjet service](https://mailjet.com/).

```
## CREDENTIALS FILE
~/.zen/MJ_APIKEY
# IS USED BY
~/.zen/Astroport.ONE/tools/mailjet.sh
```

Boostrap location is specified in ~/.zen/GPS

```
cat ~/.zen/GPS
48.87039, 2.31673

```

### LOW RESSOURCE STATION CAN ACTIVATE LOW MODE (disable ipfs daemon)
```
~/.zen/Astroport.ONE/tools/cron_VRFY.sh LOW

sudo systemctl restart astroport.service
sudo systemctl restart g1billet.service

```

### STATION : Show Station PLAYER's G1 investments levels
```http
GET /?qrcode=station
```

### STATION MAP & PLAYER DATA PROPAGATION

Chaque Station collecte et publie sur sa clef "self" (/ipns/$IPFSNODEID) les liens vers le cache de l'ensemble de l'essaim
http://localhost:12345 renvoi un json

```
{
    "created" : "202304111854481040",
    "hostname" : "kitty.localhost",
    "myIP" : "192.168.1.14",
    "ipfsnodeid" : "12D3KooWK1ACupF7RD3MNvkBFU9Z6fX11pKRAR99WDzEUiYp5t8j",
    "astroport" : "http://192.168.1.14:1234",
    "g1station" : "http://ipfs.localhost:8080/ipns/12D3KooWK1ACupF7RD3MNvkBFU9Z6fX11pKRAR99WDzEUiYp5t8j",
    "g1swarm" : "http://ipfs.localhost:8080/ipns/k51qzi5uqu5djv0qz9wkl8i94opzm62csh56mnp9zove8i543e4vv4cy9gvr1o"
}

```
| Parameter | Description     |
| :-------- | :------- |
| created | date de creation du document |
| hostname | nom de la station |
| myIP | adresse IP de la station |
| ipfsnodeid | Clef publique, balise de la station |
| astroport | Lien vers l'API de la station |
| g1station | Lien vers la carte PLAYER de la Station |
| g1swarm | Lien vers la carte des cartes des Stations de l'essaim |

Afin de propager la carte chaque station lors de son raffraichissement de cache
 envoi aux Boostrap une requête pour upload (```/ipns/${IPFSNODEID}```)
```
STATION MAP UPSYNC : http://$nodeip:12345/?${GNODEID}=${IPFSNODEID}
```


# 20H12

Chaque jour, les ASTROBOTs captent les :star: de leurs PLAYERs puis exécutent le protocole de synchronisation Ŋ1

[20H12.sh](/qo-op/Astroport.ONE/src/branch/master/20h12.sh)

Ils analysent les données et extraient des flux json selon les G1Voeu présent dans chaque TW.

Le niveau informationnel de confiance exploré permet de proposer des alertes issues du niveau Ŋ2.

## EXEMPLE DE FLUX TW :

[![TW FEEDS](https://ipfs.copylaradio.com/ipfs/Qma9zvrYHGcUPisLKBcG9U9sktThX5VfVci8jfM8D9RspT)](https://pad.p2p.legal/s/G1TWFeed#)


# IPFS : UN STOCKAGE INALTERABLE ET INTELLIGENT

[![](https://ipfs.asycn.io/ipfs/QmafsWdAeB5W9HcNPQWK2yjTgcW8eTxHoSD7bzE55mtrdP)

### "The Barefoot Architect" de Johan Van Lengen.

Lignes de commandes

```
ipfs ls Qme6a6RscGHTg4e1XsRrpRoNbfA6yojC6XNCBrS8nPSEox/
ipfs cat QmbfVUAyX6hsxTMAZY7MhvUmB3AkfLS7KqWihjGfu327yG > /tmp/vdoc.pub_the-barefoot-architect.pdf && xdg-open /tmp/vdoc.pub_the-barefoot-architect.pdf
```
Après un passage par [ajouter_media.sh](/qo-op/Astroport.ONE/src/branch/master/ajouter_media.sh)

Les données sont stockées [dans des Tiddlers](https://ipfs.copylaradio.com/ipns/k51qzi5uqu5dgobi9ozzzvdftqfd3hd7a1488nzymky1edz8j779jov7sbemc0#Foret_Enchantee-PROJET_ASTROPORT)

### Foret Enchantée - PROJET ASTROPORT.pdf

https://ipfs.copylaradio.com/ipfs/QmUtGpGeMZvwp47ftqebVmoFWCmvroy5wEtWsKvWvDWJpR

---

## SIMULATIONS LOOPY

> [Simulateur Astronaute/Voeux](https://ncase.me/loopy/v1.1/?data=[[[3,646,229,0.5,%22Astronaute%22,5],[4,806,372,0.16,%22G1Voeu%22,3],[5,449,133,0.83,%22G1Talent%22,1],[6,928,124,0.5,%22Astronaute%22,0],[7,1055,293,0.5,%22Astronaute%22,0],[8,883,587,0.5,%22Astronaute%22,0],[10,691,54,0.5,%22G1Voeu%22,3]],[[3,5,82,1,0],[3,4,-87,1,0],[6,4,83,1,0],[4,5,176,1,0],[8,8,85,1,12],[8,4,-45,1,0],[7,4,34,1,0],[5,3,49,1,0],[7,7,101,1,225],[6,6,113,1,-84],[3,3,90,1,75],[5,4,-293,1,0],[3,10,34,1,0]],[],10%5D)

> [Essaim Astroport.ONE](https://ncase.me/loopy/v1.1/?data=[[[1,419,351,1,%22Astroport.ONE%22,3],[2,506,530,1,%22Terrien%22,5],[3,499,95,1,%22IPFS%22,1],[4,272,225,1,%22Astroport.ONE%22,3],[5,620,297,0.16,%22Astroport.ONE%22,4],[7,927,69,0.66,%22Astroport.ONE%22,3],[8,798,175,0.66,%22Astroport.ONE%22,3]],[[2,1,94,-1,0],[1,2,89,1,0],[2,5,-122,1,0],[5,3,58,1,0],[3,5,25,1,0],[4,3,117,1,0],[3,4,-152,1,0],[1,3,60,1,0],[3,1,-18,1,0],[7,3,-44,1,0],[3,7,15,1,0],[8,3,37,1,0],[3,8,-47,1,0]],[[798,557,%22https%253A%252F%252Fipfs.copylaradio.com%253A1234%250A(salt%2520%252F%2520pepper%2520%252F%2520email)%2520%253D%2520TW%2520%252B%2520AstroBot%2520API%22],[256,141,%22Station%2520Officielle%250A(Bootstrap%2520%252B%2520RoundRobin%2520DNS)%22],[868,332,%22D%25C3%25A9l%25C3%25A9gation%2520de%2520clef%250A(Tiers%2520de%2520confiance)%22]],9%5D)


## Stargazers over time

[![Stargazers over time](https://starchart.cc/papiche/Astroport.ONE.svg)](https://starchart.cc/papiche/Astroport.ONE)

## CREDITS

This "digital art" structure is a selection of some of the most valuable Free & OpenSource Software I ever had in my hand.
Credits is going to all the kindness and care provided to make valuable and secure software available for all

Did you ever dring a beer bought in G1 ?

You can pay me a beer or more by contributing to our OpenCollective
https://opencollective.com/monnaie-libre#category-ABOUT

## IPFS Ecosystem Directory Submission Form
https://airtable.com/appLWiIrg9SQaEtEq/shrjwvk9pAeAk0Ci7
