# 🔄 Oracle System - Daily Maintenance

## Vue d'ensemble

Le script `ORACLE.refresh.sh` assure la maintenance quotidienne automatique du système Oracle. Il est exécuté chaque jour par `UPLANET.refresh.sh` pour gérer le cycle de vie des permis.

---

## 🎯 Fonctionnalités

### 1. **Vérification des demandes en attente**

- Récupère toutes les demandes de permis avec statut `pending` ou `attesting`
- Vérifie le nombre d'attestations reçues
- Compare avec le seuil requis (`min_attestations`)
- Déclenche l'émission du credential (30503) si le seuil est atteint

### 2. **Expiration des demandes anciennes**

- Identifie les demandes de plus de 90 jours
- Marque ces demandes comme expirées
- Permet de nettoyer les demandes abandonnées

### 3. **Révocation des credentials expirés**

- Vérifie tous les credentials existants
- Identifie ceux dont la date d'expiration est dépassée
- Marque les credentials expirés comme inactifs
- Permet la revalidation via nouvelle demande

### 4. **Génération de statistiques**

- Compte les demandes par type de permis
- Compte les credentials émis par type
- Crée des fichiers JSON de statistiques
- Statistiques globales et par permis

### 5. **Publication sur NOSTR**

- Publie un rapport quotidien signé par `UPLANETNAME.G1`
- Inclut les statistiques du jour
- Kind 1 event avec hashtags `#UPlanet #Oracle #WoT #Permits`

### 6. **Nettoyage**

- Supprime les fichiers temporaires de plus de 7 jours
- Maintient l'espace disque propre

---

## 📊 Processus détaillé

### Étape 1: Vérification API

```bash
ORACLE_API="${uSPOT:-http://127.0.0.1:54321}/api/permit"

# Vérifie que l'API est accessible
curl -s -f "${ORACLE_API}/definitions"
```

**Si l'API n'est pas disponible:** Le script s'arrête sans erreur (mode graceful).

### Étape 2: Traitement des demandes

```bash
# Récupère les demandes en attente
pending_requests=$(curl -s "${ORACLE_API}/list?type=requests&status=pending,attesting")

# Pour chaque demande
for request_id in $pending_requests; do
    # Récupère les détails
    request_data=$(curl -s "${ORACLE_API}/status/${request_id}")
    
    # Vérifie le seuil
    if [[ $attestations_count -ge $required_attestations ]]; then
        # Émet le credential
        curl -X POST "${ORACLE_API}/issue/${request_id}"
    fi
done
```

**Critères de validation:**
- Nombre d'attestations ≥ `min_attestations`
- Attestations signées par des détenteurs valides
- Demande non expirée

### Étape 3: Expiration automatique

```bash
# Calcule l'âge de la demande
age_days=$(( (now - created_at) / 86400 ))

# Expire si > 90 jours
if [[ $age_days -gt 90 ]]; then
    curl -X POST "${ORACLE_API}/expire/${request_id}"
fi
```

**Raisons d'expiration:**
- Plus de 90 jours sans validation complète
- Permet de relancer une nouvelle demande
- Évite l'accumulation de demandes obsolètes

### Étape 4: Statistiques

```bash
# Pour chaque type de permis
for permit_id in $permits; do
    requests_count=$(curl -s "${ORACLE_API}/list?type=requests&permit_id=${permit_id}")
    credentials_count=$(curl -s "${ORACLE_API}/list?type=credentials&permit_id=${permit_id}")
    
    # Sauvegarde en JSON
    echo '{"permit_id":"'$permit_id'","requests":'$requests_count',"issued":'$credentials_count'}' \
        > ~/.zen/tmp/${IPFSNODEID}/ORACLE/${permit_id}.json
done
```

