#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
dj_playlist_downloader.py
Extrait la tracklist d'un mix de DJ sur YouTube (repères temporels dans la
description) et télécharge chaque morceau individuellement via yt-dlp.
"""

import os
import re
import sys
import json
import shutil
import argparse
import subprocess
from pathlib import Path

__version__ = "2.1.0"

# Ajouter le PATH local pour s'assurer que yt-dlp est trouvé (SteamOS/Arch/Astroport)
os.environ["PATH"] = f"{os.path.expanduser('~/.local/bin')}:{os.environ.get('PATH', '')}"

AUDIO_FORMATS = ("mp3", "m4a", "opus", "vorbis", "flac", "wav", "aac", "best")

# Lignes de description à ignorer même si elles contiennent un timestamp
# (réseaux sociaux, liens, mentions génériques...)
NOISE_KEYWORDS = (
    "http://", "https://", "subscribe", "follow me", "instagram.com",
    "facebook.com", "twitter.com", "soundcloud.com", "spotify.com",
    "patreon", "youtube.com/", "bit.ly", "linktr.ee",
)

# Mots trop communs pour être significatifs dans la comparaison requête/résultat
STOPWORDS = {
    "the", "a", "an", "of", "is", "in", "on", "at", "to", "and", "or",
    "feat", "ft", "featuring", "vs", "with", "for", "de", "la", "le",
}


def run_command(cmd, capture=True):
    try:
        result = subprocess.run(cmd, capture_output=capture, text=True, check=True)
        return result.stdout.strip() if capture else ""
    except subprocess.CalledProcessError as e:
        print(f"Erreur lors de l'exécution de la commande : {' '.join(cmd)}\n{e.stderr}", file=sys.stderr)
        return None


def detect_default_browser():
    """Même détection que process_youtube.sh : navigateur système par défaut, sinon 1er trouvé."""
    try:
        out = subprocess.run(["xdg-settings", "get", "default-web-browser"],
                              capture_output=True, text=True, timeout=3).stdout.strip().lower()
        for needle, browser in (("firefox", "firefox"), ("chrom", "chrome"),
                                 ("brave", "brave"), ("opera", "opera"), ("vivaldi", "vivaldi")):
            if needle in out:
                return browser
    except Exception:
        pass
    for browser, cmd in (("firefox", "firefox"), ("chrome", "google-chrome"),
                         ("chromium", "chromium"), ("chromium", "chromium-browser")):
        if shutil.which(cmd):
            return browser
    return None


def resolve_player_email(args):
    """Email du joueur/capitaine dont on va utiliser le cookie MULTIPASS, même résolution que
    my.sh : argument explicite > CAPTAINEMAIL (exporté par my.sh) > joueur courant."""
    if args.player_email:
        return args.player_email
    if os.environ.get("CAPTAINEMAIL"):
        return os.environ["CAPTAINEMAIL"]
    current_player_file = Path.home() / ".zen" / "game" / "players" / ".current" / ".player"
    if current_player_file.is_file():
        return current_player_file.read_text(encoding="utf-8").strip()
    return None


def find_player_cookie_file(player_email):
    """Cookie YouTube MULTIPASS du joueur, mêmes noms/ordre que process_youtube.sh."""
    if not player_email:
        return None
    base = Path.home() / ".zen" / "game" / "nostr" / player_email
    for name in (".youtube.com.cookie", ".cookie.txt", "cookies.txt"):
        candidate = base / name
        if candidate.is_file():
            return candidate
    return None


def resolve_cookie_args(args):
    """Détermine les options cookies à transmettre à yt-dlp, avec la même priorité que
    ajouter_media.sh/process_youtube.sh : --cookies / --cookies-from-browser explicites >
    cookie MULTIPASS du joueur/capitaine > navigateur par défaut > aucun cookie. Calculé une
    seule fois (voir main()) pour éviter de ré-analyser à chaque appel yt-dlp."""
    if args.cookies:
        return ["--cookies", args.cookies]
    if args.cookies_from_browser:
        return ["--cookies-from-browser", args.cookies_from_browser]

    player_email = resolve_player_email(args)
    cookie_file = find_player_cookie_file(player_email)
    if cookie_file:
        print(f"🍪 Cookie YouTube MULTIPASS utilisé ({player_email}) : {cookie_file}")
        return ["--cookies", str(cookie_file)]

    browser = detect_default_browser()
    if browser:
        print(f"🍪 Aucun cookie MULTIPASS trouvé, utilisation du navigateur par défaut : {browser}")
        return ["--cookies-from-browser", browser]

    print("ℹ️  Aucun cookie YouTube disponible (recherche/téléchargement anonymes).")
    return []


def cookie_args(args):
    """Retourne les options cookies déjà résolues par resolve_cookie_args() dans main()."""
    return getattr(args, "_resolved_cookie_args", None) or []


def get_mix_metadata(url, args):
    """Récupère le titre, la description et les chapitres du mix via yt-dlp."""
    print("🔍 Récupération des informations du mix...")
    cmd = ["yt-dlp", "--skip-download", "--no-playlist", *cookie_args(args), "--dump-json", url]
    out = run_command(cmd)
    if not out:
        return None, None, None
    try:
        data = json.loads(out)
        chapters = [c["title"] for c in (data.get("chapters") or []) if c.get("title")]
        return data.get("title", "DJ_Mix"), data.get("description", ""), chapters
    except json.JSONDecodeError:
        return None, None, None


def clean_track_line(line, ts=None):
    """Nettoie une ligne brute (description ou chapitre) pour n'en garder que 'Artiste - Titre'."""
    clean_line = line.replace(ts, "").strip() if ts else line
    # Retrait des caractères non-alphanumériques de début (ex: hyphens, espaces, points)
    clean_line = re.sub(r'^[^\w\s]+', '', clean_line).strip()
    # Retrait des numéros de piste (ex: "1) ", "02. ", "1)."), en exigeant au moins un signe de
    # ponctuation après le chiffre (sinon "1 year of..." perdrait son "1" à tort)
    clean_line = re.sub(r'^\d+[\)\.\-]+\s*', '', clean_line).strip()
    # Retrait des mentions de pseudos (ex: @SaltedMusic, ou "Titre@handle" collé sans espace)
    clean_line = re.sub(r'\s*@[a-zA-Z0-9_]+', '', clean_line).strip()
    # Retrait des mentions de labels/remix entre parenthèses ou crochets
    clean_line = re.sub(r'\s*\([^)]*\b(records|recording|music|label|rec|mix|remix|dub|edit|rework)\b[^)]*\)', '', clean_line, flags=re.IGNORECASE).strip()
    clean_line = re.sub(r'\s*\[[^\]]*\b(records|recording|music|label|rec)\b[^\]]*\]', '', clean_line, flags=re.IGNORECASE).strip()
    return clean_line


