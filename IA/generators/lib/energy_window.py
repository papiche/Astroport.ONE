#!/usr/bin/env python3
"""
energy_window.py — énergie consommée entre deux instants, d'après le CSV 24/7 de
PowerJoular (/var/lib/powerjoular/power_24h.csv, une ligne par seconde :
Date,CPU Utilization,Total Power,CPU Power,GPU Power).

Usage : energy_window.py <début epoch> <fin epoch> [--csv chemin] [--json]
Ne lit que la fin du fichier (il peut peser plusieurs Go).
Mesure CPU (RAPL) + GPU (NVIDIA) : RAM, disques, ventilateurs et pertes de
l'alimentation ne sont pas comptés.
"""

import argparse
import datetime
import json
import os
import sys


def tail_lines(path, count):
    """Dernières `count` lignes sans lire tout le fichier."""
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        pos, block, data = f.tell(), 1 << 20, b""
        while pos > 0 and data.count(b"\n") <= count:
            step = min(block, pos)
            pos -= step
            f.seek(pos)
            data = f.read(step) + data
    return data.decode(errors="ignore").splitlines()[-count:]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("start", type=int)
    parser.add_argument("end", type=int)
    parser.add_argument("--csv", default=os.environ.get("POWER_24H_CSV", "/var/lib/powerjoular/power_24h.csv"))
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    age = int(datetime.datetime.now().timestamp()) - args.start
    lines = tail_lines(args.csv, age + 600)
    total = cpu = gpu = peak = 0.0
    samples = 0
    for line in lines:
        parts = line.split(",")
        if len(parts) < 5 or parts[0] == "Date":
            continue
        try:
            t = datetime.datetime.strptime(parts[0], "%Y-%m-%d %H:%M:%S").timestamp()
            w_total, w_cpu, w_gpu = float(parts[2]), float(parts[3]), float(parts[4])
        except ValueError:
            continue
        if args.start <= t <= args.end:
            total += w_total
            cpu += w_cpu
            gpu += w_gpu
            peak = max(peak, w_total)
            samples += 1
    if not samples:
        print("Aucune mesure PowerJoular sur cette période", file=sys.stderr)
        sys.exit(1)

    # Un échantillon par seconde : somme des W = J ; / 3600 = Wh
    result = {
        "duree_s": args.end - args.start,
        "echantillons": samples,
        "energie_wh": round(total / 3600, 1),
        "cpu_wh": round(cpu / 3600, 1),
        "gpu_wh": round(gpu / 3600, 1),
        "puissance_moyenne_w": round(total / samples),
        "puissance_max_w": round(peak),
    }
    if args.json:
        print(json.dumps(result, ensure_ascii=False))
    else:
        print(f'{result["energie_wh"]} Wh en {result["duree_s"] // 60} min '
              f'(CPU {result["cpu_wh"]} Wh, GPU {result["gpu_wh"]} Wh, '
              f'moyenne {result["puissance_moyenne_w"]} W, pic {result["puissance_max_w"]} W)')


if __name__ == "__main__":
    main()
