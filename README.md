# Préambule
Quand pourrons nous sortir de ce Méchant Cloud qui nous profile, nous scrute, nous analyse... Pour au final nous faire consommer.
Je n'ai pas suivi la formation d’ingénieur réseau pour fabriquer ça!
Alors j'ai fait autre chose.

Astroport est basé sur IPFS pour former nos Cloud personnels échangés entre amis d'amis à l’abri des algorithmes de l'IA et du datamining sauvage qui règne ici bas.
L'avantage de ce système, une consommation énergétique divisé par 100, une répartition des données qui permet de fonctionner déconnecté, un système d'information pair à pair inaltérable, inviolable.
S'il vous plaît arrêtons cet Internet Supermarché de nous même...
C'est une bibliothèque du savoir à la base.

https://astroport.com
Avec cette technologie, nous devenons chacun hébergeur et fournisseur d'accès, souverain monétaire et médiatique.
Avec cette technologie, nous établissons une "Crypto Nation" dont la carte relie les territoires au delà des frontières et des pays.
Astroport ONE est une ambassade.

# Astroport.ONE

Il s'agit d'un Jeu de société grandeur nature qui consiste à répertorier, inventer, enseigner, diffuser les meilleures façons d'habiter la planète Terre.
Ce programme introduit des données multimédia (page web, audio, vidéo) en tant que chaines de données (blockchain) inscrites dans le réseau IPFS
que les joueurs échangent au travers des Oasis.

Astroport One c'est aussi une performance scientifique et artistique néé le 25 oct 2021.
Dans une forêt de 8ha située en France, dans le Tarn et Garonne, une groupe de bénéficiaires du RSA
s'est réuni, pour jouer le rôle de membres d'une "NASA Extraterrestes" installés en forêt qu'ils transforment en jardin.

Cette exploration met en oeuvre l'usage de "Monnaie Libre" appliquée à ce JEu de société.
Chaque nouveau joueur reçoit 300 LOVE (correspondant à 3 DU(G1) afin dévaluer sa capacité à pratiquer des activités ayant une valeur pour le commun.

Chacun est invité à enregistrer ses idées et propositions pour améliorer la qualité de vie du lieu.
Ces publications sont enregistrées comme REVES du lieu.

Chaque joueur aura pour mission, de répartir le montant de sa production monétaire journalière, 100 LOVE entre les ACTIONS et les REVES déclarés.
Il devra également s'acquiter du montant établi pour assurer sa pension complête, montant réduit au 1/3 quand le joueur aura offert un nouvel habitat.

Les règles évoluent encore... Pour rejoindre l'expérience :

Astroport One, Sorris, Lavaurette, France
Latitude: 44.22986344
Longitude: 1.65397188

---

Bienvenue dans la confédération intergalactique.

Ambassade des Astronautes Terraformeurs.

Avant de commencer l'aventure, découvrez cet ouvrage "The Barefoot Architect" de Johan Van Lengen.
```
ipfs ls Qme6a6RscGHTg4e1XsRrpRoNbfA6yojC6XNCBrS8nPSEox/
ipfs cat QmbfVUAyX6hsxTMAZY7MhvUmB3AkfLS7KqWihjGfu327yG /tmp/vdoc.pub_the-barefoot-architect.pdf
```

Le JEu est constitué de Stations IPFS localisés à des cooordonnées précises.
Ces stations acceuillent des joueurs.  Leur mission, réaliser des rêves.

Dans IPFS, chacun publie son site web statique comportant texte, image, sons et vidéos (selon les modèles situés dans Templates)


DELARATION DES LIEUX
~/.zen/game/worlds

- Coord GPS (Map Minetest)
- Certification des niveaux d'aptitudes à utiliser des outils ou équipements.
- Niveaux autonomies:  eau, nourriture, couchages, electricité, chaleur, conservation, ...
- Ambassade & Enregistrement des joueurs ("VISA") : Passeport Terre.
- Collecte & publication des rêves : Pinterest


NAVIGATEUR JOUEUR
~/.zen/game/players

- Identité astronaute + VISA
- aptitudes / équipements
- arbres informationnels, projection de rêves.

---
# astrXbian Balise Structure

Chaque Astronaute quand il se connecte transmet ses G1 clefs au démon ipfs.

Voici où se situe ses chaines...

~/.zen/game/players/$PLAYER/moa
~/.zen/game/players/$PLAYER/keystore
~/.zen/game/players/$PLAYER/secret.dunikey
~/.zen/game/players/$PLAYER/ipfs/.$IPFSNODEID/G1SSB/

Dans IPFS, chaque MEDIA ajouté est associé à une première clef "créateur".
Chaque "contrat" permettant de libérer le MEDIA est inscrit en tant que index.html de chaque sous-répertoire.
Le contrat final correspond à enchainer la découverte des sous-répertoires, avant le dernier contenant le HASH recherché.

'G1SSB' contient le contrat "Identité du joueur", Astronaute.
'FRIENDS' les contrats et niveau de confiance déclarés.
'KEY' les contrats envers des oeuvres numériques ou numérisées (NFT).

Ces données sont diffusées au travers de la balise IPFS du joueur quand il est connecté.

Le joueur possède les clefs des canaux 'moa_player' et 'qo-op_player', ce sont ses journaux.
Le premier lié à l'administration du jeu et des joueurs
Le second public. L'équivalent d'une chaine multimédia collectivement approvisionnées...

L'interface de ces journaux est TiddlyWiki, chaque enregistrement se trouve enregistré en blockchain par le capitaine.

---

# TODO
* Ajouter des worlists au choix par oasis https://diceware.readthedocs.io/en/stable/wordlists.html
* Remplacer le chiffrage SSL par PGP
* Traductions
