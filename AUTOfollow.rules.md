# AUTOfollow.rules.md - Système de Gestion Automatique des Follow NOSTR

## 📋 Vue d'ensemble

Le système UPlanet implémente un réseau NOSTR auto-organisé où les follow sont gérés automatiquement selon des règles précises. Ce document détaille les mécanismes de follow automatique et leurs implémentations.

## 🎯 Principes Fondamentaux

### 1. **Follow Bidirectionnel**
- Chaque nouvelle identité suit automatiquement le capitaine
- Le capitaine suit automatiquement chaque nouvelle identité
- **Référence** : [`tools/make_NOSTRCARD.sh:422-448`](tools/make_NOSTRCARD.sh#L422-L448)

### 2. **Renouvellement Automatique**
- Le capitaine renouvelle ses follow lors de l'activation du mode DRAGON
- Suit toutes les identités existantes et les nœuds UMAP actifs
- **Référence** : [`RUNTIME/DRAGON_p2p_ssh.sh:110-121`](RUNTIME/DRAGON_p2p_ssh.sh#L110-L121)

### 3. **Gestion Géographique**
- Les nœuds UMAP suivent automatiquement les utilisateurs de leur zone
- Mise à jour nocturne des relations géographiques
- **Référence** : [`RUNTIME/NOSTR.UMAP.refresh.sh:1907-1924`](RUNTIME/NOSTR.UMAP.refresh.sh#L1907-L1924)

## 🔧 Scripts de Gestion des Follow

### Core Scripts

#### `nostr_follow.sh`
**Rôle** : Script central pour gérer les follow NOSTR
```bash
# Usage: nostr_follow.sh <SOURCE_NSEC> <DESTINATION_HEX1> [DESTINATION_HEX2...] [RELAY]
```
**Fonctionnalités** :
- Ajoute des utilisateurs à une liste de follow (kind 3)
- Gère les follow existants (évite les doublons)
- Support multi-relais
- **Référence** : [`tools/nostr_follow.sh:1-96`](tools/nostr_follow.sh#L1-L96)

#### `nostr_followers.sh`
**Rôle** : Trouve qui suit un utilisateur donné
```bash
# Usage: ./nostr_followers.sh <npub_hex>
```
**Référence** : [`tools/nostr_followers.sh:1-8`](tools/nostr_followers.sh#L1-L8)

### Scripts d'Application

#### 1. Création d'Identité - `make_NOSTRCARD.sh`

**Follow Bidirectionnel lors de la création d'une nouvelle identité** :

```bash
### MULTIPASS FOLLOWS CAPTAIN AUTOMATICALLY
# New MULTIPASS should follow the CAPTAIN to receive updates and guidance
if [[ -s ~/.zen/game/nostr/${CAPTAINEMAIL}/HEX ]]; then
    CAPTAINHEX=$(cat ~/.zen/game/nostr/${CAPTAINEMAIL}/HEX)
    echo "👥 MULTIPASS ${EMAIL} following CAPTAIN ${CAPTAINEMAIL} (${CAPTAINHEX})"
    ${MY_PATH}/../tools/nostr_follow.sh "$NPRIV" "$CAPTAINHEX" "$myRELAY" 2>/dev/null \
        && echo "✅ MULTIPASS now follows CAPTAIN" \
        || echo "⚠️  Failed to follow CAPTAIN (will retry later)"
fi

### CAPTAIN FOLLOWS NEW MULTIPASS AUTOMATICALLY
# CAPTAIN should follow the new MULTIPASS to monitor and provide support
if [[ -s ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr ]]; then
    CAPTAINNSEC=$(grep "NSEC=" ~/.zen/game/nostr/${CAPTAINEMAIL}/.secret.nostr | cut -d '=' -f 2)
    if [[ -n "$CAPTAINNSEC" ]]; then
        echo "👥 CAPTAIN ${CAPTAINEMAIL} following new MULTIPASS ${EMAIL} (${HEX})"
        ${MY_PATH}/../tools/nostr_follow.sh "$CAPTAINNSEC" "$HEX" "$myRELAY" 2>/dev/null \
            && echo "✅ CAPTAIN now follows new MULTIPASS" \
            || echo "⚠️  Failed to follow new MULTIPASS (will retry later)"
    fi
fi
```

**Référence** : [`tools/make_NOSTRCARD.sh:422-448`](tools/make_NOSTRCARD.sh#L422-L448)

#### 2. Support Technique - `DRAGON_p2p_ssh.sh`

**Renouvellement complet des follow du capitaine** :

```bash
## FOLLOW EVERY NOSTR CARD
nostrhex=($(cat ~/.zen/game/nostr/*@*.*/HEX))
${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "${nostrhex[@]}" 2>/dev/null

## FOLLOW EVERY ACTIVE UMAP NODE
if [[ -d ~/.zen/tmp/${IPFSNODEID}/UPLANET ]]; then
    umaphex=($(cat ~/.zen/tmp/${IPFSNODEID}/UPLANET/__/_*/*/*/HEX 2>/dev/null))
    if [[ ${#umaphex[@]} -gt 0 ]]; then
        echo "Following ${#umaphex[@]} active UMAP nodes"
        ${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "${umaphex[@]}" 2>/dev/null
    fi
fi
```

**Référence** : [`RUNTIME/DRAGON_p2p_ssh.sh:110-121`](RUNTIME/DRAGON_p2p_ssh.sh#L110-L121)

#### 3. Gestion Géographique - `NOSTR.UMAP.refresh.sh`

**Mise à jour des follow basés sur la géolocalisation** :

```bash
update_friends_list() {
    local friends=("$@")
    
    # Get UPlanet UMAP NSEC with LAT and LON
    local UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    
    # Update friends list using nostr_follow.sh
    if [[ ${#friends[@]} -gt 0 ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            $MY_PATH/../tools/nostr_follow.sh "$UMAPNSEC" "${friends[@]}" "$myRELAY"
        else
            $MY_PATH/../tools/nostr_follow.sh "$UMAPNSEC" "${friends[@]}" "$myRELAY" 2>&1 | grep -v "Already following" | grep -v "Verification successful" | grep -v "Sending event" | grep -v "Response from" | grep -v "EVENT" | grep -v "Follow list updated" | sed 's/\x1b\[[0-9;]*m//g'
        fi
        log_always "(${LAT} ${LON}) Updated friends list with ${#friends[@]} active friends"
    else
        log_always "(${LAT} ${LON}) No active friends to update"
    fi
}
```

**Référence** : [`RUNTIME/NOSTR.UMAP.refresh.sh:1907-1924`](RUNTIME/NOSTR.UMAP.refresh.sh#L1907-L1924)

#### 4. Hiérarchie UPlanet - `UPLANET.refresh.sh`

**Follow de l'UPlanet Origin** :

```bash
originpub=$(${MY_PATH}/../tools/keygen -t nostr "0000000000000000000000000000000000000000000000000000000000000000" "0000000000000000000000000000000000000000000000000000000000000000")
originhex=$(${MY_PATH}/../tools/nostr2hex.py $originpub)
if [[ ${UPLANETNAME} == "0000000000000000000000000000000000000000000000000000000000000000" ]]; then
    echo "UPLANET ORIGIN : Seek for ${originhex} followers"
    ${MY_PATH}/../tools/nostr_followers.sh "${originhex}"
else
    ## UPLANET Ẑen ---- > follow UPlanet ORIGIN
    originhex=$(${MY_PATH}/../tools/nostr2hex.py $originpub)
    echo "UPLANET ZEN - follow -> UPlanet ORIGIN : ${originhex}"
    ${MY_PATH}/../tools/nostr_follow.sh "$UPLANETNSEC" "${originhex}"
fi
```

**Référence** : [`RUNTIME/UPLANET.refresh.sh:300-310`](RUNTIME/UPLANET.refresh.sh#L300-L310)

#### 5. Communication IA - `UPlanet_IA_Responder.sh`

**Follow automatique des interlocuteurs** :

```bash
## UMAP FOLLOW NOSTR CARD
if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    #######################################################################
    # UMAP FOLLOW PUBKEY -> Used nightly to create Journal "NOSTR.UMAP.refresh.sh"
    ${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY" 2>/dev/null
    #######################################################################
fi
```

**Référence** : [`IA/UPlanet_IA_Responder.sh:457-463`](IA/UPlanet_IA_Responder.sh#L457-L463)

## 📊 Matrice des Follow

| **Script** | **Qui Suit** | **Qui Est Suivi** | **Objectif** | **Moment** |
|------------|--------------|-------------------|---------------|------------|
| `make_NOSTRCARD.sh` | MULTIPASS | CAPTAIN | Guidance | Création identité |
| `make_NOSTRCARD.sh` | CAPTAIN | MULTIPASS | Surveillance | Création identité |
| `DRAGON_p2p_ssh.sh` | CAPTAIN | TOUTES identités | Support technique | Activation DRAGON |
| `NOSTR.UMAP.refresh.sh` | UMAP | Amis géographiques | Réseau local | Refresh nocturne |
| `UPLANET.refresh.sh` | UPLANET | ORIGIN | Hiérarchie | Refresh UPlanet |
| `UPlanet_IA_Responder.sh` | UMAP/IA | Interlocuteurs | Communication | Réponse IA |

## 🔄 Cycle de Vie des Follow

### Phase 1 : Création d'Identité
1. **MULTIPASS suit CAPTAIN** → Guidance et mises à jour
2. **CAPTAIN suit MULTIPASS** → Surveillance et support

### Phase 2 : Support Technique
1. **CAPTAIN suit TOUTES les identités** → Renouvellement complet
2. **CAPTAIN suit TOUS les nœuds UMAP** → Géolocalisation

### Phase 3 : Gestion Géographique
1. **UMAP suit les amis actifs** → Réseau local
2. **Mise à jour nocturne** → Relations géographiques

### Phase 4 : Communication IA
1. **UMAP suit les interlocuteurs** → Communication géolocalisée
2. **CAPTAIN suit en fallback** → Sécurité

## 🛠️ Outils de Support

### Scripts Utilitaires
- **`nostr_follow.sh`** : Gestion des follow (ajout/suppression)
- **`nostr_followers.sh`** : Analyse des followers
- **`nostr_setup_profile.py`** : Configuration des profils NOSTR

### Variables d'Environnement
- **`CAPTAINEMAIL`** : Email du capitaine
- **`CAPTAINHEX`** : Clé publique hex du capitaine
- **`CAPTAINNSEC`** : Clé privée NSEC du capitaine
- **`myRELAY`** : Relais NOSTR principal

## 📈 Avantages du Système

1. **Réseau Dense** : Chaque identité est connectée au réseau
2. **Support Automatique** : Le capitaine peut aider tous les utilisateurs
3. **Géolocalisation** : Follow basé sur la proximité géographique
4. **IA Réactive** : L'IA suit automatiquement ses interlocuteurs
5. **Hiérarchie** : Structure claire UPlanet → Origin
6. **Auto-Réparation** : Renouvellement automatique des follow

## 🔍 Dépannage

### Vérification des Follow
```bash
# Vérifier qui suit une identité
./tools/nostr_followers.sh <hex_pubkey>

# Vérifier les follow d'une identité
./tools/nostr_follow.sh <nsec> <hex_pubkey>
```

### Logs de Debug
- Les scripts affichent des messages de succès/échec
- Utiliser `VERBOSE=true` pour plus de détails
- Vérifier les fichiers `.secret.nostr` pour les clés

## 📝 Notes d'Implémentation

- Tous les follow utilisent le protocole NOSTR standard (kind 3)
- Les clés sont stockées de manière sécurisée dans `.secret.nostr`
- Le système gère automatiquement les doublons
- Les follow sont publiés sur les relais configurés
- Le système est résilient aux échecs (retry automatique)

---

**Dernière mise à jour** : $(date -u +"%Y-%m-%dT%H:%M:%SZ")  
**Version** : 1.0  
**Auteur** : Système UPlanet