def extract_tracklist(description, chapters=None):
    """Extrait les titres d'artistes et morceaux, en priorité depuis les chapitres YouTube
    (plus fiables que le texte libre de la description), avec repli sur la description."""
    tracks = []

    if chapters:
        print(f"📑 {len(chapters)} chapitres YouTube détectés, utilisés comme tracklist.")
        for title in chapters:
            clean_line = clean_track_line(title)
            if clean_line and len(clean_line) > 3:
                tracks.append(clean_line)

    if not tracks:
        # Recherche des repères temporels (ex: 00:00, 14:35, 1:02:58, [12:34], (12:34))
        timestamp_pattern = re.compile(r'(?:\[|\()?(\d{1,2}:\d{2}(?::\d{2})?)(?:\]|\))?')
        lines = description.splitlines()
        for line in lines:
            line = line.strip()
            if not line or any(kw in line.lower() for kw in NOISE_KEYWORDS):
                continue
            match = timestamp_pattern.search(line)
            if match:
                clean_line = clean_track_line(line, match.group(0))
                if clean_line and len(clean_line) > 3:
                    tracks.append(clean_line)

        # Fallback si aucun repère temporel n'est détecté
        if not tracks:
            print("ℹ️ Aucun repère temporel détecté. Analyse par structure 'Artiste - Titre'...")
            for line in lines:
                line = line.strip()
                if not line or any(kw in line.lower() for kw in NOISE_KEYWORDS):
                    continue
                if " - " in line or " – " in line:
                    clean_line = clean_track_line(line)
                    if clean_line and len(clean_line) > 5:
                        tracks.append(clean_line)

    # Dédoublonnage en conservant l'ordre
    seen = set()
    deduped = []
    for t in tracks:
        key = t.lower()
        if key not in seen:
            seen.add(key)
            deduped.append(t)
    return deduped


