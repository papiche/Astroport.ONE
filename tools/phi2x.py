#!/usr/bin/env python3
"""
phi2x.py — Moteur de résonance Phi2X
Référence canonique partagée entre KIN.daily.sh, UPassport, et les scripts Astroport.

Toutes les constantes et formules sont synchronisées avec :
  - cabine-33/autoloads/Phi2X_Math.gd  (Godot/GDScript)
  - UPlanet/earth/phi2x.js             (JavaScript/Web)

Usage standalone :
  python3 phi2x.py --phase 1985-04-17 15:30 48.86 2.35
  python3 phi2x.py --omega 1.73 70.0 0
  python3 phi2x.py --kin 1985 4 17
  python3 phi2x.py --k 1.234 0.987
"""
import math, sys, argparse

# ── Constantes canoniques ────────────────────────────────────────────────────
PHI              = 1.6180339887          # Nombre d'Or
F_PHI            = 33.17                 # Fréquence Phi [Hz]
F_2              = 31.32                 # Fréquence Octave [Hz]
F_WATER          = 429.62               # Fréquence eau physiologique [Hz]
WAVE_STRETCH     = F_PHI / F_2          # ≈ 1.059 — multiplicateur d'onde (PAS un modulo)
TAU              = 2 * math.pi
ORBITAL_YEAR_S   = 365.25636 * 86400   # Année sidérale [s] — cohérent avec les disclosures tdcommons
ORBITAL_DAY_S    = 86400               # Jour [s]
HEX_SIZE_KM      = 1.0
EARTH_RADIUS_KM  = 6371.0

# 12 pentagones du polyèdre de Goldberg (époque J2000, coordonnées GPS lat/lon)
PENTAGONS_GPS = [
    (90.0,   0.0),   # 0  — Pôle Nord (fixe)
    (-90.0,  0.0),   # 1  — Pôle Sud (fixe)
    (26.56,  0.0),   (26.56, 72.0),  (26.56,  144.0),
    (26.56, -72.0),  (26.56,-144.0),
    (-26.56, 36.0),  (-26.56,108.0), (-26.56, 180.0),
    (-26.56,-36.0),  (-26.56,-108.0),
]

# Calendrier Kin Maya
KIN_GLYPHS_FR = ['Dragon','Vent','Nuit','Graine','Serpent','Lieur','Main','Étoile',
                  'Lune','Chien','Singe','Chemin','Roseau','Jaguar','Aigle','Guerrier',
                  'Terre','Miroir','Tempête','Soleil']
KIN_TONES_FR  = ['Magnétique','Lunaire','Électrique','Auto-existante','Harmonique',
                  'Rythmique','Résonnante','Galactique','Solaire','Planétaire',
                  'Spectrale','Cristal','Cosmique']
KIN_COLORS    = ['Rouge','Blanc','Bleu','Jaune','Vert']
KIN_MESES     = [0,31,59,90,120,151,181,212,243,13,44,74]
KIN_SUMA      = {30:2,35:7,40:12,45:17,50:22,3:27,8:32,13:37,18:42,23:47,28:52,
                 32:57,38:62,42:67,48:72,1:76,6:82,11:87,16:92,21:97,26:102,31:107,
                 36:112,41:117,46:122,51:127,4:132,9:137,14:142,19:147,24:152,29:157,
                 34:162,39:167,44:172,49:177,2:182,7:187,12:192,17:197,22:202,27:207,
                 37:217,47:227,0:232,5:237,10:242,15:247,20:252,25:257}

# ── Haversine ────────────────────────────────────────────────────────────────
def haversine_km(lat1, lon1, lat2, lon2):
    r = EARTH_RADIUS_KM
    φ1, φ2 = math.radians(lat1), math.radians(lat2)
    dφ = math.radians(lat2 - lat1)
    dλ = math.radians(lon2 - lon1)
    a = math.sin(dφ/2)**2 + math.cos(φ1)*math.cos(φ2)*math.sin(dλ/2)**2
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

