# Préambule - [read this introduction in english](https://github.com/papiche/Astroport.ONE/blob/master/README.en.md) -
Quand pourrons nous sortir de ce Méchant Cloud qui nous profile, nous scrute, nous analyse... Pour au final nous faire consommer.
Je n'ai pas suivi la formation d’ingénieur réseau pour fabriquer ça!
Alors j'ai fait autre chose.

Astroport est contruit sur IPFS pour former nos Cloud personnels échangés entre amis d'amis à l’abri des algorithmes de l'IA et du datamining sauvage qui règne ici bas.
L'avantage de ce système, une consommation énergétique divisé par 100, une répartition des données qui permet de fonctionner déconnecté, un système d'information pair à pair inaltérable, inviolable.
S'il vous plaît arrêtons cet Internet Supermarché de nous même...
C'est une bibliothèque du savoir à la base.

## https://astroport.com

Avec cette technologie, nous devenons chacun hébergeur et fournisseur d'accès, souverain monétaire et médiatique.
Avec cette technologie, nous établissons le "Crypto Département 96" dont la carte relie les territoires au delà des frontières et des pays.

**Astroport ONE propulse un monde numérique fait de toiles confiances interconnectées**

# Astroport.ONE

Chaque Station "Astroport.ONE" est une ambassade numérique qui dialogue et se synchronise avec ses pairs.
Les utilisateurs peuvent "déplacer leur compte". La dernière utilisée dans la journée devient "station officielle".

L'architecture attachée à chaque clefs publiques se déploie et en forme de "pétales de fleur" selon les cercles de confiance Ŋ1 et Ŋ2.

Des clefs dérivées sont crées pour exporter et explorer les "G1MotsClefs" associés au Tiddlers.
A chaque copie le tiddlers reçoit une nouvelle signature et déclenche le processus "G1PalPay".


# INSTALLATION (Linux Mint / Ubuntu / DEBIAN)

```
# GIT.P2P.LEGAL

bash <(wget -qO- https://git.p2p.legal/qo-op/Astroport.ONE/raw/branch/master/install.sh)

# GITHHUB
bash <(wget -qO- https://raw.githubusercontent.com/papiche/Astroport.ONE/master/install.sh)


```

# LANCEMENT

## MODE AVENTURE : Activez une Ambassade "Astroport" !

```
~/.zen/Astroport.ONE/adventure/adventure.sh
```

Trouvez le moyen d'accéder à une "Station Astroport" installée en forêt...

NB: Une Station branchée sur un panneau solaire et une batterie adéquate, peut fonctionner OnGrid et OffGrid

## ./start.sh

Gestion des VISA PLAYER (et gestion des VOEUX) en mode CLI

```
~/.zen/Astroport.ONE/command.sh
```

# Activer "myos" MODE OLYMPE (Docker)

```
sudo apt install git make docker.io
sudo adduser $USER docker

## REBOOT

cd ~/.zen/Astroport.ONE
make
make install
```

USER devient un PLAYER, avec son propre démon IPFS, installé dans un Docker.
Chaque STATION (nœud Astroport) accessible en WAN peut héberger un à plusieurs autres "JOUEURS".

IPFS relie les clefs et les données.
Nous mettons un TW dans une clef.


# "OPEN API" : "♥BOX"
## http://astroport.localhost:1234

Une fois votre Station Astroport démarrée:
* le port 1234 publie API (REPONSE PORT TCP 12145 12445 )
* le port 12345 publie MAP(*) (JSON STATION CACHE IPNS KEY)
* le port 33101 publie G1BILLETS  (REPONSE PORT TCP 33102)

* le port 8080, 4001 et 5001 sont ceux de la passerelle IPFS

⚠ ASTROPORT NETCAT SYSTEM ⚠

Astroport utilise l'outil réseau le plus simple "netcat". Il s'agit d'un moteur STEP donnant accès à une "OPEN API".
Notre programme est conçu pour fonctionner dans des conditions de réseau local.
Le premier HTTP GET envoie la commande, mais l'APP doit obtenir le PORT de réponse.

Voici comment procéder en BASH ou JAVASCRIPT