def _keywords(text):
    """Mots significatifs (>2 caractères, hors stopwords) pour comparer requête et résultat."""
    words = re.findall(r"[a-zA-Z0-9']+", text.lower())
    return {w for w in words if len(w) > 2 and w not in STOPWORDS}


def _match_score(track_query, candidate_title):
    """Ratio des mots-clés de la requête retrouvés dans le titre de la vidéo candidate."""
    query_words = _keywords(track_query)
    if not query_words:
        return 0.0
    candidate_words = _keywords(candidate_title)
    return len(query_words & candidate_words) / len(query_words)


def find_best_match(track_query, args):
    """Cherche plusieurs résultats YouTube et renvoie le mieux noté (score, id, titre),
    ou None si la recherche n'a rien retourné."""
    cmd = [
        "yt-dlp", "--skip-download", "--flat-playlist", "--no-warnings", *cookie_args(args),
        "--dump-json", f"ytsearch{args.candidates}:{track_query}",
    ]
    out = run_command(cmd)
    if not out:
        return None

    candidates = []
    for line in out.splitlines():
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            continue
        vid, title = data.get("id"), data.get("title", "")
        if vid and title:
            candidates.append((_match_score(track_query, title), vid, title))

    if not candidates:
        return None
    return max(candidates, key=lambda c: c[0])


def sanitize_filename(name):
    """Rend un nom de morceau utilisable comme nom de fichier sur tout système."""
    name = re.sub(r'[<>:"/\\|?*]', '_', name)
    return re.sub(r'\s+', ' ', name).strip()


def split_artist_title(track_query):
    """Sépare 'Artiste - Titre' en (artiste, titre) pour les tags ID3."""
    for sep in (" - ", " – "):
        if sep in track_query:
            artist, title = track_query.split(sep, 1)
            return artist.strip(), title.strip()
    return "", track_query.strip()


def apply_track_tags(filepath, track_query, album=None):
    """Réécrit les tags titre/artiste/album via ffmpeg pour que le fichier garde le nom de
    morceau original de la tracklist (et non le titre brut de la vidéo YouTube trouvée),
    afin d'être immédiatement exploitable dans Mixxx."""
    if not shutil.which("ffmpeg"):
        print("⚠️  ffmpeg introuvable : tags ID3 non corrigés (nom de fichier conservé tel quel).")
        return
    artist, title = split_artist_title(track_query)
    tmp_path = filepath.with_name(filepath.stem + ".tagging" + filepath.suffix)
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(filepath), "-map", "0", "-c", "copy",
           "-metadata", f"title={title}"]
    if artist:
        cmd += ["-metadata", f"artist={artist}"]
    if album:
        cmd += ["-metadata", f"album={album}"]
    cmd.append(str(tmp_path))
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0 and tmp_path.exists():
        tmp_path.replace(filepath)
    else:
        tmp_path.unlink(missing_ok=True)
        print(f"⚠️  Échec de la correction des tags ID3 pour {filepath.name}")


AUDIO_EXTENSIONS = {"mp3", "m4a", "opus", "ogg", "flac", "wav", "aac", "webm"}


