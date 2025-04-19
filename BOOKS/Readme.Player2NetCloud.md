Pour créer un compte avec un quota de 10 Go sur votre installation NextCloud en utilisant la ligne de commande, vous devez utiliser le conteneur nextcloud-aio-nextcloud. Voici la commande à exécuter :

```bash
OC_PASS="suite_de_mots_comme_mot_de_passe" docker exec -u www-data nextcloud-aio-nextcloud php occ user:add --display-name="Nom Utilisateur" --group="users" --password-from-env --quota=10GB adresse_email@exemple.com
```

Assurez-vous de remplacer les éléments suivants :
- "suite_de_mots_comme_mot_de_passe" : le mot de passe souhaité pour le compte
- "Nom Utilisateur" : le nom complet de l'utilisateur
- "adresse_email@exemple.com" : l'adresse e-mail qui servira de nom d'utilisateur

## Explications

- La commande utilise `docker exec` pour exécuter une commande à l'intérieur du conteneur nextcloud-aio-nextcloud.
- L'option `-u www-data` spécifie l'utilisateur sous lequel la commande doit être exécutée.
- `php occ` est l'outil en ligne de commande de NextCloud.
- `user:add` est la sous-commande pour ajouter un nouvel utilisateur.
- Les options définissent le nom d'affichage, le groupe, le quota, et indiquent d'utiliser le mot de passe défini dans la variable d'environnement.

Après l'exécution de cette commande, le compte sera créé avec les paramètres spécifiés, y compris le quota de 10 Go.