**Fichiers créés:**
- `~/.zen/tmp/${IPFSNODEID}/ORACLE/PERMIT_ORE_V1.json`
- `~/.zen/tmp/${IPFSNODEID}/ORACLE/PERMIT_DRIVER.json`
- `~/.zen/tmp/${IPFSNODEID}/ORACLE/global_stats.json`

### Étape 5: Publication NOSTR

```bash
oracle_message="🔐 Oracle System Daily Report (${TODATE})

📊 Global Statistics:
• Total requests: ${total_requests}
• Total credentials issued: ${total_credentials}

🎯 Active Permits: ${permit_count}

🔗 View permits: ${myIPFS}/oracle

#UPlanet #Oracle #WoT #Permits"

# Signe avec UPLANETNAME.G1
nostr_send_note.py --keyfile <(echo "NSEC=${UPLANETG1NSEC}") \
    --content "$oracle_message" \
    --kind 1 \
    --relays "$myRELAY"
```

---

## 🕐 Planification

### Exécution quotidienne

Le script est appelé par `UPLANET.refresh.sh` qui tourne quotidiennement via cron:

```bash
# UPLANET.refresh.sh (ligne 42-46)
#################################################################
### ORACLE SYSTEM - Daily Permit Maintenance
echo "############################################"
${MY_PATH}/ORACLE.refresh.sh
echo "############################################"
#################################################################
```

### Ordre d'exécution

1. **ZEN.ECONOMY.sh** - Économie et transactions
2. **ORACLE.refresh.sh** ⭐ - Maintenance des permis
3. **NOSTR.UMAP.refresh.sh** - Rafraîchissement UMAP
4. **Boucle UMAP** - Mise à jour de chaque UMAP

---

## 📈 Cas d'usage

### Cas 1: Validation automatique d'une demande

**Contexte:** Alice a demandé PERMIT_ORE_V1 (5 attestations requises)

**Timeline:**
- **Jour 1:** Alice publie sa demande (30501)
- **Jour 2-5:** Bob, Carol, Dave, Eve, Frank attestent (30502)
- **Jour 6 (ORACLE.refresh.sh):**
  - Script détecte 5 attestations ≥ 5 requis
  - Émet le credential (30503) signé par UPLANETNAME.G1
  - Publie sur NOSTR
  - Met à jour le DID d'Alice

**Résultat:** Alice reçoit son credential automatiquement

### Cas 2: Expiration d'une demande abandonnée

**Contexte:** Bob a demandé PERMIT_DRIVER (12 attestations requises) mais n'a reçu que 3 attestations

**Timeline:**
- **Jour 1:** Bob publie sa demande
- **Jour 1-30:** Reçoit 3 attestations (insuffisant)
- **Jour 31-90:** Pas d'autres attestations
- **Jour 91 (ORACLE.refresh.sh):**
  - Script détecte âge > 90 jours
  - Marque la demande comme expirée
  - Bob peut relancer une nouvelle demande

**Résultat:** Demande nettoyée, Bob peut recommencer

### Cas 3: Révocation d'un credential expiré

**Contexte:** Carol a un PERMIT_MEDICAL_FIRST_AID valide 2 ans

**Timeline:**
- **An 1:** Credential émis (expires_at: 2027-10-30)
- **An 1-2:** Credential actif
- **An 3 (2027-10-31, ORACLE.refresh.sh):**
  - Script détecte expiration dépassée
  - Marque le credential comme "expired"
  - Carol doit renouveler son permis

**Résultat:** Credential révoqué, renouvellement nécessaire

---

## 🔧 Configuration

### Variables d'environnement

```bash
# API URL (défaut: http://127.0.0.1:54321)
export uSPOT="http://127.0.0.1:54321"

# Relay NOSTR (défaut: wss://relay.copylaradio.com)
export myRELAY="wss://relay.copylaradio.com"

# UPlanet name
export UPLANETNAME="EnfinLibre"

# IPFS Node ID
export IPFSNODEID="QmXXXXXXXXXXXXXXXXXXXXXX"
```

### Personnalisation