def download_track(video_url, track_query, output_dir, args, album=None):
    """Télécharge le morceau à l'URL donnée sous le nom de la tracklist (pas le titre YouTube
    brut), puis corrige ses tags ID3. Renvoie True si succès."""
    safe_name = sanitize_filename(track_query)
    cmd = [
        "yt-dlp",
        "-x",
        "--audio-format", args.format,
        "--audio-quality", str(args.quality),
        "--no-playlist",
        "--no-overwrites",
        "-o", os.path.join(output_dir, f"{safe_name}.%(ext)s"),
    ]
    if args.embed_thumbnail:
        cmd.append("--embed-thumbnail")
    if args.embed_metadata:
        cmd.append("--embed-metadata")
    cmd += cookie_args(args)
    if args.verbose:
        cmd.append("-v")
    elif args.quiet:
        cmd += ["--quiet", "--no-warnings"]
    cmd.append(video_url)

    if subprocess.run(cmd).returncode != 0:
        return False

    matches = [p for p in Path(output_dir).iterdir()
               if p.stem == safe_name and p.suffix.lstrip(".").lower() in AUDIO_EXTENSIONS]
    if not matches:
        print(f"⚠️  Fichier téléchargé introuvable pour retagger : {safe_name}")
        return True
    apply_track_tags(matches[0], track_query, album=album)
    return True