# ── Pentagon offset (moyenne circulaire pondérée exponentielle) ──────────────
def _pentagon_offset(lat, lon):
    """Moyenne circulaire pondérée exp(-d/1500) sur les 12 pentagones."""
    sum_sin = sum_cos = 0.0
    for i, (plat, plon) in enumerate(PENTAGONS_GPS):
        d = haversine_km(lat, lon, plat, plon)
        w = math.exp(-d / 1500.0)
        angle = i / 12.0 * TAU
        sum_sin += math.sin(angle) * w
        sum_cos += math.cos(angle) * w
    result = math.atan2(sum_sin, sum_cos)
    return result if result >= 0.0 else result + TAU

# ── Calcul phase personnelle φ_i ─────────────────────────────────────────────
def compute_personal_phase(birth_unix: int, birth_lat: float, birth_lon: float,
                            utc_offset_h: float = 0.0) -> float:
    """
    φ_i ∈ [0, 2π) — phase personnelle issue des données de naissance.

    Formule canonique :
      θ_annual = fmod(birth_unix_utc, ORBITAL_YEAR_S) / ORBITAL_YEAR_S * 2π
      θ_daily  = fmod(birth_unix_solar, ORBITAL_DAY_S) / ORBITAL_DAY_S * 2π
      Δφ_penta = _pentagon_offset(lat, lon)   [moyenne circulaire pondérée exp]
      φ_i      = fmod((θ_annual + θ_daily + Δφ_penta) * WAVE_STRETCH, 2π)

    WAVE_STRETCH = F_PHI/F_2 ≈ 1.059 est un multiplicateur d'onde,
    PAS un modulo (erreur corrigée par rapport à l'implémentation originale atomic.html).
    """
    utc_corr_s   = -utc_offset_h * 3600.0
    solar_corr_s = birth_lon / 360.0 * ORBITAL_DAY_S

    theta_annual = (birth_unix % ORBITAL_YEAR_S) / ORBITAL_YEAR_S * TAU
    birth_solar  = float(birth_unix) + utc_corr_s + solar_corr_s
    theta_daily  = (birth_solar % ORBITAL_DAY_S) / ORBITAL_DAY_S * TAU
    offset_penta = _pentagon_offset(birth_lat, birth_lon)

    return math.fmod((theta_annual + theta_daily + offset_penta) * WAVE_STRETCH, TAU)

# ── Résonance k ──────────────────────────────────────────────────────────────
def compute_resonance_k(phi_i: float, phi_j: float) -> float:
    """k = 1 / (1 + |sin(Δφ)|) ∈ [0.5, 1.0]"""
    return 1.0 / (1.0 + abs(math.sin(phi_i - phi_j)))

def is_optical_singularity(phi_i: float, phi_j: float, tol: float = 0.05) -> bool:
    """Singularité optique : Condition A (Δφ≈0) OU Condition B (Δφ≈π)."""
    delta = abs(phi_i - phi_j)
    return delta < tol or abs(delta - math.pi) < tol

# ── Vérification a4l_proof (NIP-101 / Kind 30078) ────────────────────────────
def verify_a4l_proof(pubkey_hex: str, proof: str, salt: str = "ATOM4LOVE_v1") -> bool:
    """Vérifie SHA256(pubkey_hex + ':' + salt) == proof."""
    import hashlib
    expected = hashlib.sha256(f"{pubkey_hex}:{salt}".encode()).hexdigest()
    return expected == proof

def compute_a4l_proof(pubkey_hex: str, salt: str = "ATOM4LOVE_v1") -> str:
    """Calcule le a4l_proof pour un pubkey donné (utile pour les tests)."""
    import hashlib
    return hashlib.sha256(f"{pubkey_hex}:{salt}".encode()).hexdigest()

