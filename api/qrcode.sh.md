# QRCODE.sh

***

L'API `QRCODE` permet de gérer diverses opérations liées aux QR codes, y compris la redirection de liens, la gestion des clés IPNS, et l'interaction avec des chaînes de blocs comme G1. Voici les détails sur les différentes fonctionnalités de cette API.

#### Fonctionnement Général

L'API `QRCODE` est accessible via des requêtes HTTP GET. Les paramètres de la requête déterminent l'action spécifique à effectuer. Voici les principales fonctionnalités :

#### Redirection de Liens Web

Si le QR code contient un lien HTTP, l'API redirige simplement vers ce lien.

**Exemple de requête :**

```http
GET /?qrcode=http://example.com
```

**Réponse :**

```http
HTTP/1.1 302 Found
Location: http://example.com
```

#### Gestion des Stations

Pour rafraîchir une station et ouvrir l'interface G1PalPay, utilisez le paramètre `station`.

**Exemple de requête :**

```http
GET /?qrcode=station
```

**Réponse :**

```http
HTTP/1.1 302 Found
Location: http://<IPFS_LINK_TO_STATION>
```

#### QR Code PGP Encrypté

Pour gérer un QR code contenant un message PGP encrypté, utilisez le paramètre `pass` pour fournir la phrase de passe.

**Exemple de requête :**

```http
GET /?qrcode=-----BEGIN%20PGP%20MESSAGE-----~~jA0ECQMC5iq8...&pass=coucou
```

**Réponse :**

```http
HTTP/1.1 200 OK
Content-Type: text/html
...
```

#### Mode G1Voeu

Pour retourner l'adresse IPNS d'un souhait (voeu) ou un lien direct vers un tag spécifique dans TiddlyWiki.

**Exemple de requête :**

```http
GET /?qrcode=G1Tag&tw=_IPNS_PLAYER_&json
```

**Réponse :**

```http
HTTP/1.1 200 OK
Content-Type: application/json
...
```

#### Conversion d'Adresse IPNS

Pour convertir une adresse IPNS en lien G1 ou vice versa.

**Exemple de requête :**

```http
GET /?qrcode=12D3Koo...&getipns=on
```

**Réponse :**

```http
HTTP/1.1 200 OK
Content-Type: text/html
...
```

#### Paramètres

| Paramètre | Type     | Description                                                   |
| --------- | -------- | ------------------------------------------------------------- |
| `qrcode`  | `string` | **Requis**. Le contenu du QR code                             |
| `pass`    | `string` | **Optionnel**. Phrase de passe pour déchiffrer le message PGP |
| `getipns` | `string` | **Optionnel**. Convertir une adresse IPNS                     |
| `tw`      | `string` | **Optionnel**. Adresse IPNS de TiddlyWiki                     |
| `json`    | `string` | **Optionnel**. Retourner le résultat en format JSON           |

#### Exemples d'Utilisation

**Redirection de Lien Web**

```http
GET /?qrcode=http://example.com
```

**Rafraîchir une Station**

```http
GET /?qrcode=station
```

**QR Code PGP Encrypté**

```http
GET /?qrcode=-----BEGIN%20PGP%20MESSAGE-----~~jA0ECQMC5iq8...&pass=coucou
```

**Mode G1Voeu**

```http
GET /?qrcode=G1Tag&tw=_IPNS_PLAYER_&json
```

**Conversion d'Adresse IPNS**

```http
GET /?qrcode=12D3Koo...&getipns=on
```