def build_parser():
    epilog = """\
Exemples :
  %(prog)s https://youtu.be/XXXX
      Extrait la tracklist et télécharge chaque morceau en MP3 (avec confirmation).

  %(prog)s https://youtu.be/XXXX --dry-run
      Affiche et enregistre la tracklist détectée sans rien télécharger.

  %(prog)s https://youtu.be/XXXX -y -o ~/Music/MonMix --format flac --quality 0
      Téléchargement automatique (sans confirmation) en FLAC qualité maximale.

  %(prog)s https://youtu.be/XXXX --limit 5 --retries 3
      N'essaie que les 5 premiers morceaux, avec jusqu'à 3 tentatives chacun.

  %(prog)s https://youtu.be/XXXX --min-match 0.7 --candidates 8
      Vérification plus stricte : examine 8 résultats par morceau et n'accepte que les
      correspondances à 70%% de mots-clés communs (évite de télécharger une vidéo sans rapport).

  %(prog)s https://youtu.be/XXXX --cookies-from-browser firefox
      Recherche et téléchargement avec ta session YouTube connectée (résultats de recherche
      identiques à ceux vus dans le navigateur — utile si une recherche anonyme se trompe).

Notes :
  - Chaque morceau est vérifié par comparaison de mots-clés avant téléchargement (voir --min-match)
  - La tracklist détectée est toujours sauvegardée dans <dossier>/tracklist.txt
  - Les échecs sont listés dans <dossier>/failed.txt, les morceaux sans correspondance fiable
    dans <dossier>/no_match.txt
"""
    parser = argparse.ArgumentParser(
        prog="dj_playlist_downloader.py",
        description=(
            "Extrait la tracklist d'un mix de DJ YouTube (repères temporels "
            "dans la description : 00:00, [12:34], (1:02:58)...) et télécharge "
            "chaque morceau individuellement via yt-dlp (recherche par nom sur YouTube)."
        ),
        epilog=epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("url", help="Lien YouTube du mix DJ à analyser")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")

    grp_out = parser.add_argument_group("Sortie")
    grp_out.add_argument(
        "-o", "--output", metavar="DOSSIER",
        help="Dossier de destination (défaut : ~/Music/DJ_Mix_Tracks/<nom_du_mix>)",
    )
    grp_out.add_argument(
        "--dry-run", action="store_true",
        help="Extraire et afficher/sauvegarder la tracklist sans rien télécharger",
    )
    grp_out.add_argument(
        "-n", "--limit", type=int, metavar="N", default=None,
        help="Ne traiter que les N premiers morceaux détectés (utile pour tester)",
    )

    grp_search = parser.add_argument_group("Recherche / vérification")
    grp_search.add_argument(
        "--candidates", type=int, default=5, metavar="N",
        help="Nombre de résultats YouTube examinés par morceau pour choisir le mieux assorti (défaut : 5)",
    )
    grp_search.add_argument(
        "--min-match", type=float, default=0.5, metavar="0.0-1.0",
        help="Score minimal de correspondance mots-clés requête/résultat pour accepter le "
             "téléchargement ; en dessous, le morceau est ignoré au lieu de télécharger "
             "n'importe quoi (défaut : 0.5). Mettre 0 pour désactiver la vérification.",
    )

    grp_dl = parser.add_argument_group("Téléchargement")
    grp_dl.add_argument(
        "-f", "--format", choices=AUDIO_FORMATS, default="mp3", metavar="FORMAT",
        help=f"Format audio de sortie, parmi {', '.join(AUDIO_FORMATS)} (défaut : mp3)",
    )
    grp_dl.add_argument(
        "--quality", type=int, choices=range(0, 10), default=0, metavar="0-9",
        help="Qualité audio VBR yt-dlp : 0 = meilleure, 9 = pire (défaut : 0)",
    )
    grp_dl.add_argument(
        "-r", "--retries", type=int, default=1, metavar="N",
        help="Nombre de tentatives par morceau en cas d'échec (défaut : 1, pas de retry)",
    )
    grp_dl.add_argument(
        "--embed-thumbnail", action="store_true",
        help="Intégrer la miniature YouTube comme pochette de l'audio",
    )
    grp_dl.add_argument(
        "--embed-metadata", action="store_true",
        help="Intégrer les métadonnées (titre, artiste, date...) dans le fichier audio",
    )
    grp_auth = parser.add_argument_group("Authentification")
    grp_cookies = grp_auth.add_mutually_exclusive_group()
    grp_cookies.add_argument(
        "--cookies-from-browser", metavar="NAVIGATEUR",
        help="Utilise les cookies du navigateur indiqué (firefox, chrome, chromium, edge...) "
             "pour la recherche ET le téléchargement — reproduit ta session connectée, utile "
             "quand une recherche anonyme renvoie des résultats différents de ceux vus dans "
             "le navigateur, ou pour les vidéos avec restriction d'âge/région",
    )
    grp_cookies.add_argument(
        "--cookies", metavar="FICHIER",
        help="Fichier de cookies (format Netscape) à transmettre à yt-dlp, alternative à "
             "--cookies-from-browser",
    )
    grp_auth.add_argument(
        "--player-email", metavar="EMAIL",
        help="Email MULTIPASS dont utiliser le cookie YouTube enregistré "
             "(~/.zen/game/nostr/EMAIL/.youtube.com.cookie). Sans --cookies ni "
             "--cookies-from-browser explicite, ce cookie est utilisé automatiquement s'il "
             "existe (défaut : CAPTAINEMAIL ou joueur courant, comme process_youtube.sh)",
    )

    grp_misc = parser.add_argument_group("Général")
    grp_misc.add_argument(
        "-y", "--yes", action="store_true",
        help="Ne pas demander de confirmation avant de lancer les téléchargements",
    )
    grp_misc.add_argument(
        "-v", "--verbose", action="store_true",
        help="Afficher la sortie complète de yt-dlp (debug)",
    )
    grp_misc.add_argument(
        "-q", "--quiet", action="store_true",
        help="Réduire la sortie de yt-dlp aux erreurs uniquement (ignoré si --verbose)",
    )
    return parser


def main():
    args = build_parser().parse_args()

    if not shutil.which("yt-dlp"):
        print("❌ Erreur : 'yt-dlp' n'est pas accessible. Assurez-vous qu'il est installé dans votre environnement.", file=sys.stderr)
        sys.exit(1)

    args._resolved_cookie_args = resolve_cookie_args(args)

    title, description, chapters = get_mix_metadata(args.url, args)
    if not description:
        print("❌ Impossible de récupérer la description du mix ou vidéo invalide.", file=sys.stderr)
        sys.exit(1)

    # Assainir le titre pour créer un sous-dossier propre
    clean_title = re.sub(r'[^a-zA-Z0-9_-]', '_', title).strip('_')
    clean_title = re.sub(r'_+', '_', clean_title)

    # Définition du dossier de sortie
    if args.output:
        output_dir = Path(args.output).expanduser()
    else:
        output_dir = Path.home() / "Music" / "DJ_Mix_Tracks" / clean_title

    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"📂 Les morceaux seront sauvegardés dans : {output_dir}")

    # Extraction des pistes
    tracks = extract_tracklist(description, chapters)
    if not tracks:
        print("❌ Aucun morceau n'a pu être extrait de la description.")
        sys.exit(1)

    print(f"✅ {len(tracks)} morceaux détectés dans la playlist du mix.")

    if args.limit is not None and args.limit < len(tracks):
        print(f"✂️  --limit {args.limit} : seuls les {args.limit} premiers morceaux seront traités.")
        tracks = tracks[:args.limit]

    for idx, t in enumerate(tracks, 1):
        print(f"  {idx:02d}. {t}")

    # Sauvegarde de la tracklist pour référence / relance manuelle
    tracklist_path = output_dir / "tracklist.txt"
    tracklist_path.write_text("\n".join(tracks) + "\n", encoding="utf-8")

    if args.dry_run:
        print(f"\n📝 Tracklist enregistrée dans {tracklist_path} (dry-run, rien n'a été téléchargé).")
        sys.exit(0)

    if not args.yes:
        try:
            confirm = input("\nVoulez-vous lancer le téléchargement de ces morceaux ? [O/n] : ")
        except (KeyboardInterrupt, EOFError):
            print("\nAnnulé.")
            sys.exit(0)
        if confirm.strip().lower() not in ("", "o", "oui", "y", "yes"):
            print("Téléchargement annulé.")
            sys.exit(0)

    failed = []
    no_match = []
    for idx, track in enumerate(tracks, 1):
        print(f"\n[{idx}/{len(tracks)}] 🔎 {track}")
        match = find_best_match(track, args)
        if not match:
            print("   ❌ Aucun résultat de recherche YouTube.")
            failed.append(track)
            continue

        score, video_id, found_title = match
        if score < args.min_match:
            print(f"   ⚠️  Meilleur résultat trop différent (\"{found_title}\", "
                  f"score {score:.0%} < seuil {args.min_match:.0%}) — morceau ignoré.")
            no_match.append(f"{track}  →  meilleur résultat : {found_title} ({score:.0%})")
            continue

        print(f"   ✅ Correspondance : {found_title} (score {score:.0%})")
        video_url = f"https://www.youtube.com/watch?v={video_id}"

        success = False
        for attempt in range(1, args.retries + 1):
            if attempt > 1:
                print(f"   ↻ Nouvelle tentative ({attempt}/{args.retries})...")
            if download_track(video_url, track, output_dir, args, album=title):
                success = True
                break
        if not success:
            failed.append(track)

    if no_match:
        no_match_path = output_dir / "no_match.txt"
        no_match_path.write_text("\n".join(no_match) + "\n", encoding="utf-8")
        print(f"\nℹ️  {len(no_match)} morceau(x) ignoré(s) faute de correspondance fiable. Détails dans {no_match_path}")

    if failed:
        failed_path = output_dir / "failed.txt"
        failed_path.write_text("\n".join(failed) + "\n", encoding="utf-8")
        print(f"⚠️  {len(failed)} échec(s) de téléchargement sur {len(tracks)}. Détails dans {failed_path}")

    downloaded = len(tracks) - len(failed) - len(no_match)
    if failed or no_match:
        print(f"\n🎉 Terminé : {downloaded}/{len(tracks)} morceaux téléchargés dans {output_dir}")
        sys.exit(1 if failed else 0)

    print(f"\n🎉 Terminé ! Les {len(tracks)} morceaux sont disponibles dans {output_dir}")


if __name__ == "__main__":
    main()
