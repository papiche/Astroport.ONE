# THE ART OF BOOSTRAPING

"Blockchain" has special treatment during "heart beats" making evolve change of "State".

As we use IPFS, we can record any data structure as a "blockchain" by just copying last CID into new update.
IPNS key publishes evolving "Solid State" (like archive.org). Any ECC key is an IPNS key.
So Duniter/Cesium, GChange, SSH, PGP, ... can benefit a side shared storage onto IPFS.

Astroport.ONE is collecting is map through the bootstrap nodes in ~/.zen/Astroport.ONE/A_boostrap_nodes.txt
A new list makes a new "Station Tribe". Some bootstrap scenario could initiate automatic key creation & cross signatures
(ex: Create 25 PLAYERs to start a 5x5 document emitting with random cross signature)

THIS IS ALREADY THE CASE WITH PGP.
Instead you can convert your SSH key and benefit from Astroport Data Layer Protocol
```
## SEE EXERCICE
keygen --help
```

PLAYER key & wishes can be controled through : ```~/.zen/Astroport.ONE/command.sh``` or directly through TW (Tag="voeu")
Each wish, is a derivated key, it has an IPNS publishing and can be associated to its own ASTROBOT program to take care about Friends data collect & merge.

VISA.new.sh is creating TW from ```templates/twdefault.html``` and ```templates/minimal.html```
This script is important as it initialize PLAYER and connect him to STATION... You can add more different templates...

Visit https://tiddlywiki.com to understand all the capacities this tools have inside.

## 20H12
Every day (20H12.process.sh) activates automation.
Sequence is run every night :
1. PLAYER.refresh (distributed USERs key management)
2. UPLANET.refresh (UPlanet key refresh only Station in Boostrap list)

## _12345.sh : The MAP maintainer

This process is run almost every hour. Stations are getting and publishing
Each time MAP.refresh.sh is running it takes data from PLAYERs caches (~/.zen/game/players/.../) and publish it on Station IPNS key.

Boostrap Stations gets LANCoeurBOX through 12345 client call, asking for IPNS retrieval so SWARM data are collected.

## REVERSE CODE

You can use ~/.zen/Astroport.ONE/search command to search the code for "EXPRESSIONS"

For exemple, if you want to know from where VISA.new.sh is called run

```
~/.zen/Astroport.ONE$ ./search VISA.new.sh

------------------------------------------------------------------------------
  Searching for VISA.new.sh recursively. Please Wait...
------------------------------------------------------------------------------
./command.sh:            ${MY_PATH}/RUNTIME/VISA.new.sh
./command.sh:            ${MY_PATH}/RUNTIME/VISA.new.sh "$SALT" "$PEPPER" "$EMAIL"
./API/SALT.sh:                    echo "# ASTRONAUT NEW VISA Create VISA.new.sh in background (~/.zen/tmp/email.${EMAIL}.${MOATS}.txt)"
./API/SALT.sh:                    ${MY_PATH}/../RUNTIME/VISA.new.sh "$SALT" "$PEPPER" "${EMAIL}" "$PSEUDO" "${WHAT}" >> ~/.zen/tmp/email.${EMAIL}.${MOATS}.txt
./TODO.list:./RUNTIME/VISA.new.sh:######### TODO Ajouter d'autres clefs IPNS, GPG ?
./TODO.list:./RUNTIME/VISA.new.sh:WID="https://ipfs.$CLYUSER$YOMAIN.$(myHostName)/api" ## Next Generation API # TODO PLAYER IPFS Docker entrance
./TODO.list:./RUNTIME/VISA.new.sh:    ############ TODO améliorer templates, sed, ajouter index.html, etc...
./TODO.list:./RUNTIME/VISA.new.sh:         ## TODO : FOR STRONGER SECURITY REMOVE THIS LINE
./TODO.list:./RUNTIME/VISA.new.sh:# !! TODO !! # DEMO MODE. REMOVE FOR PRODUCTION - RECALCULATE AND RENEW AFTER EACH NEW KEY DELEGATION
./TODO.list:./RUNTIME/VISA.new.sh:# TODO : Allow Astronaut PASS change ;)
------------------------------------------------------------------------------
```