## RECUPERATION DU PORT DE REPONSE API : (◕‿‿◕)
### CLI
```
    # PLAYER COPIER "_URL_" FAVORITE
    curl -so ~/.zen/tmp/${MOATS}/astro.port "http://astroport.localhost:1234/?salt=0&pepper=0&g1pub=_URL_&email=${EMAIL}"

    TELETUBE=$(cat ~/.zen/tmp/${MOATS}/astro.port | grep "(◕‿‿◕)" | cut -d ':' -f 2 | cut -d '/' -f 3)
    TELEPORT=$(cat ~/.zen/tmp/${MOATS}/astro.port | grep "(◕‿‿◕)" | cut -d ':' -f 3 | cut -d '"' -f 1)

                sleep 30

    # RECUPERER SON JETON PLAYER
    curl -so ~/.zen/tmp/${MOATS}/astro.rep "http://$TELETUBE:$TELEPORT"
```
### JS
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

## ➤ PRIVATE ZONE (fonctionne sur toutes les Stations.)
### ```/?salt=${SALT}&pepper=${PEPPER}&${APPNAME}=${WHAT}&${OBJ}=${VAL}...```

### Créer un PLAYER TW <3BOX
```http
GET /?salt=${SALT}&pepper=${PEPPER}&g1pub=${URLENCODEDURL}&email=${PLAYER}
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `g1pub` | `string` | **Required**. Your prefered _URL_  |
| `email` | `email` | **Required**. Your email one token |

### LOGOUT PLAYER (remove IPNS keys from Station)
```http
GET /?salt=${SALT}&pepper=${PEPPER}&logout=${PLAYER}
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `logout` | `string` | **Required**. Your email one token  |

### LOGIN PLAYER (Activate IPNS keys on Station)
```http
GET /?salt=${SALT}&pepper=${PEPPER}&login=${PLAYER}
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `login` | `string` | **Required**. Your email one token  |

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


### Lire Messagerie Gchange
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

###  Redirections
* vers Gchange

```/?salt=${SALT}&pepper=${PEPPER}&g1pub=on```

* vers TW

```/?salt=${SALT}&pepper=${PEPPER}&g1pub=astro```

###  Déclencher un Payement de 1 Ğ1 à Fred
```http
GET /?salt=${SALT}&pepper=${PEPPER}&pay=1&g1pub=DsEx1pS33vzYZg4MroyBV9hCw98j1gtHEhwiZ5tK7ech
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `salt` | `string` | **Required**. Your passphrase one token |
| `pepper` | `string` | **Required**. Your passphrase two token |
| `pay` | `integer` | **Required** G1 AMOUNT |
| `g1pub` | `G1PUB` |  **Required**  destination "wallet key" |

## ➤ PLAYER ZONE (API Station qui héberge ${PLAYER})
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


###  Modifier URL ♥BOX - CopierYoutube du PLAYER
```http
GET /?player=${PLAYER}&youtube=URLENCODED
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `player` | `string` | **Required**. Your EMAIL token |
| `youtube` | `string` | **Required** URL = Video URL |



### QRCODE (API SandBox)
```http
GET /?qrcode=${G1PUB}
```
| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `qrcode` | `string` | **Required**. Your G1PUB token |

> Look for details & extend as you like in ~/.zen/Astroport.ONE/API/QRCODE.sh

If is IPNS & local PLAYER ? Redirect to G1BILLET

If is G1*? Redirect to G1WishApp / Export Tags from TW

http://astroport.localhost:1234/?qrcode=G1Serie&tw=k51qzi5uqu5dgobi9ozzzvdftqfd3hd7a1488nzymky1edz8j779jov7sbemc0
redirect to
http://ipfs.localhost:8080/ipns/k51qzi5uqu5din47zmnzk6tmk1tjqaeaj9pbb3qilmstbsf9uyc12qpdmigtd3/

http://astroport.localhost:1234/?qrcode=G1G1Serie&tw=k51qzi5uqu5dgobi9ozzzvdftqfd3hd7a1488nzymky1edz8j779jov7sbemc0&json
redirect to pure "tag=" result  json


If is G1PUB ? G1BILLET adventure with GCHANGE and CESIUM

### HOW TO REFRESH SLOW IPFS STATION
```
sudo systemctl restart ipfs
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
| ipfsnodeid | date de creation du document |
| astroport | Lien vers l'API de la station |
| g1station | Lien vers la carte PLAYER de la Station |
| g1swarm | Lien vers la carte des cartes des Stations de l'essaim |

