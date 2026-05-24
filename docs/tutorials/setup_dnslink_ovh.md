# Tutoriel — Configurer le DNSLink OVH pour astroport.one

> Vous apprendrez à lier le contenu IPFS de `earth/` au nom de domaine `astroport.one` via l'API OVH, de façon à ce que chaque `./microledger.me.sh` mette à jour automatiquement le DNS.
>
> **Durée estimée** : 15 minutes.
> **Prérequis** : accès au compte OVH gestionnaire de la zone `astroport.one`, station Astroport.ONE opérationnelle, `UPLANETNAME` défini.

---

## Ce que vous allez faire

À la fin de ce tutoriel, chaque publication de `earth/` via `microledger.me.sh` mettra automatiquement à jour les enregistrements TXT `_dnslink.astroport.one` et `_dnslink.origin.astroport.one` sur OVH. Les visiteurs accédant à l'application via une gateway IPFS verront toujours la version la plus récente.

---

## Étape 1 — Créer un token d'API OVH

Ouvrez [https://api.ovh.com/createToken](https://api.ovh.com/createToken) et connectez-vous avec le compte OVH qui gère `astroport.one`.

Remplissez le formulaire :

| Champ | Valeur |
|---|---|
| Application name | `uplanet-dnslink` |
| Application description | `DNSLink auto-update` |
| Validity | Unlimited |

Ajoutez exactement ces trois droits :

```
GET  /domain/zone/*
PUT  /domain/zone/*
POST /domain/zone/*
```

Cliquez **Create keys**. OVH affiche trois valeurs — **notez-les immédiatement**, elles ne sont plus accessibles ensuite :

```
Application Key    : XXXXXXXXXXXXXXXXXXXX
Application Secret : YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
Consumer Key       : ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
```

---

## Étape 2 — Stocker les credentials dans le Kind 30800

Ouvrez un terminal sur votre station et sourcez `cooperative_config.sh` :

```bash
source ~/.zen/Astroport.ONE/tools/cooperative_config.sh
```

Stockez les trois clés (elles seront automatiquement chiffrées) :

```bash
coop_config_set "OVH_APP_KEY"      "XXXXXXXXXXXXXXXXXXXX"
coop_config_set "OVH_APP_SECRET"   "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY"
coop_config_set "OVH_CONSUMER_KEY" "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
```

La zone est déjà `astroport.one` par défaut. Si votre zone DNS porte un autre nom :

```bash
coop_config_set "OVH_ZONE" "mondomaine.fr"
```

Vérifiez que les valeurs ont bien été stockées :

```bash
coop_config_list
```

Vous devez voir la section `=== DNSLINK OVH ===` avec `OVH_APP_KEY`, `OVH_APP_SECRET` et `OVH_CONSUMER_KEY` affichés comme `[ENCRYPTED]`.

---

## Étape 3 — (Facultatif) Vérifier via l'interface web

Ouvrez `economy.html` dans votre navigateur. Faites défiler jusqu'à la section **⚙️ Cooperative Config**, cliquez sur **Déchiffrer** et saisissez votre `UPLANETNAME`. Les quatre champs **🌐 DNSLink OVH** doivent afficher vos valeurs.

---

## Étape 4 — Publier une première version

Faites une modification mineure dans `earth/` pour déclencher le flux :

```bash
cd ~/workspace/AAA/UPlanet
touch earth/.dnslink-test && rm earth/.dnslink-test
./microledger.me.sh
```

Observez la sortie. Après le commit git, vous devez voir :

```
## IPFS EARTH : Qm<hash_du_répertoire_earth>
## DNSLINK _dnslink.astroport.one → dnslink=/ipfs/Qm...
OK: DNSLink mis à jour → dnslink=/ipfs/Qm...
## DNSLINK _dnslink.origin.astroport.one → dnslink=/ipfs/Qm...
OK: DNSLink mis à jour → dnslink=/ipfs/Qm...
```

Si l'enregistrement `_dnslink.astroport.one` n'existait pas encore sur OVH, vous verrez :

```
INFO: Record TXT _dnslink.astroport.one absent — création...
INFO: Record créé (id: 1234567890)
OK: DNSLink mis à jour → dnslink=/ipfs/Qm...
```

---

## Étape 5 — Vérifier la propagation DNS

Attendez 1 à 2 minutes (selon le TTL), puis vérifiez :

```bash
dig TXT _dnslink.astroport.one +short
```

La sortie doit ressembler à :

```
"dnslink=/ipfs/QmEARTH..."
```

Testez l'accès via une gateway IPFS :

```bash
curl -sI "https://cloudflare-ipfs.com/ipns/astroport.one" | head -5
```

---

## Ce que vous avez accompli

Vous avez :
- Créé un token OVH avec les droits minimaux nécessaires
- Stocké les credentials de façon chiffrée dans le réseau coopératif (Kind 30800)
- Vérifié que `microledger.me.sh` met à jour automatiquement les deux enregistrements TXT
- Confirmé la propagation DNS

Désormais, chaque fois que vous modifiez `earth/` et lancez `./microledger.me.sh`, le DNSLink est mis à jour sans intervention manuelle.
