# Guide pratique — DNSLink OVH

> Recettes pour les tâches courantes liées au DNSLink OVH.
> Ces guides supposent que la configuration initiale est déjà faite (voir `docs/tutorials/setup_dnslink_ovh.md`).
> L'outil CLI est `Astroport.ONE/admin/system/ovh.me.sh` (symlink disponible : `~/.zen/Astroport.ONE/admin/system/ovh.me.sh`).

---

## Récupérer une clé API OVH existante

Si vous avez perdu vos credentials OVH ou souhaitez créer un nouveau token, suivez ces étapes.

### Créer un nouveau token depuis le Manager OVH

1. Rendez-vous sur **[https://api.ovh.com/createToken](https://api.ovh.com/createToken)**
2. Connectez-vous avec le compte OVH qui gère la zone DNS `astroport.one`
3. Renseignez :
   - **Application name** : `uplanet-dnslink`
   - **Validity** : `Unlimited`
   - **Rights** :
     ```
     GET  /domain/zone/*
     PUT  /domain/zone/*
     POST /domain/zone/*
     ```
4. Validez — OVH affiche les trois valeurs **une seule fois** :
   ```
   Application Key    : (OVH_APP_KEY)
   Application Secret : (OVH_APP_SECRET)
   Consumer Key       : (OVH_CONSUMER_KEY)
   ```
   Copiez-les immédiatement.

### Lister les tokens existants

Vous pouvez consulter vos applications OVH existantes (sans récupérer le secret) depuis l'API :

```bash
# Remplacer AK par votre Application Key — sans consumer key, GET non authentifié sur /me/api/application
# Uniquement via Manager OVH : https://www.ovh.com/manager/ → Mon compte → API
```

> **Note** : OVH ne permet pas de récupérer un `Application Secret` ou `Consumer Key` après création. Si perdu, créez un nouveau token et révoquez l'ancien.

### Révoquer un ancien token

```
https://www.ovh.com/manager/ → Mon compte → Mes tokens API
```

Identifiez le token `uplanet-dnslink` et supprimez-le.

---

## Mettre à jour les credentials OVH

```bash
source ~/.zen/Astroport.ONE/tools/cooperative_config.sh

coop_config_set "OVH_APP_KEY"      "nouveau_app_key"
coop_config_set "OVH_APP_SECRET"   "nouveau_app_secret"
coop_config_set "OVH_CONSUMER_KEY" "nouveau_consumer_key"
```

Les nouvelles valeurs sont immédiatement disponibles pour toutes les stations qui sourcent `cooperative_config.sh`.

---

## Changer la zone DNS cible

```bash
source ~/.zen/Astroport.ONE/tools/cooperative_config.sh
coop_config_set "OVH_ZONE" "monautrezone.fr"
```

Le prochain `./microledger.me.sh` mettra à jour `_dnslink.monautrezone.fr` et `_dnslink.origin.monautrezone.fr`.

---

## Administrer les records DNSLink avec ovh.me.sh

`ovh.me.sh` est l'outil CLI complet pour gérer les records DNSLink sur OVH.

```bash
OVH_TOOL=~/.zen/Astroport.ONE/admin/system/ovh.me.sh

# Lister tous les records _dnslink de la zone
"$OVH_TOOL" list

# Lire un record
"$OVH_TOOL" get alice
# → _dnslink.alice.astroport.one

# Créer ou mettre à jour (upsert — recommandé)
"$OVH_TOOL" upsert alice /ipns/k51q...
"$OVH_TOOL" upsert _dnslink /ipfs/QmEARTH...
"$OVH_TOOL" upsert _dnslink.origin /ipfs/QmEARTH...

# Supprimer
"$OVH_TOOL" delete alice

# Cibler une autre zone
"$OVH_TOOL" list monautrezone.fr
"$OVH_TOOL" upsert alice /ipns/k51q... monautrezone.fr
```

Les credentials OVH sont lus depuis l'ENV (`OVH_APP_KEY`, `OVH_APP_SECRET`, `OVH_CONSUMER_KEY`) ou depuis le Kind 30800 coopératif si `UPLANETNAME` est défini.

---

## Créer le DNSLink d'un MULTIPASS

Chaque MULTIPASS expose son vault IPFS via `/ipns/$NOSTRNS`. Pour rendre ce vault accessible sous `alice.astroport.one` :

```bash
# YOUSER = slug dérivé de l'email via clyuseryomail.sh (ex: "alice")
# NOSTRNS = clef IPNS base36 (ex: "k51qzi5uqu5d...")
OVH_TOOL=~/.zen/Astroport.ONE/admin/system/ovh.me.sh

"$OVH_TOOL" upsert "${YOUSER}" "/ipns/${NOSTRNS}"
# → _dnslink.alice.astroport.one  TXT  "dnslink=/ipns/k51q..."
```

Ce record est créé automatiquement par `make_NOSTRCARD.sh` (création) et `NOSTRCARD.refresh.sh` (republication IPNS) si `ovh.me.sh` est disponible et les credentials OVH configurés.

---

## Déclencher une mise à jour DNSLink sans modifier earth/

Le script s'arrête avec `No change.` si le CID de `earth/` n'a pas changé. Pour forcer une mise à jour :

```bash
cd ~/workspace/AAA/UPlanet

# Option 1 : modifier un fichier quelconque
echo "# $(date)" >> earth/.dnslink-refresh
./microledger.me.sh
# Puis supprimer le fichier temporaire au prochain commit

# Option 2 : appeler directement la fonction de mise à jour
source ~/.zen/Astroport.ONE/tools/cooperative_config.sh
coop_load_env_from_config

IPFSEARTH=$(ipfs add -rq earth/ | tail -n 1)
source /path/to/microledger_functions.sh  # ou copier les fonctions manuellement
_dnslink_update "_dnslink"        "${OVH_ZONE:-astroport.one}" "$IPFSEARTH"
_dnslink_update "_dnslink.origin" "${OVH_ZONE:-astroport.one}" "$IPFSEARTH"
```

---

## Vérifier l'état actuel des enregistrements

```bash
# Via dig (DNS standard)
dig TXT _dnslink.astroport.one +short
dig TXT _dnslink.origin.astroport.one +short

# Via l'API OVH (nécessite les credentials)
source ~/.zen/Astroport.ONE/tools/cooperative_config.sh
coop_load_env_from_config

curl -s "https://eu.api.ovh.com/1.0/domain/zone/astroport.one/record?fieldType=TXT&subDomain=_dnslink"
```

---

## Vérifier qu'une gateway IPFS résout correctement

```bash
# Cloudflare IPFS gateway
curl -sI "https://cloudflare-ipfs.com/ipns/astroport.one" | grep -i "x-ipfs\|location\|content-type"

# Gateway locale (si IPFS tourne en local)
curl -sI "http://localhost:8080/ipns/astroport.one" | head -5
```

---

## Réduire le TTL pour une propagation plus rapide

Dans le Manager OVH (ou via l'API), passez le TTL de `_dnslink.astroport.one` à **60 secondes**. Cela accélère la propagation après chaque mise à jour.

```bash
# Via API OVH (après avoir les credentials en ENV)
RECORD_ID=$(curl -s "https://eu.api.ovh.com/1.0/domain/zone/astroport.one/record?fieldType=TXT&subDomain=_dnslink" | tr -d '[] ' | cut -d',' -f1)

# Mettre à jour le TTL (garder le target existant)
CURRENT_TARGET=$(curl -s "https://eu.api.ovh.com/1.0/domain/zone/astroport.one/record/${RECORD_ID}" | grep -o '"target":"[^"]*"' | cut -d'"' -f4)
curl -s -X PUT "https://eu.api.ovh.com/1.0/domain/zone/astroport.one/record/${RECORD_ID}" \
  -H "Content-Type: application/json" \
  -d "{\"target\":\"${CURRENT_TARGET}\",\"ttl\":60}"
```

---

## Diagnostiquer une erreur de signature OVH

Si vous voyez `ERROR OVH API (GET): {"message":"INVALID_CREDENTIAL"}` :

1. Vérifiez que les trois variables sont correctement définies :
```bash
echo "AK=${OVH_APP_KEY:0:6}... AS=${OVH_APP_SECRET:0:6}... CK=${OVH_CONSUMER_KEY:0:6}..."
```

2. Vérifiez la synchronisation horaire de la station (l'horloge doit être à ±30s de l'heure OVH) :
```bash
date -u && curl -s "https://eu.api.ovh.com/1.0/auth/time"
```

Si l'écart est important :
```bash
sudo ntpdate pool.ntp.org
# ou
sudo timedatectl set-ntp true
```
