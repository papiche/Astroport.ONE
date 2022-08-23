# Client CLI for Cesium+/Ḡchange pod
## Installation

Linux:
```
bash setup.sh
```

Autre:
```
Débrouillez-vous.
```

## Utilisation

*Python 3.9 minimum*

Renseignez optionnellement le fichier **.env** (Généré lors de la première tentative d'execution, ou à copier depuis .env.template).

```
./jaklis.py -h
```

```
usage: jaklis.py [-h] [-v] [-k KEY] [-n NODE] {read,send,delete,get,set,erase,stars,unstars,getoffer,setoffer,deleteoffer,pay,history,balance,id,idBalance} ...

Client CLI pour Cesium+ et Ḡchange

optional arguments:
  -h, --help            show this help message and exit
  -v, --version         Affiche la version actuelle du programme
  -k KEY, --key KEY     Chemin vers mon trousseau de clé (PubSec)
  -n NODE, --node NODE  Adresse du noeud Cesium+, Gchange ou Duniter à utiliser

Commandes de jaklis:
  {read,send,delete,get,set,erase,stars,unstars,getoffer,setoffer,deleteoffer,pay,history,balance,id,idBalance}
    read                Lecture des messages
    send                Envoi d'un message
    delete              Supression d'un message
    get                 Voir un profile Cesium+
    set                 Configurer son profile Cesium+
    erase               Effacer son profile Cesium+
    stars               Voir les étoiles d'un profile / Noter un profile (option -s NOTE)
    unstars             Supprimer un star
    getoffer            Obtenir les informations d'une annonce gchange
    setoffer            Créer une annonce gchange
    deleteoffer         Supprimer une annonce gchange
    pay                 Payer en Ḡ1
    history             Voir l'historique des transactions d'un compte Ḡ1
    balance             Voir le solde d'un compte Ḡ1
    id                  Voir l'identité d'une clé publique/username
    idBalance           Voir l'identité d'une clé publique/username et son solde
```

Utilisez `./jaklis CMD -h` où `CMD` est la commande souhaité pour obtenir l'aide détaillé de cette commande.

### Exemples:

Lire les 10 derniers messages de mon compte indiqué dans le fichier `.env` (par defaut 3 messages):
```
./jaklis read -n10
```

Envoyer un message à la clé publique `Do99s6wQR2JLfhirPdpAERSjNbmjjECzGxHNJMiNKT3P` avec un fichier de trousseau particulier:
```
./jaklis.py -k /home/saucisse/mon_fichier_de_trousseau.dunikey send -d Do99s6wQR2JLfhirPdpAERSjNbmjjECzGxHNJMiNKT3P -t "Objet du message" -m "Corps de mon message"
```

Noter 4 étoiles le profile `S9EJbjbaGPnp26VuV6fKjR7raE1YkNhUGDgoydHvAJ1` sur gchange:
```
./jaklis.py -n https://data.gchange.fr like -p S9EJbjbaGPnp26VuV6fKjR7raE1YkNhUGDgoydHvAJ1 -s 4
```

Paramétrer mon profile Cesium+:
```
./jaklis.py set -n "Sylvain Durif" -v "Bugarach" -a "42 route de Vénus" -d "Christ cosmique" -pos 48.539927 2.6608169 -s https://www.creationmonetaire.info -A mon_avatar.png
```

Effacer mon profile Gchange:
```
./jaklis.py -n https://data.gchange.fr erase
```
