# Préambule - [read this introduction in english](https://github.com/papiche/Astroport.ONE/blob/master/README.en.md) -

Bienvenue dans l'équipe d'Astroport, le réseau pair-à-pair (P2P) révolutionnaire qui repousse les limites de la liberté d'information et d'interaction ! Si vous êtes un développeur passionné à la recherche d'un projet novateur et audacieux, alors vous êtes au bon endroit.

Astroport offre une plateforme sécurisée et décentralisée permettant le partage d'informations, en particulier de vidéos, via IPFS. Notre objectif est de contrer les restrictions de censure qui pourraient être imposées par les futures lois de fact-checking avancées par l'Union Européenne. Nous croyons fermement en la liberté d'expression et nous nous engageons à protéger cette valeur fondamentale.

Mais ce n'est pas tout ! Astroport va bien au-delà du simple partage d'informations. Notre plateforme vous permet également d'identifier les ressources autour de vous, qu'il s'agisse de nourriture, d'amis, de services ou de biens. Grâce à Astroport, vous serez en mesure de trouver et de partager les ressources nécessaires à votre vie quotidienne de manière simple et efficace.

Et ce n'est pas tout ! Nous souhaitons également intégrer un "[build guide](https://ipfs.copylaradio.com/ipfs/QmNcNcYRDUFmR1Ey1MAyhzzZRJEi1Dfq8YXRTXq6XZ9n4A/#)" à Astroport, inspiré par les célèbres livres de recettes de Minecraft. Vous pourrez utiliser ce guide pour apprendre à créer des objets réels, en utilisant les matériaux disponibles sur notre place de marché. Imaginez un tutoriel détaillé pour fabriquer des meubles, des objets de décoration, voire même des outils pratiques pour votre quotidien. Astroport met la créativité entre vos mains.