**Modifier le délai d'expiration (90 jours):**

Éditer `ORACLE.refresh.sh` ligne ~90:

```bash
# Changer 90 par le nombre de jours souhaité
if [[ $age_days -gt 90 ]]; then
```

**Changer la fréquence de publication NOSTR:**

Par défaut, le script publie un rapport quotidien. Pour modifier:

```bash
# Publier seulement si > 0 credentials émis aujourd'hui
if [[ $daily_issued -gt 0 ]]; then
    nostr_send_note.py ...
fi
```

---

## 📊 Statistiques générées

### Fichier global: `global_stats.json`

```json
{
    "total_requests": 42,
    "total_credentials": 38,
    "last_updated": "2025-10-30T12:00:00Z",
    "uplanet": "EnfinLibre",
    "ipfs_node": "QmXXXXXXXXXXXXXXXXX"
}
```

### Fichier par permis: `PERMIT_ORE_V1.json`

```json
{
    "permit_id": "PERMIT_ORE_V1",
    "permit_name": "ORE Environmental Verifier",
    "requests_count": 12,
    "credentials_count": 10,
    "last_updated": "2025-10-30T12:00:00Z"
}
```

---

## 🛠️ Dépannage

### L'API n'est pas disponible

**Symptôme:**
```
[WARNING] Oracle API not available at http://127.0.0.1:54321/api/permit
[INFO] Skipping Oracle maintenance (API not running)
```

**Solution:**
1. Vérifier que l'API UPassport tourne:
   ```bash
   ps aux | grep 54321.py
   ```
2. Démarrer l'API si nécessaire:
   ```bash
   cd UPassport
   python3 54321.py &
   ```

### Les credentials ne sont pas émis automatiquement

**Symptôme:**
Une demande a atteint le seuil mais pas de credential émis.

**Solutions:**
1. Vérifier que l'endpoint `/api/permit/issue/` existe dans `54321.py`
2. Vérifier les logs de l'API:
   ```bash
   tail -f ~/.zen/tmp/UPassport.log
   ```
3. Vérifier que `UPLANETNAME.G1` a la clé privée disponible

### Les statistiques ne sont pas créées

**Symptôme:**
Pas de fichiers dans `~/.zen/tmp/${IPFSNODEID}/ORACLE/`

**Solutions:**
1. Vérifier les permissions du répertoire:
   ```bash
   mkdir -p ~/.zen/tmp/${IPFSNODEID}/ORACLE
   chmod 755 ~/.zen/tmp/${IPFSNODEID}/ORACLE
   ```
2. Vérifier que `jq` est installé:
   ```bash
   sudo apt-get install jq
   ```

---

## 📖 Références

- **ORACLE_SYSTEM.md**: Documentation complète du système Oracle
- **ORACLE_WOT_BOOTSTRAP.md**: Initialisation de la WoT
- **ORACLE_NOSTR_FLOW.md**: Flux détaillé des événements NOSTR
- **UPLANET.refresh.sh**: Script parent de maintenance quotidienne

---

## 🎯 Améliorations futures

### 1. Notifications push

Envoyer des notifications NOSTR DM aux utilisateurs:
- Quand leur credential est émis
- Quand leur credential va expirer (7 jours avant)
- Quand leur demande est expirée

### 2. Métriques avancées

- Temps moyen entre demande et émission
- Taux de validation par permis
- Graphiques d'évolution

### 3. Backup automatique

Sauvegarder l'état du système Oracle:
- Base de données des credentials
- Événements NOSTR archivés
- Statistiques historiques

### 4. Webhooks

Déclencher des actions externes:
- Notification Telegram/Discord
- Mise à jour d'un dashboard web
- Synchronisation avec autres UPlanets

---

**Date:** 30 octobre 2025  
**Version:** 1.0  
**Auteur:** Assistant IA (Claude Sonnet 4.5)  
**Projet:** UPlanet / Astroport.ONE