def parse_kind30078(event: dict) -> dict:
    """
    Parse un événement NOSTR Kind 30078 d=atom4love.
    Retourne un dict normalisé avec tous les champs ATOM4LOVE (v1 et v2).
    Retourne {} si l'événement est invalide ou le proof incorrect.
    """
    if event.get("kind") != 30078: return {}
    tags = {t[0]: t[1] for t in event.get("tags", []) if len(t) >= 2}
    if tags.get("d") != "atom4love": return {}

    import json
    try:
        content = json.loads(event.get("content", "{}"))
    except Exception:
        return {}

    pubkey = event.get("pubkey", "")
    proof  = tags.get("a4l_proof", "")
    if proof and pubkey and not verify_a4l_proof(pubkey, proof):
        return {}  # Proof invalide — rejeter

    phi   = float(content.get("personal_phase", 0) or 0)
    omega = float(content.get("omega_bio", 0)       or 0)
    if phi <= 0 or phi >= TAU * 1.1: return {}  # Hors plage physique

    return {
        "pubkey":         pubkey,
        "personal_phase": phi,
        "omega_bio":      omega,
        "biological_sex": int(content.get("biological_sex", 0) or 0),
        "kin_num":        int(content.get("kin_num", 0)         or 0),
        "inst_id":        int(content.get("inst_id", 0)         or 0),
        "app_version":    int(content.get("version", 1)         or 1),
        "a4l_proof":      proof,
        "proof_valid":    bool(proof and pubkey),
        "created_at":     event.get("created_at", 0),
    }

def parse_kind7_resonance(event: dict) -> dict:
    """
    Parse un événement Kind 7 de résonance ATOM4LOVE.
    Distingue des paiements ẐEN : k ∈ [0.45, 1.0] (décimal < 1).
    Note : 7.sh (NIP-101) traite les content '+N' entiers comme paiements ẐEN —
    les résonances '+k' décimales < 1.0 ne sont jamais interprétées comme paiements.
    """
    if event.get("kind") != 7: return {}
    content = event.get("content", "")
    import re
    m = re.search(r'\+?([0-9]+\.[0-9]+)', content)
    if not m: return {}
    k = float(m.group(1))
    if not (0.45 <= k <= 1.0): return {}

    tags = {t[0]: t[1] for t in event.get("tags", []) if len(t) >= 2}
    return {
        "pubkey_from": event.get("pubkey", ""),
        "pubkey_to":   tags.get("p", ""),
        "k":           k,
        "is_singularity": k >= 0.95,
        "created_at":  event.get("created_at", 0),
    }

# ── ω_bio (fréquence biologique) ─────────────────────────────────────────────
def compute_omega_bio(height_cm: float, weight_kg: float, sex: int) -> float:
    """
    ω_bio = F_WATER × (water_kg / 70.0)
    Formule Watson TBW (sans âge) — synchronisée avec phi2x.js et Phi2X_Math.gd :
    ♂ Φ-wave  : TBW = 0.1074·h + 0.3362·w − 5.0
    ♀ Octave  : TBW = 0.1069·h + 0.2466·w − 2.0
    """
    if sex == 0:
        water_kg = max(0.1074 * height_cm + 0.3362 * weight_kg - 5.0, 1.0)
    else:
        water_kg = max(0.1069 * height_cm + 0.2466 * weight_kg - 2.0, 1.0)
    return F_WATER * (water_kg / 70.0)

