# Victron MPPT BLE Monitor

Scanne et surveille un régulateur MPPT Victron (SmartSolar, etc.) via les
annonces Bluetooth LE "Instant Readout". Fonctionne aussi avec les autres
appareils Victron (BMV, Orion-XS, Smart Battery Protect...).

Intégré à Astroport.ONE comme module `victron` (voir `IA/modules.list`),
installable/pilotable via `astrosystemctl`.

## Installation sur la station

```bash
cd ~/.zen/Astroport.ONE
./install/install_victron.sh
```

Ce script :
- installe `bleak`, `victron-ble`, `pycryptodome` dans le venv `~/.astro`
- installe `bluez` si `bluetoothctl` est absent (apt/pacman/dnf)
- génère et active le service systemd `victron-mppt-monitor.service`
  (tourne sous l'utilisateur courant, pas besoin de root pour le scan BLE via BlueZ/D-Bus)

Suivi via `astrosystemctl status victron` / `astrosystemctl list`.

## 1. Trouver l'adresse MAC du régulateur

```bash
~/.astro/bin/python3 tools/victron/victron_monitor.py discover --duration 30
```

Approchez-vous du régulateur MPPT (portée BLE typique: quelques mètres) et
relancez la commande. Chaque appareil Victron avec "Instant Readout" activé
(par défaut sur les modèles récents) apparaît avec son adresse MAC.

## 2. Récupérer la clé de déchiffrement

Les advertisements Victron sont chiffrés (AES-CTR). La clé par appareil se
récupère dans l'app **VictronConnect** :

1. Ouvrir l'app, sélectionner le régulateur MPPT.
2. Icône réglages (roue dentée) → **Product info**.
3. Section **Instant Readout details** → bouton **Show** → copier la clé
   (32 caractères hexadécimaux).

## 3. Configurer les appareils à surveiller

La config vit dans `~/.zen/victron.json` — **hors du dépôt git** (elle
contient un secret : la clé de déchiffrement BLE). `install_victron.sh` la
crée automatiquement depuis `devices.example.json` si elle n'existe pas
encore.

```bash
cp devices.example.json ~/.zen/victron.json
```

Éditer `~/.zen/victron.json` :

```json
{
  "devices": [
    {
      "name": "MPPT Toit",
      "mac": "AA:BB:CC:DD:EE:FF",
      "key": "0123456789abcdef0123456789abcdef"
    }
  ]
}
```

## 4. Lancer la surveillance manuellement

```bash
~/.astro/bin/python3 tools/victron/victron_monitor.py monitor --config ~/.zen/victron.json
```

Exemple de sortie :

```
2026-09-13 14:32:01 [MPPT Toit / aa:bb:cc:dd:ee:ff] rssi=-62dBm  charge_state=bulk  battery_voltage=13.24  battery_charging_current=4.2  yield_today=350  solar_power=62  external_device_load=0.0
```

Champs disponibles (selon le modèle Victron) :

- `charge_state` : off / bulk / absorption / float / equalize / ...
- `charger_error` : code d'erreur du régulateur (`none` si aucune)
- `battery_voltage` (V), `battery_charging_current` (A)
- `solar_power` (W instantané), `yield_today` (Wh produits aujourd'hui)
- `external_device_load` (A, si une charge est branchée sur le régulateur)

Options utiles :

```bash
# Journaliser aussi dans un CSV (une ligne par lecture)
~/.astro/bin/python3 tools/victron/victron_monitor.py monitor --config ~/.zen/victron.json --csv readings.csv

# S'arrêter après N secondes (utile pour un test / cron)
~/.astro/bin/python3 tools/victron/victron_monitor.py monitor --config ~/.zen/victron.json --duration 60
```

## 5. Surveillance permanente (service systemd)

Géré par `install_victron.sh` (voir plus haut). Par défaut, le CSV et
l'historique quotidien agrégé sont écrits en local dans `~/.zen/game/victron/`
— **jamais** directement sous `~/.zen/tmp/$IPFSNODEID/`, qui est ré-ajouté à
IPFS en entier à chaque publication IPNS : un fichier qui grossit
indéfiniment y alourdirait la balise publiée un peu plus chaque jour (cette
règle vaut pour tout log longue durée diffusé par une station Astroport.ONE).

Seul le **CID** de l'historique agrégé (`victron_history.json`) est publié :
`victron_stats.sh publish-cid` l'épingle sur IPFS et écrit son CID dans un
petit fichier pointeur, `~/.zen/tmp/$IPFSNODEID/VICTRON/victron_history.json.ipfs`
(quelques octets, peu importe la taille de l'historique). Pour le lire
depuis le swarm : récupérer le CID via
`/ipns/$IPFSNODEID/VICTRON/victron_history.json.ipfs`, puis le contenu via
`/ipfs/<CID>`. Ce pointeur est régénéré chaque jour par `20h12.process.sh`.

```bash
sudo systemctl status victron-mppt-monitor
journalctl -u victron-mppt-monitor -f
```

## Notes

- Le déchiffrement se fait localement (aucune donnée n'est envoyée à
  Victron) : la lib `victron-ble` (MIT/Unlicense,
  https://github.com/keshavdv/victron-ble) implémente le format documenté
  par Victron (BLE Advertising Protocol PDF côté VictronConnect).
- Pas besoin d'appairage Bluetooth : tout passe par les paquets
  d'advertising BLE broadcastés en clair (chiffrés) par le régulateur.
- Si `discover` ne trouve rien : vérifier que "Instant Readout" est activé
  sur le régulateur (VictronConnect → réglages produit) et que vous êtes à
  moins de ~10-15 m à vue directe.
- Intégration constellation : `RUNTIME/ECONOMY.broadcast.sh` publie les
  agrégats (`victron_stats.sh solar-stats` : puissance instantanée, Wh
  jour/mois/total, tension batterie, état de charge) dans son événement
  NOSTR kind 30850, affichés dans `UPlanet/earth/economy.Swarm.html` et
  dans la page dédiée `UPlanet/earth/victron.html`. L'historique quotidien
  complet reste consultable via son CID publié (voir section précédente)
  pour un futur graphique multi-jours par station (non NOSTR — fichier
  épinglé sur IPFS, pointeur seul sous IPNS).