Afin de propager la carte chaque Stations lors de son raffraichissement de cache demande aux Boostrap de la récupérer
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

[![](http://ipfs.localhost:8080/ipfs/QmafsWdAeB5W9HcNPQWK2yjTgcW8eTxHoSD7bzE55mtrdP)

### "The Barefoot Architect" de Johan Van Lengen.

Lignes de commandes

```
ipfs ls Qme6a6RscGHTg4e1XsRrpRoNbfA6yojC6XNCBrS8nPSEox/
ipfs cat QmbfVUAyX6hsxTMAZY7MhvUmB3AkfLS7KqWihjGfu327yG > /tmp/vdoc.pub_the-barefoot-architect.pdf && xdg-open /tmp/vdoc.pub_the-barefoot-architect.pdf
```
Après un passage par [ajouter_media.sh](/qo-op/Astroport.ONE/src/branch/master/ajouter_media.sh)

Vos données son stockées [dans des Tiddlers](https://ipfs.copylaradio.com/ipns/k51qzi5uqu5dioeckikst5f8jw1tbljom6acjbw9zerl3671921krs4nm1531r#:[tag[G1Films]])

### Foret Enchantée - PROJET ASTROPORT.pdf

https://ipfs.copylaradio.com/ipfs/QmUtGpGeMZvwp47ftqebVmoFWCmvroy5wEtWsKvWvDWJpR

---

## SIMULATIONS LOOPY

> [Simulateur Astronaute/Voeux](https://ncase.me/loopy/v1.1/?data=[[[3,646,229,0.5,%22Astronaute%22,5],[4,806,372,0.16,%22G1Voeu%22,3],[5,449,133,0.83,%22G1Talent%22,1],[6,928,124,0.5,%22Astronaute%22,0],[7,1055,293,0.5,%22Astronaute%22,0],[8,883,587,0.5,%22Astronaute%22,0],[10,691,54,0.5,%22G1Voeu%22,3]],[[3,5,82,1,0],[3,4,-87,1,0],[6,4,83,1,0],[4,5,176,1,0],[8,8,85,1,12],[8,4,-45,1,0],[7,4,34,1,0],[5,3,49,1,0],[7,7,101,1,225],[6,6,113,1,-84],[3,3,90,1,75],[5,4,-293,1,0],[3,10,34,1,0]],[],10%5D)

> [Essaim Astroport.ONE](https://ncase.me/loopy/v1.1/?data=[[[1,419,351,1,%22Astroport.ONE%22,3],[2,506,530,1,%22Terrien%22,5],[3,499,95,1,%22IPFS%22,1],[4,272,225,1,%22Astroport.ONE%22,3],[5,620,297,0.16,%22Astroport.ONE%22,4],[7,927,69,0.66,%22Astroport.ONE%22,3],[8,798,175,0.66,%22Astroport.ONE%22,3]],[[2,1,94,-1,0],[1,2,89,1,0],[2,5,-122,1,0],[5,3,58,1,0],[3,5,25,1,0],[4,3,117,1,0],[3,4,-152,1,0],[1,3,60,1,0],[3,1,-18,1,0],[7,3,-44,1,0],[3,7,15,1,0],[8,3,37,1,0],[3,8,-47,1,0]],[[798,557,%22https%253A%252F%252Fipfs.copylaradio.com%253A1234%250A(salt%2520%252F%2520pepper%2520%252F%2520email)%2520%253D%2520TW%2520%252B%2520AstroBot%2520API%22],[256,141,%22Station%2520Officielle%250A(Bootstrap%2520%252B%2520RoundRobin%2520DNS)%22],[868,332,%22D%25C3%25A9l%25C3%25A9gation%2520de%2520clef%250A(Tiers%2520de%2520confiance)%22]],9%5D)


## Stargazers over time

[![Stargazers over time](https://starchart.cc/papiche/Astroport.ONE.svg)](https://starchart.cc/papiche/Astroport.ONE)