Nous nous sommes également associés à la [monnaie libre Ğ1](https://monnaie-libre.fr) et à sa place de marché, [gchange.fr](https://gchange.fr). Cela signifie que vous pourrez commander les matériaux nécessaires à la réalisation de vos projets directement depuis Astroport. Tout est à portée de clic, dans une seule et même application.

Rejoindre l'équipe d'Astroport, c'est contribuer à une cause qui va bien au-delà de la simple programmation. C'est faire partie d'un mouvement qui aspire à défendre les principes de liberté, de partage et de créativité. C'est travailler sur un projet qui a le potentiel de changer la façon dont nous interagissons avec l'information et les ressources qui nous entourent.

Alors, si vous êtes prêt à relever le défi et à participer à la construction d'un avenir où la censure n'a pas sa place, rejoignez-nous dès aujourd'hui et laissez votre empreinte sur le monde avec Astroport. Ensemble, nous pouvons libérer le potentiel de la technologie et créer un avenir plus ouvert pour tous.


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

[DOCUMENTATION](https://pad.p2p.legal/s/Astroport.ONE)


# INSTALLATION (Linux Mint / Ubuntu / DEBIAN)

```
# GIT.P2P.LEGAL

bash <(wget -qO- https://git.p2p.legal/qo-op/Astroport.ONE/raw/branch/master/install.sh)

# GITHHUB
bash <(wget -qO- https://raw.githubusercontent.com/papiche/Astroport.ONE/master/install.sh)


```

Si tout s'est bien déroulé, vous devriez trouver ces processus en cours d'execution...

```
/usr/local/bin/ipfs daemon --enable-pubsub-experiment --enable-namesy
/bin/bash /home/fred/.zen/G1BILLET/G1BILLETS.sh daemon
 \_ /bin/bash /home/fred/.zen/G1BILLET/G1BILLETS.sh daemon
   \_ nc -l -p 33101 -q 1
/bin/bash /home/fred/.zen/Astroport.ONE/12345.sh
 \_ /bin/bash /home/fred/.zen/Astroport.ONE/12345.sh
   \_ nc -l -p 1234 -q 1
/bin/bash /home/fred/.zen/Astroport.ONE/_12345.sh
 \_ nc -l -p 12345 -q 1

```

# LANCEMENT

Après l'installation, vous devriez avoir 2 nouveaux raccourcis sur votre "Bureau"

* "Astroport" qui ouvre le portail de votre Station : http://astroport.localhost:1234
* "REC" qui permet d'enregistrer vos fichiers sur IPFS et publier leur Capusle dans votre TW

## Comment Gérer votre "Astroport" !


```
~/.zen/Astroport.ONE/command.sh
```
Permet la Gestion des PLAYER (et des G1VoeuX) en mode CLI

# "BASH API" : "♥BOX"
## http://astroport.localhost:1234

Une fois votre Station Astroport démarrée:
* le port 1234 publie API (REPONSE PORT TCP 12245 à 12445 )
* le port 12345 publie MAP(*) (CARTE DE L'ESSAIM - BOOTSTRAP / STATIONS)
* le port 33101 publie G1BILLETS  (REPONSE PORT TCP 33102)

* le port 8080, 4001 et 5001 sont ceux de la passerelle IPFS

⚠ ASTROPORT NETCAT SYSTEM ⚠

Astroport utilise l'outil réseau le plus simple "netcat".
Il s'agit d'un moteur STEP donnant accès à une "API BASH".
Les requêtes se font en HTTP GET.
Vous effectuez un regexp sur "url=ADRESSE:PORT" ou (◕‿‿◕) pour y obtenir le résultat.

En voici des exemples.

## RECUPERATION DU PORT DE REPONSE API : (◕‿‿◕)
### CLI (BASH)
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
Utilisez "[astro.js](www/G1PalPay/G1PalPay_fichiers/astro.js)" comme dans l'Application DEMO www/G1PalPay (accessible sur "Open Station")
```
    <script src="http://127.0.0.1:8080/ipfs/Qmae5v9zydax9u6C9ceDijURu5PYdd5avmv4NkenCw7RFv/astro.js"></script>
```



## ➤ PRIVATE ZONE (fonctionne sur toutes les Stations.)
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


###  Lancer la copie d'une URL (youtube | pdf ) par PLAYER dans son TW
```http
GET /?player=${PLAYER}&youtube=URLENCODED
```

| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `player` | `string` | **Required**. Your EMAIL token |
| `youtube or pdf` | `string` | **Required** URL kind = URL |


### QRCODE (API SandBox)
```http
GET /?qrcode=${G1PUB} | ${ASTRONAUTENS} | ${PGP_G1PASS_STRING}
```
| Parameter | Type     | Description                       |
| :-------- | :------- | :-------------------------------- |
| `qrcode` | `string` | **Required**. Your G1PUB token |

> Look for details & extend as you like in [~/.zen/Astroport.ONE/API/QRCODE.sh](API/QRCODE.sh)

### CODE BEHAVIOUR. monitor && rewards || fork signal

* Is IPNS key & PLAYER is local ? Redirect to [make a G1PASS (security level 6)](http://g1billet.localhost:33101/?montant=0&style=xbian&dice=6)

* Is G1*? Redirect to G1WishApp / Export Tagged Tiddlers json from TW

[http://astroport.localhost:1234/?qrcode=G1G1Serie&tw=k51qzi5uqu5dgobi9ozzzvdftqfd3hd7a1488nzymky1edz8j779jov7sbemc0](http://astroport.localhost:1234/?qrcode=G1Serie&tw=k51qzi5uqu5dgobi9ozzzvdftqfd3hd7a1488nzymky1edz8j779jov7sbemc0)
redirect to
[http://ipfs.localhost:8080/ipns/k51qzi5uqu5din47zmnzk6tmk1tjqaeaj9pbb3qilmstbsf9uyc12qpdmigtd3/](http://ipfs.localhost:8080/ipns/k51qzi5uqu5din47zmnzk6tmk1tjqaeaj9pbb3qilmstbsf9uyc12qpdmigtd3/)

[http://astroport.localhost:1234/?qrcode=G1G1Serie&tw=k51qzi5uqu5dgobi9ozzzvdftqfd3hd7a1488nzymky1edz8j779jov7sbemc0&json](http://astroport.localhost:1234/?qrcode=G1G1Serie&tw=k51qzi5uqu5dgobi9ozzzvdftqfd3hd7a1488nzymky1edz8j779jov7sbemc0&json)
redirect to pure "tag=" result  json

* Is G1PUB ... (FROM NEW G1PASS or empty G1BILLET)

    * If balance is "null" : Send 1 G1 (G1BILLET)
    * if GChange+ account exists : send 10 G1
    * if Cesium+ account exists : send 50 G1

* Is G1PASS
    * decode with PASS and make operation (same functions as SALT API are available)


## The Art of key derivation

In order to make (a little) clear how we use cryptography,

We choose to use "NaCl" (secret1 / secret) 2 key generation.

Thus

* If PLAYER key is (SECRET1/SECRET2) and G1PUB and EMAIL
    * wishes keys are (SECRET2 / G1WishName)
        * sub-wishes are (EMAIL / G1WishName G1PUB)
            * wish-billets are (EMAIL_dice_words / G1WishName G1PUB)

This way PLAYER never loose its data.
It is writen into IPFS... So recreate the key anywhere makes you get your data from friends you shared it with

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

## CREDITS

This "digital art" structure is a selection of some of the most valuable Free & OpenSource Software I ever had in my hand.
Credits is going to all the kindness and care provided to make valuable and secure software available for all

Did you ever dring a beer bought in G1 ?

You can pay me a beer or more by contributing to our OpenCollective
https://opencollective.com/monnaie-libre#category-ABOUT

