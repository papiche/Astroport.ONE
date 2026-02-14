#!/usr/bin/env python3
"""
generate_powerjoular_graph.py

Génère un graphique de consommation électrique à partir d'un CSV PowerJoular
Format attendu (celui du service systemd 24h) :
Date,CPU Utilization,Total Power,CPU Power,GPU Power
2025-02-14 14:30:00,0.12,7.45,7.45,0.0
...
"""

import sys
import csv
import os
from datetime import datetime
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.dates as mdates


def parse_powerjoular_csv(csv_path):
    """
    Parse un CSV PowerJoular (format 5 colonnes du service 24h)
    Retourne: timestamps, total_power_W, cpu_power_W, gpu_power_W
    """
    if not os.path.isfile(csv_path):
        print(f"ERROR: Fichier introuvable : {csv_path}", file=sys.stderr)
        return None, None, None, None

    timestamps = []
    total_power = []
    cpu_power = []
    gpu_power = []

    try:
        with open(csv_path, newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            
            # Lire et vérifier l'en-tête
            try:
                header = next(reader)
                header = [h.strip() for h in header]
                expected = ["Date", "CPU Utilization", "Total Power", "CPU Power", "GPU Power"]
                if header != expected:
                    print(f"Warning: En-tête inattendu : {header}", file=sys.stderr)
                    # On continue quand même, au cas où c'est juste des espaces ou casse
            except StopIteration:
                print("ERROR: Fichier CSV vide", file=sys.stderr)
                return None, None, None, None

            for row in reader:
                if len(row) < 5:
                    continue
                try:
                    ts_str = row[0].strip()
                    timestamp = datetime.strptime(ts_str, '%Y-%m-%d %H:%M:%S')

                    total_p = float(row[2].strip())
                    cpu_p   = float(row[3].strip())
                    gpu_p   = float(row[4].strip()) if row[4].strip() else 0.0

                    timestamps.append(timestamp)
                    total_power.append(total_p)
                    cpu_power.append(cpu_p)
                    gpu_power.append(gpu_p)

                except (ValueError, IndexError):
                    continue  # ligne invalide → on passe

        if not timestamps:
            print(f"ERROR: Aucune donnée valide dans {csv_path}", file=sys.stderr)
            return None, None, None, None

        print(f"Données lues : {len(timestamps)} échantillons", file=sys.stderr)
        return timestamps, total_power, cpu_power, gpu_power

    except Exception as e:
        print(f"ERROR parsing CSV : {e}", file=sys.stderr)
        return None, None, None, None


def generate_graph(csv_file, output_file, title="Power Consumption"):
    timestamps, total_power, cpu_power, gpu_power = parse_powerjoular_csv(csv_file)
    if timestamps is None:
        return False

    # Figure avec deux sous-graphiques
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(13, 9), sharex=True)

    # Graphique 1 : Puissance totale
    ax1.plot(timestamps, total_power, 'b-', linewidth=1.8, label='Puissance totale système')
    ax1.fill_between(timestamps, total_power, alpha=0.18, color='blue')
    ax1.set_ylabel('Puissance (W)', fontsize=12, fontweight='bold')
    ax1.set_title(f'{title} – Puissance totale', fontsize=14, fontweight='bold')
    ax1.grid(True, alpha=0.25)
    ax1.legend(loc='upper right', fontsize=10)

    # Statistiques
    if total_power:
        avg_w  = sum(total_power) / len(total_power)
        max_w  = max(total_power)
        min_w  = min(total_power)

        # Calcul énergie (méthode trapèze)
        energy_j = 0.0
        for i in range(1, len(timestamps)):
            dt_sec = (timestamps[i] - timestamps[i-1]).total_seconds()
            if dt_sec <= 0:
                continue
            avg_interval = (total_power[i] + total_power[i-1]) / 2
            energy_j += avg_interval * dt_sec

        energy_kwh = energy_j / 3_600_000

        stats = (
            f"Moyenne : {avg_w:6.2f} W\n"
            f"Max     : {max_w:6.2f} W\n"
            f"Min     : {min_w:6.2f} W\n"
            f"Énergie : {energy_j:,.0f} J  ({energy_kwh:.5f} kWh)"
        )
        ax1.text(0.02, 0.98, stats, transform=ax1.transAxes,
                 fontsize=10, va='top', ha='left',
                 bbox=dict(boxstyle='round,pad=0.5', fc='ivory', alpha=0.85, ec='gray'))

    # Graphique 2 : CPU + GPU
    has_gpu = any(x > 0.01 for x in gpu_power)

    if has_gpu:
        ax2.plot(timestamps, cpu_power, 'limegreen', lw=1.6, label='CPU', alpha=0.9)
        ax2.plot(timestamps, gpu_power, 'tomato',    lw=1.6, label='GPU', alpha=0.9)
        ax2.set_title("Répartition CPU / GPU", fontsize=14, fontweight='bold')
        ax2.legend(loc='upper right', fontsize=10)
    else:
        ax2.plot(timestamps, cpu_power, 'limegreen', lw=1.8, label='CPU (seul)')
        ax2.set_title("Puissance CPU", fontsize=14, fontweight='bold')
        ax2.legend(loc='upper right', fontsize=10)

    ax2.set_ylabel('Puissance (W)', fontsize=12, fontweight='bold')
    ax2.grid(True, alpha=0.25)

    # Formatage de l'axe des temps
    ax2.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
    interval_min = max(1, (timestamps[-1] - timestamps[0]).total_seconds() // 600)
    ax2.xaxis.set_major_locator(mdates.MinuteLocator(interval=int(interval_min)))
    plt.setp(ax2.get_xticklabels(), rotation=40, ha='right', fontsize=9)

    ax2.set_xlabel('Heure', fontsize=12, fontweight='bold')

    # Titre global
    start_str = timestamps[0].strftime("%Y-%m-%d %H:%M")
    end_str   = timestamps[-1].strftime("%H:%M")
    fig.suptitle(f"{title} — {start_str} → {end_str}", 
                 fontsize=16, fontweight='bold', y=0.995)

    plt.tight_layout(rect=[0, 0, 1, 0.96])

    try:
        plt.savefig(output_file, dpi=160, bbox_inches='tight')
        plt.close(fig)
        print(f"Graphique généré : {output_file}")
        if total_power:
            print(f"Stats : Moy={avg_w:.2f} W | Max={max_w:.2f} W | Énergie={energy_kwh:.5f} kWh")
        return True
    except Exception as e:
        print(f"Erreur sauvegarde graphique : {e}", file=sys.stderr)
        plt.close(fig)
        return False


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: generate_powerjoular_graph.py <input.csv> <output.png> [titre optionnel]")
        sys.exit(1)

    csv_file   = sys.argv[1]
    output_img = sys.argv[2]
    title      = sys.argv[3] if len(sys.argv) > 3 else "Consommation électrique"

    success = generate_graph(csv_file, output_img, title)
    sys.exit(0 if success else 1)