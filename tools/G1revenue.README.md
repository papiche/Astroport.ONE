# G1revenue.sh - Suivi du Chiffre d'Affaires UPlanet

## 📊 Description

`G1revenue.sh` est un script shell qui calcule le **Chiffre d'Affaires (CA)** de la coopérative UPlanet en analysant l'historique des transactions blockchain du portefeuille `UPLANETNAME` (hub de distribution des services).

## 🎯 Fonctionnalités

- ✅ **Calcul du CA total** en ẐEN et Ğ1
- ✅ **Filtrage par année** (2024, 2025, etc.)
- ✅ **Résumé annuel automatique** (CA par année)
- ✅ **Historique détaillé** des ventes RENTAL
- ✅ **Identification des clients** (email)
- ✅ **Sortie JSON structurée**

## 📋 Prérequis

- **Environnement configuré** : Variables `UPLANETG1PUB` et `UPLANETNAME_G1` dans `my.sh`
- **Script G1history.sh** : Doit être disponible dans le même répertoire
- **jq** : Processeur JSON en ligne de commande

## 🚀 Usage

### Syntaxe

```bash
./G1revenue.sh [YEAR]
```

### Paramètres

- `YEAR` : Année à filtrer (optionnel)
  - `all` ou aucun paramètre : Toutes les années
  - `2024`, `2025`, etc. : Année spécifique

### Exemples

```bash
# CA total (toutes années) avec résumé annuel
./G1revenue.sh
./G1revenue.sh all

# CA uniquement pour 2025
./G1revenue.sh 2025

# CA uniquement pour 2024
./G1revenue.sh 2024

# Formater la sortie avec jq
./G1revenue.sh | jq '.'

# Afficher uniquement le résumé annuel
./G1revenue.sh | jq '.yearly_summary'

# Afficher le CA de 2025
./G1revenue.sh 2025 | jq '{year: .filter_year, ca_zen: .total_revenue_zen, transactions: .total_transactions}'
```

## 📤 Format de Sortie JSON

### Structure Complète

```json
{
  "g1pub": "AwdjhpJNqzQgmSrvpUk5Fd2GxBZMJVQkBQmXn4JQLr6z",
  "filter_year": "all",
  "total_revenue_g1": 120.5,
  "total_revenue_zen": 1195.0,
  "total_transactions": 24,
  "yearly_summary": [
    {
      "year": "2025",
      "total_revenue_g1": 85.0,
      "total_revenue_zen": 840.0,
      "total_transactions": 17
    },
    {
      "year": "2024",
      "total_revenue_g1": 35.5,
      "total_revenue_zen": 355.0,
      "total_transactions": 7
    }
  ],
  "transactions": [
    {
      "date": "2025-10-09 14:20:15",
      "year": "2025",
      "customer_email": "frenault@linkeo.com",
      "amount_g1": 2.0,
      "amount_zen": 20.0,
      "transaction_type": "RENTAL",
      "comment": "Service RENTAL - UPLANET:AwdjhpJN:RENTAL:frenault@linkeo.com"
    }
  ],
  "timestamp": "2025-10-09T16:30:42"
}
```

### Champs Principaux

| Champ | Type | Description |
|-------|------|-------------|
| `g1pub` | string | Clé publique du portefeuille UPLANETNAME |
| `filter_year` | string | Année filtrée ("all" ou "YYYY") |
| `total_revenue_g1` | number | CA total en Ğ1 |
| `total_revenue_zen` | number | CA total en ẐEN |
| `total_transactions` | number | Nombre de ventes RENTAL |
| `yearly_summary` | array | Résumé CA par année (mode "all" uniquement) |
| `transactions` | array | Liste des transactions (max 100) |
| `timestamp` | string | Date/heure de génération |

## 🔍 Logique de Calcul du CA

### Critères de Filtrage

Le script filtre les transactions selon ces critères :

1. **Direction** : INCOMING (entrantes) vers `UPLANETG1PUB`
2. **Émetteur** : Provient de `UPLANETNAME_G1` (réserve)
3. **Référence** : Contient "RENTAL" (ventes de services)

### Format de Référence RENTAL

```
UPLANET:${UPLANETG1PUB:0:8}:RENTAL:${email}
```

**Exemple** :
```
UPLANET:AwdjhpJN:RENTAL:bidule@machintruc.com
```

### Formule de Conversion

```
ẐEN = (Ğ1 - 1) × 10
```

**Exemple** : 
- Transaction de 2.0 Ğ1
- CA = (2.0 - 1) × 10 = **10 Ẑ**

## 🏗️ Architecture Économique

