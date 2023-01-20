# Préambule
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

Astroport ONE est l'ambassade d'un monde fait de toiles confiances algorithmiques interconnectées.

# Astroport.ONE

Il s'agit d'un Jeu de société grandeur nature qui consiste à répertorier, inventer, enseigner, diffuser les meilleures façons d'habiter la planète Terre.
Ce programme introduit des données multimédia (page web, audio, vidéo) en tant que chaines de données (blockchain) inscrites dans le réseau IPFS
que les joueurs échangent au travers des TW et Oasis.


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


# API : La "porte fenètre" de votre "♥BOX"
## http://astroport.localhost:1234

Une fois votre Station Astroport démarrée (```~/.start.sh```):
* le port 1234 publie API
* le port 12345 publie MAP(*)



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

Redirections
* vers Gchange

```/?salt=${SALT}&pepper=${PEPPER}&g1pub=on```

* vers TW

```/?salt=${SALT}&pepper=${PEPPER}&g1pub=astro```

## ➤ PLAYER ZONE (fonctionne uniquement sur la Station qui héberge votre PLAYER)
### ```/?player=${PLAYER}&${APPNAME}=${WHAT}&${OBJ}=${VAL}...```

###  Déclencher un Payement de 99 Ğ1 à Fred
```http
GET /?player=${PLAYER}&pay=99&g1pub=DsEx1pS33vzYZg4MroyBV9hCw98j1gtHEhwiZ5tK7ech
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `player` | `string` | **Required**. Your EMAIL token |
| `pay` | `string` | **Required** pay = ZEN AMOUNT |
| `g1pub` | `${VAL}` |  **Required** G1PUB |


###  Exporter Tiddlers.json depuis son TW selon valeur des "tags" ( ici TAG=G1CopierYoutube)
```http
GET /?player=${PLAYER}&moa=json&tag=G1CopierYoutube
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `player` | `string` | **Required**. Your EMAIL token |
| `moa` | `string` | **Required** APP = output format |
| `tag` | `${VAL}` | TW filtering default G1CopierYoutube |



### PUBLIC (fonctionne par tout, pour tous)
```http
GET /?qrcode=$G1PUB/$IPNS/$...
```
### TODO


# 20H12

Chaque jour, les ASTROBOTs captent les :star: de leurs PLAYERs puis exécutent le protocole de synchronisation Ŋ1

[20H12.sh](/qo-op/Astroport.ONE/src/branch/master/20h12.sh)

Ils analysent les données et extraient des flux json selon les G1Voeu présent dans chaque TW.

Le niveau informationnel de confiance exploré permet de proposer des alertes issues du niveau Ŋ2.

## FLUX TW :

[![TW FEEDS](https://ipfs.copylaradio.com/ipfs/Qma9zvrYHGcUPisLKBcG9U9sktThX5VfVci8jfM8D9RspT)](https://pad.p2p.legal/s/G1TWFeed#)


# IPFS : UN STOCKAGE INALTERABLE ET INTELLIGENT

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
