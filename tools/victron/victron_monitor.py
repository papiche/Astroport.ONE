#!/usr/bin/env python3
"""
Scan & monitor Victron devices (SmartSolar MPPT, BMV, etc.) over BLE
"Instant Readout" advertisements.

Modes:
  discover   Listen for any Victron BLE advertisement and print MAC/name/RSSI.
             No encryption key needed - use this to find your MPPT's MAC address.
  monitor    Decrypt and print live readings for the devices listed in a config
             file (MAC + per-device encryption key). Optionally append each
             reading to a CSV log.

The per-device encryption key comes from the VictronConnect app:
  Device -> gear icon (Settings) -> Product info -> Instant Readout -> "Show".
"""
import argparse
import asyncio
import csv
import json
import logging
import sys
import time
from pathlib import Path

from bleak import BleakScanner
from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData
from victron_ble.exceptions import AdvertisementKeyMissingError, UnknownDeviceError
from victron_ble.scanner import BaseScanner, DiscoveryScanner
from victron_ble.devices import detect_device_type

logger = logging.getLogger("victron_monitor")


def load_config(path: Path) -> dict:
    with open(path) as f:
        cfg = json.load(f)
    return {d["mac"].lower(): d for d in cfg["devices"]}


class MonitorScanner(BaseScanner):
    """Decrypts advertisements for known devices and prints/logs a live reading."""

    def __init__(self, devices_by_mac: dict, csv_path: Path | None = None):
        super().__init__()
        # BlueZ's default scanning mode can miss weak/borderline-range Victron
        # advertisements; force active scanning for reliability.
        self._scanner = BleakScanner(
            detection_callback=self._detection_callback, scanning_mode="active"
        )
        self._devices_by_mac = devices_by_mac
        self._known_devices = {}
        self._csv_path = csv_path
        self._csv_header_written = csv_path.exists() if csv_path else False

    def get_device(self, ble_device: BLEDevice, raw_data: bytes):
        address = ble_device.address.lower()
        if address not in self._known_devices:
            key = self._devices_by_mac[address]["key"]
            device_klass = detect_device_type(raw_data)
            if not device_klass:
                raise UnknownDeviceError(f"Unknown device type for {ble_device}")
            self._known_devices[address] = device_klass(key)
        return self._known_devices[address]

    def callback(self, ble_device: BLEDevice, raw_data: bytes, advertisement: AdvertisementData):
        address = ble_device.address.lower()
        if address not in self._devices_by_mac:
            return  # not one of ours

        try:
            device = self.get_device(ble_device, raw_data)
        except AdvertisementKeyMissingError:
            logger.error(f"No key configured for {address}")
            return
        except UnknownDeviceError as e:
            logger.error(e)
            return

        parsed = device.parse(raw_data)
        friendly = self._devices_by_mac[address].get("name", address)
        row = self._extract_fields(parsed)
        row["timestamp"] = time.strftime("%Y-%m-%d %H:%M:%S")
        row["name"] = friendly
        row["mac"] = address
        row["rssi"] = advertisement.rssi

        self._print_line(row)
        if self._csv_path:
            self._append_csv(row)

    @staticmethod
    def _extract_fields(parsed) -> dict:
        fields = {}
        for attr in dir(parsed):
            if attr.startswith("get_"):
                value = getattr(parsed, attr)()
                if value is None:
                    continue
                if hasattr(value, "name"):  # Enum (charge_state, charger_error, ...)
                    value = value.name.lower()
                fields[attr[4:]] = value
        return fields

    @staticmethod
    def _print_line(row: dict):
        parts = [f"{row['timestamp']} [{row['name']} / {row['mac']}] rssi={row['rssi']}dBm"]
        for k, v in row.items():
            if k in ("timestamp", "name", "mac", "rssi"):
                continue
            parts.append(f"{k}={v}")
        print("  ".join(parts), flush=True)

    def _append_csv(self, row: dict):
        write_header = not self._csv_header_written
        self._csv_path.parent.mkdir(parents=True, exist_ok=True)
        with open(self._csv_path, "a", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(row.keys()))
            if write_header:
                writer.writeheader()
                self._csv_header_written = True
            writer.writerow(row)


async def run_discover(duration: float | None):
    print("Recherche d'appareils Victron (Instant Readout) en Bluetooth LE...")
    print("(Ctrl+C pour arreter)\n")
    scanner = DiscoveryScanner()
    # Force active scanning: passive/default mode misses weak/borderline-range
    # Victron advertisements on some BlueZ adapters.
    scanner._scanner = BleakScanner(
        detection_callback=scanner._detection_callback, scanning_mode="active"
    )
    await scanner.start()
    try:
        if duration:
            await asyncio.sleep(duration)
        else:
            while True:
                await asyncio.sleep(3600)
    finally:
        await scanner.stop()


async def run_monitor(config_path: Path, csv_path: Path | None, duration: float | None):
    devices_by_mac = load_config(config_path)
    print(f"Surveillance de {len(devices_by_mac)} appareil(s): "
          f"{', '.join(d.get('name', m) for m, d in devices_by_mac.items())}")
    scanner = MonitorScanner(devices_by_mac, csv_path)
    await scanner.start()
    try:
        if duration:
            await asyncio.sleep(duration)
        else:
            while True:
                await asyncio.sleep(3600)
    finally:
        await scanner.stop()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-v", "--verbose", action="store_true")
    sub = parser.add_subparsers(dest="mode", required=True)

    p_discover = sub.add_parser("discover", help="Trouver l'adresse MAC du regulateur MPPT")
    p_discover.add_argument("--duration", type=float, default=None, help="Duree du scan en secondes (defaut: illimite)")

    p_monitor = sub.add_parser("monitor", help="Lire les donnees en direct d'un ou plusieurs appareils")
    p_monitor.add_argument("--config", type=Path, default=Path.home() / ".zen" / "victron.json",
                            help="Fichier JSON {mac, key, name} (defaut: ~/.zen/victron.json)")
    p_monitor.add_argument("--csv", type=Path, default=None, help="Chemin d'un fichier CSV pour journaliser les lectures")
    p_monitor.add_argument("--duration", type=float, default=None, help="Duree en secondes (defaut: illimite)")

    args = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    try:
        if args.mode == "discover":
            asyncio.run(run_discover(args.duration))
        elif args.mode == "monitor":
            if not args.config.exists():
                sys.exit(f"Fichier de config introuvable: {args.config}\n"
                         f"Copiez devices.example.json vers {args.config} et renseignez mac/key.")
            asyncio.run(run_monitor(args.config, args.csv, args.duration))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