## EXERCICE

“keygen” peut fabriquer la clef duniter et ipfs à partir du keygen ssh (avec clef à courbe elliptique: ECC) et les convertir en clef duniter (secret.dunikey) et ipfs (IPNS)

```
ssh-keygen -t ed25519 -C "userA"
keygen -i ~/.ssh/id_ed25519 -t duniter -o ~/.zen/Asecret.dunikey
keygen -i ~/.ssh/id_ed25519 -t ipfs -o ~/.zen/Asecret.ipns
```
On va utiliser “natools” pour faire voyager les données en sécurité dans IPFS :wink:
```
natools.py encrypt -p $UserBPubKey -i ~/.zen/file.clear -o ~/.zen/file.toB.enc
```
“jaklis” va servir distribuer la toile de confiance.
On envoi entre 1 et 100 G1 aux UserXPubKey des clefs SSH avec lesquelles ont veut signifier un niveau de confiance.

UserB devra faire de même avec le même montant (ou pas, on verra plus tard ce cas…)
```
MACHINE A
jaklis.py -k ~/.zen/secretA.dunikey pay -a 100 -p ${UserBPubKey} -c "ASTRO#SSH" -m

MACHINE B
jaklis.py -k ~/.zen/secretB.dunikey pay -a 100 -p ${UserAPubKey} -c "ASTRO#SSH" -m
```
Maintenant.
Il reste à maintenir à jour et appliquer la ToileDeConfiance ASTRO#SSH

Pour cela, jaklis va extraire l’historique des transactions reçues qui portent le tag ASTRO#SSH
```
jaklis.py history -p UserAPubKey

+---------------------------------------------------------------------------------------------------------------------------------------
|        Date        |    De / À    |   Ḡ1    |  DU/ḡ1  | Commentaire                   |
|---------------------------------------------------------------------------------------------------------------------------------------
| 04/04/2023 à 20:01 | HV7o…jG61:Bu6 | 100.00    |  ~~~   | ASTRO#SSH
|---------------------------------------------------------------------------------------------------------------------------------------
| 04/04/2023 à 20:01 | 54yA…UvJm:3px | 70.00    | ~~~   | ASTRO#SSH
```
Extraire et vérifier qu’au moins une TX entrante et sortante existent (leur somme fait 0)… (“jq”)

Puis pour établir le droit de se connecter en SSH par exemple, UserA et UserB peuvent inscrire leur clef publique SSH dans ~/.ssh/authorized_keys et ~/.ssh/known_hosts.

Pour agrémenter cette phase on peut utiliser IPFS (et natools)

```
# Récup les paquets pour A depuis les machines SSH comptabilisé à 0
ipfs cat /ipns/IPNSUserB/file.toA.enc
ipfs cat /ipns/IPNSUserC/file.toA.enc
```

Voila le principe pour utiliser la G1 et établir une nouvelle “toile de confiance”, et faire passer des fichiers ou des messages entre les clefs. On étendre ce principe à d’autres “toiles de confiance” en définissant une nomenclature pour les ASTRO#TAG…

Qui est intéressé par ce programme (de distribution de clef SSH ou autre)?
Voila ma clef

ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEtg3SlRxtzsQnsBSeU83W0tvUyBTUvOU5lhjlbZVPCZ support@qo-op.com

* “keygen” https://git.p2p.legal/STI/Astroport.ONE/src/branch/master/tools/keygen
* “natools” https://git.p2p.legal/STI/Astroport.ONE/src/branch/master/tools/natools.py
* “jaklis” https://git.p2p.legal/axiom-team/jaklis
* “ipfs” https://git.p2p.legal/STI/Astroport.ONE/src/branch/master/kubo_v0.20.0_linux.install.sh

## ASTROPORT CREW GILET https://astroport.myspreadshop.fr/create?product=a68ad31e-d554-4c75-821d-97b00d6ad13f&view=2