```
┌─────────────────────────────────────────────┐
│ UPLANETNAME_G1 (Réserve Ğ1)                │
│ Conversion EUR → ẐEN (OpenCollective)      │
└─────────────────────────────────────────────┘
               ↓ ÉMISSION (CA)
┌─────────────────────────────────────────────┐
│ UPLANETNAME (UPLANETG1PUB)                 │
│ Hub de distribution des services            │
│ Historique RENTAL = Chiffre d'Affaires     │
└─────────────────────────────────────────────┘
               ↓ DISTRIBUTION
┌─────────────────────────────────────────────┐
│ MULTIPASS (NOSTR) + ZEN Card (PLAYERS)     │
│ Services actifs pour utilisateurs           │
└─────────────────────────────────────────────┘
```

## 🔗 Intégration API

Ce script est appelé par l'endpoint FastAPI `/check_revenue` dans `54321.py` :

```python
# API UPassport (54321.py)
@app.get("/check_revenue")
async def check_revenue_route(year: Optional[str] = None):
    script_path = "~/.zen/Astroport.ONE/tools/G1revenue.sh"
    year_filter = year if year else "all"
    result = subprocess.run([script_path, year_filter], ...)
    return json.loads(result.stdout)
```

### Endpoints API

- `GET /check_revenue` → JSON (toutes années)
- `GET /check_revenue?year=2025` → JSON (année 2025)
- `GET /check_revenue?html=1` → Page HTML stylisée
- `GET /check_revenue?html=1&year=2024` → Page HTML (année 2024)

## 📊 Affichage dans economy.html

Le CA est affiché dans le dashboard économique UPlanet :

```html
📡 Chiffre d'Affaires (UPLANETG1PUB)
├─ CA total : 1195 Ẑ
├─ 24 ventes RENTAL
└─ [💼 Historique CA] → Lien vers /check_revenue?html=1
```

## 🛠️ Dépannage

### Erreur : "UPLANETG1PUB not configured"

```bash
# Vérifier la configuration
source ~/.zen/Astroport.ONE/tools/my.sh
echo "UPLANETG1PUB=$UPLANETG1PUB"
```

### Erreur : "Invalid JSON response"

```bash
# Vérifier G1history.sh
./G1history.sh "$UPLANETG1PUB" 2>/dev/null | head -20
```

### CA vide (0 transaction)

C'est normal si aucune vente RENTAL n'a encore été effectuée. Testez avec :

```bash
cd /home/fred/workspace/AAA/Astroport.ONE
./UPLANET.official.sh -l test@example.com -m 20
```

## 📚 Fichiers Associés

| Fichier | Description |
|---------|-------------|
| `G1revenue.sh` | Script principal de calcul CA |
| `G1history.sh` | Récupère l'historique blockchain |
| `UPLANET.official.sh` | Gère les transactions RENTAL |
| `54321.py` | API FastAPI avec endpoint `/check_revenue` |
| `templates/revenue.html` | Template HTML pour affichage CA |
| `economy.html` | Dashboard économique UPlanet |
| `UPASSPORT_API.md` | Documentation API complète |

## 🔄 Flux de Données

```
1. Client → UPLANET.official.sh (recharge MULTIPASS)
2. Transaction RENTAL → Blockchain Ğ1
3. G1history.sh → Récupère historique
4. G1revenue.sh → Calcule CA + filtre RENTAL
5. 54321.py → API JSON/HTML
6. economy.html → Affichage dashboard
```

## 📈 Évolutions Futures

- [ ] **Statistiques mensuelles** (CA par mois)
- [ ] **Graphiques de tendance** (croissance CA)
- [ ] **Top clients** (classement par CA)
- [ ] **Prévisions CA** (ML sur historique)
- [ ] **Export CSV/Excel** (reporting comptable)
- [ ] **Alertes CA** (seuils personnalisés)

## 📝 Changelog

### Version 1.0 (2025-10-09)
- ✅ Calcul CA total depuis transactions RENTAL
- ✅ Filtrage par année
- ✅ Résumé annuel automatique
- ✅ Sortie JSON structurée
- ✅ Intégration API `/check_revenue`
- ✅ Affichage dans `economy.html`

## 📄 Licence

AGPL-3.0 - Voir [LICENSE](../LICENSE) pour plus de détails.

## 👤 Auteur

Fred (support@qo-op.com) - Astroport.ONE / UPlanet ẐEN

## 🔗 Liens Utiles

- [UPASSPORT_API.md](../UPASSPORT_API.md) - Documentation API complète
- [UPLANET.official.README.md](../UPLANET.official.README.md) - Guide des virements officiels
- [ZEN.ECONOMY.readme.md](../RUNTIME/ZEN.ECONOMY.readme.md) - Système économique UPlanet