# ── Calendrier Kin Maya ──────────────────────────────────────────────────────
def calc_kin(year: int, month: int, day: int) -> dict:
    """
    Calcule le Kin Tzolkin à partir d'une date grégorienne.
    Utilise KIN_MESES + KIN_SUMA (cycle 52 ans) sans Julian Day Number.
    """
    if not (1 <= month <= 12 and 1 <= day <= 31):
        return {}
    kin = day + KIN_MESES[month - 1] + KIN_SUMA.get(year % 52, 0)
    if kin > 260: kin -= 260
    if kin <= 0:  kin += 260
    gi = (kin - 1) % 20
    ti = (kin - 1) % 13
    ci = ((kin - 1) // 13) % 5
    return {
        "kin": kin, "gi": gi, "ti": ti, "ci": ci,
        "glyph_fr": KIN_GLYPHS_FR[gi],
        "tone_fr":  KIN_TONES_FR[ti],
        "color_fr": KIN_COLORS[ci],
        "tone_num": ti + 1,         # 1-13
        "lfo_hz":   (ti + 1) * 0.15,  # LFO orchestre
    }

def calc_kin_unix(unix_ts: int) -> dict:
    from datetime import datetime, timezone
    d = datetime.fromtimestamp(unix_ts, tz=timezone.utc)
    return calc_kin(d.year, d.month, d.day)

# ── Gestation (conception depuis naissance) ──────────────────────────────────
def compute_conception_unix(birth_unix: int, weight_kg: float = 3.5) -> int:
    """
    Déduire la date de conception à partir de la naissance et du poids.
    gestation_days = 280.0 + (weight_kg - 3.5) × 4.0
    """
    w = max(weight_kg, 0.5)
    gestation_s = (280.0 + (w - 3.5) * 4.0) * ORBITAL_DAY_S
    return int(birth_unix - gestation_s)

# ── Score d'harmonie collective H ────────────────────────────────────────────
def group_harmony_score(phases: list) -> float:
    """H = moyenne de k pour toutes les paires de la liste."""
    n = len(phases)
    if n < 2: return 0.5
    total = sum(compute_resonance_k(phases[i], phases[j])
                for i in range(n) for j in range(i+1, n))
    return total / (n * (n-1) / 2)

# ── CLI standalone ───────────────────────────────────────────────────────────
if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Phi2X — Moteur de résonance cosmique")
    ap.add_argument("--phase", nargs=4,
                    metavar=("DATE","TIME","LAT","LON"),
                    help="Calculer φ_i : YYYY-MM-DD HH:MM lat lon")
    ap.add_argument("--omega", nargs=3, metavar=("HEIGHT","WEIGHT","SEX"),
                    help="Calculer ω_bio : height_cm weight_kg sex(0/1)")
    ap.add_argument("--kin", nargs=3, metavar=("YEAR","MONTH","DAY"),
                    help="Calculer le Kin Maya")
    ap.add_argument("--k", nargs=2, metavar=("PHI_I","PHI_J"),
                    help="Calculer la résonance k entre deux phases")
    ap.add_argument("--harmony", nargs="+", metavar="PHI",
                    help="Score H d'un groupe de phases")
    args = ap.parse_args()

    if args.phase:
        date_s, time_s, lat_s, lon_s = args.phase
        from datetime import datetime, timezone
        dt = datetime.fromisoformat(f"{date_s}T{time_s}").replace(tzinfo=timezone.utc)
        phi = compute_personal_phase(int(dt.timestamp()), float(lat_s), float(lon_s))
        omega = compute_omega_bio(170.0, 70.0, 0)  # défaut si pas fourni
        kin   = calc_kin_unix(int(dt.timestamp()))
        print(f"φ_i      = {phi:.6f} rad  ({math.degrees(phi):.2f}°)")
        print(f"ω_bio    = {omega:.4f} Hz  (défaut h=170cm, w=70kg, sex=0)")
        print(f"Kin      = {kin}")
        k_self = compute_resonance_k(phi, phi)
        print(f"k(self)  = {k_self:.6f}")

    elif args.omega:
        h, w, s = float(args.omega[0]), float(args.omega[1]), int(args.omega[2])
        omega = compute_omega_bio(h, w, s)
        print(f"ω_bio = {omega:.4f} Hz")
        print(f"  (F_water={F_WATER}, water_ratio={'0.65' if s==0 else '0.60'}, water_kg={w*(.65 if s==0 else .60):.2f}kg)")

    elif args.kin:
        y, m, d = int(args.kin[0]), int(args.kin[1]), int(args.kin[2])
        k = calc_kin(y, m, d)
        print(f"Kin {k['kin']} — {k['color_fr']} {k['glyph_fr']} · Tonalité {k['tone_num']} {k['tone_fr']}")
        print(f"  LFO orchestre : {k['lfo_hz']:.2f} Hz")

    elif args.k:
        phi_i, phi_j = float(args.k[0]), float(args.k[1])
        k = compute_resonance_k(phi_i, phi_j)
        sing = is_optical_singularity(phi_i, phi_j)
        print(f"k = {k:.6f}  {'⚡ SINGULARITÉ OPTIQUE' if sing else ''}")

    elif args.harmony:
        phases = [float(p) for p in args.harmony]
        H = group_harmony_score(phases)
        print(f"H = {H:.4f}  ({len(phases)} phases, {len(phases)*(len(phases)-1)//2} paires)")

    else:
        ap.print_help()
