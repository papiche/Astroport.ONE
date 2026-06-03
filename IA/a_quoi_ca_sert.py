#!/usr/bin/env python3
"""
a_quoi_ca_sert.py — Identifie une image et explique ce que c'est, à quoi ça sert,
et comment s'en servir. Pour les plantes, enrichit avec PlantNet + Wikipedia.

Usage:
    ./a_quoi_ca_sert.py <image>                    # texte
    ./a_quoi_ca_sert.py <image> --json             # JSON structuré
    ./a_quoi_ca_sert.py <image> --publish          # + publication kind 1 NOSTR
    ./a_quoi_ca_sert.py <image> --publish alice@example.com
"""

import sys
import os
_venv_python = os.path.expanduser("~/.astro/bin/python3")
if os.path.exists(_venv_python) and sys.executable != _venv_python:
    os.execv(_venv_python, [_venv_python] + sys.argv)

import json
import argparse
import subprocess
import socket
import requests
import time

HOME_DIR = os.path.expanduser("~")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

_CURE_SECTION_KEYS = [
    'utilisation', 'usage', 'propriété', 'vertu', 'médecine', 'pharmacol',
    'phytothérapie', 'cuisine', 'culinaire', 'recette', 'préparation',
    'culture', 'récolte', 'conservation', 'toxicité', 'danger', 'précaution',
    'composition', 'chimique', 'nutritionnel', 'alimentaire', 'thérapeutique',
]

def _categorize_section(title):
    t = title.lower()
    if any(k in t for k in ('toxicité', 'danger', 'précaution', 'poison', 'contre-indication')):
        return 'warnings'
    if any(k in t for k in ('préparation', 'recette', 'cuisine', 'culture', 'récolte', 'conservation', 'culinaire')):
        return 'how_to_use'
    if any(k in t for k in ('utilisation', 'usage', 'propriété', 'vertu', 'médecine', 'phytothérapie',
                             'pharmacol', 'thérapeutique', 'nutritionnel', 'alimentaire', 'composition')):
        return 'uses'
    if any(k in t for k in ('description', 'morphologie', 'caractéristique', 'botanique', 'taxonomie')):
        return 'description'
    return 'other'


# ─── Ollama ────────────────────────────────────────────────────────────────────

def _check_ollama_port():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(1)
        ok = s.connect_ex(('127.0.0.1', 11434)) == 0
        s.close()
        return ok
    except Exception:
        return False


def _ensure_ollama():
    if _check_ollama_port():
        return True
    script = os.path.join(SCRIPT_DIR, 'services', 'ollama.me.sh')
    if os.path.exists(script):
        subprocess.run([script], capture_output=True, timeout=15)
    return _check_ollama_port()


def _ollama_vision(image_bytes, prompt, model='llama3.2-vision:11b'):
    import ollama
    def _call():
        return ollama.chat(
            model=model,
            messages=[{'role': 'user', 'content': prompt, 'images': [image_bytes]}],
            options={'temperature': 0.1, 'num_predict': 400}
        )
    try:
        return _call()['message']['content']
    except Exception as e:
        if '104' in str(e) or 'reset' in str(e).lower() or 'refused' in str(e).lower():
            script = os.path.join(SCRIPT_DIR, 'services', 'ollama.me.sh')
            if os.path.exists(script):
                subprocess.run([script], capture_output=True, timeout=15)
            return _call()['message']['content']
        raise


def _ollama_text(prompt, model=None):
    import ollama
    if model is None:
        for candidate in ['mistral', 'llama3.2', 'llama3', 'phi3', 'qwen2']:
            try:
                ollama.show(candidate)
                model = candidate
                break
            except Exception:
                continue
    if model is None:
        model = 'llama3.2-vision:11b'
    resp = ollama.chat(
        model=model,
        messages=[{'role': 'user', 'content': prompt}],
        options={'temperature': 0.2, 'num_predict': 1200, 'repeat_penalty': 1.2}
    )
    return resp['message']['content']


# ─── Chargement image ──────────────────────────────────────────────────────────

def _load_image(source):
    if source.startswith('http://') or source.startswith('https://'):
        r = requests.get(source, timeout=20)
        r.raise_for_status()
        return r.content, source
    if not os.path.exists(source):
        raise FileNotFoundError(f"Fichier introuvable : {source}")
    with open(source, 'rb') as f:
        return f.read(), source


# ─── Identification initiale ───────────────────────────────────────────────────

IDENTIFY_PROMPT = """Regarde cette image. Réponds UNIQUEMENT avec un objet JSON valide, sans texte avant ou après.
Format exact :
{"type":"plant|animal|food|object|tool|place|person|other","name":"nom le plus probable","confidence":0.0,"details":"description en 1 phrase"}
Types : plant=plante/champignon, animal=animal/insecte, food=aliment préparé, object=objet manufacturé, tool=outil/appareil, place=lieu/paysage, person=personne, other=autre."""


def identify_subject(image_bytes):
    raw = _ollama_vision(image_bytes, IDENTIFY_PROMPT)
    # Extraire le JSON même si le modèle ajoute du texte autour
    import re
    m = re.search(r'\{[^{}]+\}', raw, re.DOTALL)
    if m:
        try:
            return json.loads(m.group())
        except Exception:
            pass
    # Fallback : parser manuellement les champs clés
    subject = {'type': 'other', 'name': '', 'confidence': 0.0, 'details': raw[:200]}
    for field, pattern in [('type', r'"type"\s*:\s*"([^"]+)"'),
                            ('name', r'"name"\s*:\s*"([^"]+)"'),
                            ('confidence', r'"confidence"\s*:\s*([\d.]+)'),
                            ('details', r'"details"\s*:\s*"([^"]+)"')]:
        m2 = re.search(pattern, raw)
        if m2:
            val = m2.group(1)
            subject[field] = float(val) if field == 'confidence' else val
    return subject


# ─── PlantNet ──────────────────────────────────────────────────────────────────

def _call_plantnet(image_data, api_key):
    from PIL import Image
    import io
    try:
        img = Image.open(io.BytesIO(image_data))
        if img.format not in ('JPEG', 'PNG'):
            buf = io.BytesIO()
            img.convert('RGB').save(buf, format='JPEG', quality=95)
            image_data = buf.getvalue()
    except Exception:
        pass
    url = f"https://my-api.plantnet.org/v2/identify/all?api-key={api_key}"
    r = requests.post(url,
                      files={'images': ('image.jpg', image_data, 'image/jpeg')},
                      params={'lang': 'fr', 'no-reject': 'false'},
                      timeout=30)
    if r.status_code != 200:
        return None
    data = r.json()
    if not data.get('results'):
        return None
    best = data['results'][0]
    species = best['species']
    sci_name = species.get('scientificNameWithoutAuthor', '')
    return {
        'scientific_name': sci_name,
        'common_names': species.get('commonNames', []),
        'confidence': best['score'],
        'wikipedia_url': f"https://fr.wikipedia.org/wiki/{sci_name.replace(' ', '_')}",
        'plantnet_url': f"https://identify.plantnet.org/fr/k-world-flora/species/{sci_name.lower().replace(' ', '-')}/view",
        'all_results': [
            {'name': r['species']['scientificNameWithoutAuthor'], 'score': r['score']}
            for r in data['results'][:5]
        ]
    }


def get_plantnet_key():
    # Essayer l'env, puis le .env de la station, puis cooperative_config
    key = os.getenv('PLANTNET_API_KEY')
    if key:
        return key
    env_file = os.path.join(HOME_DIR, '.zen', 'Astroport.ONE', '.env')
    if os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                if line.startswith('PLANTNET_API_KEY='):
                    return line.split('=', 1)[1].strip().strip('"\'')
    return None


# ─── Scrapers ──────────────────────────────────────────────────────────────────

# Domaines prioritaires pour --deep (bases botaniques, médicinales, phytothérapie)
_DEEP_PRIORITY = [
    'pfaf.org', 'tela-botanica.org', 'botanical.com', 'henriettes-herb.com',
    'ethnobotanical.com', 'phytotherapy.org', 'plants.usda.gov', 'itis.gov',
    'tropicos.org', 'gbif.org', 'inaturalist.org', 'florabase.com',
    'medplants.org', 'herbalremediesadvice.org', 'drugs.com', 'webmd.com',
    'ncbi.nlm.nih.gov', 'pubmed.ncbi', 'sciencedirect.com',
    'passeportsante.net', 'doctissimo.fr', 'vidal.fr', 'eurekasante.fr',
]
_DEEP_SKIP = [
    'facebook.com', 'twitter.com', 'instagram.com', 'youtube.com',
    'amazon.', 'ebay.', 'shop', 'boutique', 'acheter', 'buy',
    'wikidata.org', 'wikimedia.org', 'commons.wikimedia',
]


def _score_link(link):
    """Score 0-10 : pertinence d'un lien pour --deep."""
    url = link.get('url', '').lower()
    label = link.get('label', '').lower()
    ctx = link.get('context', '')
    if any(s in url for s in _DEEP_SKIP):
        return -1
    score = 0
    for domain in _DEEP_PRIORITY:
        if domain in url:
            score += 5
            break
    if ctx == 'external_links':
        score += 2
    # Mots-clés pertinents dans le label
    useful_kw = ['plante', 'plant', 'botani', 'médecin', 'herbal', 'phyto',
                 'flore', 'espèce', 'species', 'taxonom', 'flora', 'médicinal']
    if any(k in label for k in useful_kw):
        score += 1
    return score


def _run_scraper(scraper_path, target, extra_args=None):
    cmd = [sys.executable, scraper_path, target, '--json']
    if extra_args:
        cmd += extra_args
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=45)
        if r.returncode == 0 and r.stdout.strip():
            return json.loads(r.stdout)
    except Exception:
        pass
    return {}


def scrape_deep(enriched, log=None, max_sources=5):
    """Suit les liens externes trouvés dans Wikipedia/PlantNet et scrape le contenu."""
    generic_scraper = os.path.join(SCRIPT_DIR, 'scrapers', 'generic', 'scrape.py')
    if not os.path.exists(generic_scraper):
        return []

    # Collecter tous les liens depuis les sources déjà scrapées
    all_links = []
    for source_data in enriched.values():
        all_links.extend(source_data.get('external_links', []))

    if not all_links:
        return []

    # Trier par score de pertinence, dédupliquer
    seen_urls = set()
    scored = []
    for lnk in all_links:
        url = lnk.get('url', '')
        if url in seen_urls:
            continue
        seen_urls.add(url)
        s = _score_link(lnk)
        if s >= 0:
            scored.append((s, lnk))
    scored.sort(key=lambda x: -x[0])
    candidates = [lnk for _, lnk in scored[:max_sources]]

    if log:
        log(f"--deep : {len(candidates)} source(s) à scraper sur {len(all_links)} liens trouvés")

    results = []
    for lnk in candidates:
        url = lnk['url']
        if log:
            log(f"  → {url[:70]}")
        data = _run_scraper(generic_scraper, url, ['--max-chars', '2500'])
        if data and data.get('text') and not data.get('error'):
            data['_link_label'] = lnk.get('label', '')
            data['_link_context'] = lnk.get('context', '')
            results.append(data)

    return results


def scrape_sources(plant_info=None, subject_name=None):
    """Lance les scrapers selon le type de sujet. Retourne un dict de données enrichies."""
    enriched = {}

    wiki_scraper = os.path.join(SCRIPT_DIR, 'scrapers', 'wikipedia', 'scrape.py')

    # Wikipedia uniquement — les données PlantNet viennent déjà de l'API
    wiki_target = None
    if plant_info:
        wiki_target = plant_info.get('wikipedia_url') or plant_info.get('scientific_name')
    elif subject_name:
        wiki_target = subject_name

    if wiki_target and os.path.exists(wiki_scraper):
        enriched['wikipedia'] = _run_scraper(wiki_scraper, wiki_target)

    return enriched


# ─── Synthèse Ollama ───────────────────────────────────────────────────────────

def _trim(text, max_chars):
    """Tronque au dernier signe de ponctuation complet."""
    if not text or len(text) <= max_chars:
        return text
    cut = text[:max_chars]
    last = max(cut.rfind('. '), cut.rfind('.\n'), cut.rfind('! '), cut.rfind('? '))
    return (cut[:last + 1] if last > max_chars // 2 else cut).strip()


def _build_context(subject, plant_info, enriched, cure_mode=False, deep_results=None):
    lim = 900 if cure_mode else 500
    parts = []
    if plant_info:
        parts.append(f"Plante : {plant_info['scientific_name']} ({', '.join(plant_info['common_names'][:3])}), confiance {int(plant_info['confidence']*100)}%")
    elif subject.get('name'):
        parts.append(f"Sujet : {subject['name']} (type : {subject['type']})")

    wiki = enriched.get('wikipedia', {})

    for key in ('summary', 'description'):
        val = wiki.get(key, '').strip()
        if val:
            parts.append(f"\n[Présentation]\n{_trim(val, lim)}")
            break

    if wiki.get('uses'):
        parts.append(f"\n[Utilisations et propriétés]\n{_trim(wiki['uses'], lim)}")

    if wiki.get('how_to_use'):
        parts.append(f"\n[Préparation / culture / utilisation pratique]\n{_trim(wiki['how_to_use'], lim)}")

    if wiki.get('warnings'):
        parts.append(f"\n[Précautions / toxicité]\n{_trim(wiki['warnings'], 500 if cure_mode else 300)}")

    # En mode --cure : ajouter toutes les autres sections non catégorisées
    if cure_mode:
        for s in wiki.get('raw_sections', []):
            if s['title'] == '__intro__':
                continue
            cat = _categorize_section(s['title'])
            if cat == 'other' and s.get('content'):
                text = '\n'.join(s['content'])
                parts.append(f"\n[{s['title']}]\n{_trim(text, 600)}")

    # Sources profondes (--deep)
    if deep_results:
        for src in deep_results:
            domain = src.get('domain', src.get('url', '')[:40])
            label = src.get('_link_label') or src.get('title', '')
            text = _trim(src.get('text', ''), 600)
            if text:
                parts.append(f"\n[Source externe : {label or domain}]\n{text}")

    return '\n'.join(parts)


# Champs standard
_FIELDS_BASE = ('ce_que_cest', 'a_quoi_ca_sert', 'comment_sen_servir')

# Champs étendus --cure
_FIELDS_CURE = ('ce_que_cest', 'proprietes', 'preparations', 'usages_culinaires',
                'precautions', 'comment_sen_servir')

SYNTHESIS_PROMPT_TMPL = """Contexte sur le sujet observé :
{context}

Réponds UNIQUEMENT avec ce JSON compact, sans markdown, sans code fence, sans commentaire :
{{"ce_que_cest":"2 phrases max","a_quoi_ca_sert":"2-3 phrases max","comment_sen_servir":"2-3 phrases max"}}
Chaque valeur : texte simple, phrases complètes, aucune répétition entre les champs."""

CURE_PROMPT_TMPL = """Contexte détaillé sur le sujet observé :
{context}

Tu es un herboriste expert. Réponds UNIQUEMENT avec ce JSON compact (sans markdown, sans code fence) :
{{"ce_que_cest":"1-2 phrases","proprietes":"propriétés thérapeutiques, nutritionnelles et actifs principaux en 3-4 phrases","preparations":"méthodes de préparation précises : infusion (quelle partie, quelle dose, combien de minutes), décoction, macération, huile essentielle, usage externe/interne, etc. — 3-5 phrases","usages_culinaires":"comment l'utiliser en cuisine, quelles associations, comment le conserver — 2-3 phrases","precautions":"contre-indications, interactions médicamenteuses, dosage maximum, personnes à risque — 2-3 phrases","comment_sen_servir":"conseils pratiques de récolte, conservation et usage quotidien — 2-3 phrases"}}"""


def _extract_field(raw, field):
    import re
    m = re.search(rf'"{field}"\s*:\s*"((?:[^"\\]|\\.)*)"', raw)
    if m:
        val = m.group(1).replace('\\"', '"').replace('\\n', ' ').strip()
        last = re.search(r'^(.*[.!?])\s*$', val, re.DOTALL)
        return last.group(1).strip() if last else val
    return ''


def synthesize(subject, plant_info, enriched, cure_mode=False, deep_results=None):
    import re
    context = _build_context(subject, plant_info, enriched, cure_mode, deep_results)
    tmpl = CURE_PROMPT_TMPL if cure_mode else SYNTHESIS_PROMPT_TMPL
    prompt = tmpl.format(context=context)
    raw = _ollama_text(prompt)

    raw = re.sub(r'```(?:json)?', '', raw).strip().rstrip('`').strip()

    m = re.search(r'\{.*\}', raw, re.DOTALL)
    if m:
        try:
            return json.loads(m.group())
        except Exception:
            pass

    fields = _FIELDS_CURE if cure_mode else _FIELDS_BASE
    result = {f: _extract_field(raw, f) for f in fields}
    if any(result.values()):
        return result

    return {'ce_que_cest': raw[:400], 'a_quoi_ca_sert': '', 'comment_sen_servir': ''}


# ─── Publication NOSTR kind 1 ──────────────────────────────────────────────────

def _ipfs_url(cid):
    gateway = os.getenv('myLIBRA', 'https://ipfs.copylaradio.com').rstrip('/')
    if gateway.endswith('/ipfs'):
        gateway = gateway[:-5]
    return f"{gateway}/ipfs/{cid}"


def publish_kind1(text_content, image_source, email=None):
    if not email:
        email = os.getenv('CAPTAINEMAIL', '')
    if not email:
        env_file = os.path.join(HOME_DIR, '.zen', 'Astroport.ONE', '.env')
        if os.path.exists(env_file):
            with open(env_file) as f:
                for line in f:
                    if line.startswith('CAPTAINEMAIL='):
                        email = line.split('=', 1)[1].strip().strip('"\'')
                        break
    if not email:
        return None

    keyfile = os.path.join(HOME_DIR, '.zen', 'game', 'nostr', email, '.secret.nostr')
    if not os.path.exists(keyfile):
        return None

    ipfs_url = None
    if not image_source.startswith('http'):
        try:
            r = subprocess.run(['ipfs', 'add', '--quiet', '--pin=false', image_source],
                               capture_output=True, text=True, timeout=30)
            cid = r.stdout.strip().split()[-1] if r.returncode == 0 else None
            if cid:
                ipfs_url = _ipfs_url(cid)
        except Exception:
            pass
    else:
        ipfs_url = image_source

    content = text_content
    tags = [["t", "identification"], ["t", "aquoicasert"]]
    if ipfs_url:
        content += f"\n\n📸 {ipfs_url}"
        tags.append(["r", ipfs_url])

    script = os.path.join(HOME_DIR, '.zen', 'Astroport.ONE', 'tools', 'nostr_send_note.py')
    if not os.path.exists(script):
        script = os.path.join(SCRIPT_DIR, '..', 'tools', 'nostr_send_note.py')
    relay = os.getenv('NOSTR_RELAY_WS', 'ws://127.0.0.1:7777')

    try:
        r = subprocess.run(
            [sys.executable, script,
             '--keyfile', keyfile, '--content', content,
             '--kind', '1', '--tags', json.dumps(tags),
             '--relays', relay, '--json'],
            capture_output=True, text=True, timeout=60
        )
        if r.returncode == 0:
            pub = json.loads(r.stdout)
            pub['_content'] = content
            return pub
    except Exception:
        pass
    return None


# ─── Formatage texte ───────────────────────────────────────────────────────────

def _safe_field(value):
    if not value or not isinstance(value, str):
        return ''
    v = value.strip()
    if v.startswith('{') or v.startswith('[') or v.startswith('```'):
        return ''
    return v


def format_text(subject, plant_info, synthesis, enriched, cure_mode=False):
    lines = []

    if plant_info:
        sci = plant_info['scientific_name']
        common = ', '.join(plant_info['common_names'][:3])
        conf = int(plant_info['confidence'] * 100)
        emoji = '🟢' if conf >= 70 else '🟡' if conf >= 40 else '🟠'
        lines.append(f"🌿 {sci}{' (' + common + ')' if common else ''}")
        lines.append(f"{emoji} Confiance PlantNet : {conf}%")
        if plant_info.get('all_results') and len(plant_info['all_results']) > 1:
            lines.append("Autres candidats : " + ", ".join(
                f"{r['name']} ({int(r['score']*100)}%)"
                for r in plant_info['all_results'][1:3]
            ))
    else:
        lines.append(f"🔍 {subject.get('name', '?')} ({subject.get('type', '?')})")

    lines.append('')

    # Champs communs
    if _safe_field(synthesis.get('ce_que_cest')):
        lines.append(f"📖 Ce que c'est\n{synthesis['ce_que_cest']}")
    if _safe_field(synthesis.get('a_quoi_ca_sert')):
        lines.append(f"\n✅ À quoi ça sert\n{synthesis['a_quoi_ca_sert']}")

    # Champs --cure uniquement
    if cure_mode:
        if _safe_field(synthesis.get('proprietes')):
            lines.append(f"\n🧪 Propriétés\n{synthesis['proprietes']}")
        if _safe_field(synthesis.get('preparations')):
            lines.append(f"\n⚗️  Préparations\n{synthesis['preparations']}")
        if _safe_field(synthesis.get('usages_culinaires')):
            lines.append(f"\n🍽️  Usages culinaires\n{synthesis['usages_culinaires']}")
        if _safe_field(synthesis.get('precautions')):
            lines.append(f"\n⚠️  Précautions\n{synthesis['precautions']}")

    if _safe_field(synthesis.get('comment_sen_servir')):
        lines.append(f"\n🛠️  Comment s'en servir\n{synthesis['comment_sen_servir']}")

    wiki = enriched.get('wikipedia', {})
    if wiki.get('url'):
        lines.append(f"\n🔗 Wikipedia : {wiki['url']}")
    if plant_info and plant_info.get('plantnet_url'):
        lines.append(f"🌱 PlantNet : {plant_info['plantnet_url']}")

    return '\n'.join(lines)


# ─── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Identifie une image et explique ce que c'est, à quoi ça sert, comment s'en servir.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples :
  ./a_quoi_ca_sert.py /tmp/plante.jpg
      Identification + explication courte (texte)

  ./a_quoi_ca_sert.py /tmp/plante.jpg --cure
      Mode détaillé : propriétés, préparations, précautions, usages culinaires

  ./a_quoi_ca_sert.py /tmp/outil.jpg --json
      Sortie JSON structurée (ce_que_cest, a_quoi_ca_sert, comment_sen_servir)

  ./a_quoi_ca_sert.py /tmp/plante.jpg --cure --json
      Mode détaillé en JSON (ajoute : proprietes, preparations, usages_culinaires, precautions)

  ./a_quoi_ca_sert.py /tmp/plante.jpg --publish
      Identification + publication kind 1 NOSTR avec CAPTAINEMAIL

  ./a_quoi_ca_sert.py /tmp/plante.jpg --cure --publish alice@example.com
      Mode détaillé + publication NOSTR avec le MULTIPASS alice@example.com

  ./a_quoi_ca_sert.py https://example.com/image.jpg --no-scrape
      Identification rapide sans scraping Wikipedia/PlantNet

  ./a_quoi_ca_sert.py /tmp/plante.jpg --model llava:13b
      Utiliser un modèle vision différent pour l'identification

  ./a_quoi_ca_sert.py /tmp/plante.jpg --cure --deep
      Mode détaillé + scraping des liens externes trouvés dans Wikipedia/PlantNet
      (pfaf.org, tela-botanica.org, pubmed, passeportsante.net…)

  ./a_quoi_ca_sert.py /tmp/plante.jpg --cure --deep --max-deep 8
      Idem avec jusqu'à 8 sources profondes (défaut: 4)

  ./a_quoi_ca_sert.py /tmp/plante.jpg --cure --deep --publish --json
      Mode complet : identification + scraping profond + synthèse + publication NOSTR

  ./a_quoi_ca_sert.py /tmp/plante.jpg --cure --deep --verbose
      Affiche le détail de chaque étape : sections Wikipedia, liens trouvés,
      contexte envoyé à Ollama, réponse brute avant parsing

Scrapers utilisés (Playwright) :
  scrapers/wikipedia/scrape.py   <url_ou_titre> [--lang fr] [--json]
  scrapers/plantnet/scrape.py    <nom_scientifique_ou_url> [--json]
  scrapers/generic/scrape.py     <url> [--max-chars 3000] [--json]
"""
    )
    parser.add_argument("image_source", help="Fichier local ou URL HTTP(S)")
    parser.add_argument("--json", action="store_true", help="Sortie JSON structurée")
    parser.add_argument("--model", default="llama3.2-vision:11b",
                        help="Modèle Ollama vision (défaut: llama3.2-vision:11b)")
    parser.add_argument("--cure", action="store_true",
                        help="Mode détaillé : propriétés thérapeutiques, préparations, précautions")
    parser.add_argument("--publish", dest="publish_email", nargs="?", const="__captainemail__",
                        metavar="EMAIL",
                        help="Publier en kind 1 NOSTR (sans EMAIL = CAPTAINEMAIL)")
    parser.add_argument("--no-scrape", action="store_true",
                        help="Ne pas lancer les scrapers Wikipedia/PlantNet")
    parser.add_argument("--deep", action="store_true",
                        help="Suivre les liens externes trouvés pour enrichir davantage (combiné avec --cure)")
    parser.add_argument("--max-deep", type=int, default=4, metavar="N",
                        help="Nombre max de sources profondes à scraper (défaut: 4)")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Afficher le détail de chaque étape (sections, liens, contexte Ollama, réponse brute)")
    args = parser.parse_args()

    def log(msg, verbose_only=False):
        if args.json:
            return
        if verbose_only and not args.verbose:
            return
        prefix = "    " if verbose_only else "  "
        print(f"{prefix}{msg}", file=sys.stderr)

    def vlog(msg):
        log(msg, verbose_only=True)

    def vblock(title, content, max_chars=800):
        if not args.verbose or args.json:
            return
        sep = "─" * 60
        print(f"\n  ┌─ {title}\n  │ {sep}", file=sys.stderr)
        for line in str(content)[:max_chars].splitlines():
            print(f"  │ {line}", file=sys.stderr)
        if len(str(content)) > max_chars:
            print(f"  │ … ({len(str(content))} chars total)", file=sys.stderr)
        print(f"  └─ {sep}\n", file=sys.stderr)

    # 1. Charger l'image
    log("Chargement de l'image…")
    try:
        image_bytes, image_source = _load_image(args.image_source)
    except Exception as e:
        out = {'error': str(e)}
        print(json.dumps(out) if args.json else f"Erreur : {e}")
        sys.exit(1)
    vlog(f"{len(image_bytes)} octets, source : {image_source}")

    # 2. Connexion Ollama
    log("Connexion Ollama…")
    _ensure_ollama()

    # 3. Identification visuelle
    log("Identification du sujet…")
    try:
        subject = identify_subject(image_bytes)
    except Exception as e:
        subject = {'type': 'other', 'name': '', 'confidence': 0.0, 'details': str(e)}

    log(f"→ type={subject['type']}  name={subject.get('name', '?')}")
    vblock("Réponse identification Ollama", json.dumps(subject, ensure_ascii=False, indent=2))

    # 4. PlantNet si plante détectée
    plant_info = None
    if subject['type'] in ('plant',):
        api_key = get_plantnet_key()
        if api_key:
            log("Reconnaissance PlantNet…")
            try:
                plant_info = _call_plantnet(image_bytes, api_key)
                if plant_info:
                    log(f"→ {plant_info['scientific_name']} ({int(plant_info['confidence']*100)}%)")
                    vblock("Résultats PlantNet", json.dumps(plant_info.get('all_results', []), ensure_ascii=False, indent=2))
            except Exception as e:
                log(f"PlantNet échoué : {e}")

    # 5. Scraping des sources web
    enriched = {}
    if not args.no_scrape:
        subject_name = plant_info['scientific_name'] if plant_info else subject.get('name', '')
        if subject_name:
            log(f"Scraping sources pour « {subject_name} »…")
            enriched = scrape_sources(plant_info, subject_name)
            wiki = enriched.get('wikipedia', {})
            if wiki.get('title'):
                log(f"→ Wikipedia : {wiki['title']}")
                if wiki.get('raw_sections'):
                    vlog(f"Sections Wikipedia : " + ", ".join(
                        f"{s['title']}({len(s['content'])})" for s in wiki['raw_sections']
                        if s['title'] != '__intro__'
                    ))
                if wiki.get('external_links'):
                    vlog(f"{len(wiki['external_links'])} lien(s) externe(s) trouvé(s) :")
                    for lnk in wiki['external_links'][:10]:
                        vlog(f"  [{lnk.get('context','')}] {lnk.get('label','')[:50]} → {lnk.get('url','')[:70]}")

    # 5b. Scraping profond --deep
    deep_results = []
    cure_mode = args.cure
    if args.deep and not args.no_scrape and enriched:
        deep_results = scrape_deep(enriched, log=log, max_sources=args.max_deep)
        if deep_results:
            log(f"→ {len(deep_results)} source(s) profonde(s) récupérée(s)")
            for src in deep_results:
                vlog(f"  {src.get('domain','')} — {src.get('title','')[:60]} ({len(src.get('text',''))} chars)")

    # 6. Synthèse
    log(f"Synthèse avec Ollama{'  (mode --cure)' if cure_mode else ''}{'  + --deep' if deep_results else ''}…")
    context = _build_context(subject, plant_info, enriched, cure_mode, deep_results)
    vblock("Contexte envoyé à Ollama", context, max_chars=1200)

    try:
        import re as _re
        tmpl = CURE_PROMPT_TMPL if cure_mode else SYNTHESIS_PROMPT_TMPL
        prompt = tmpl.format(context=context)
        raw_response = _ollama_text(prompt)
        vblock("Réponse brute Ollama", raw_response)
        raw_cleaned = _re.sub(r'```(?:json)?', '', raw_response).strip().rstrip('`').strip()
        m = _re.search(r'\{.*\}', raw_cleaned, _re.DOTALL)
        if m:
            try:
                synthesis = json.loads(m.group())
            except Exception:
                fields = _FIELDS_CURE if cure_mode else _FIELDS_BASE
                synthesis = {f: _extract_field(raw_cleaned, f) for f in fields}
        else:
            fields = _FIELDS_CURE if cure_mode else _FIELDS_BASE
            synthesis = {f: _extract_field(raw_cleaned, f) for f in fields}
        if not any(synthesis.values()):
            synthesis = {'ce_que_cest': raw_cleaned[:400], 'a_quoi_ca_sert': '', 'comment_sen_servir': ''}
    except Exception as e:
        synthesis = {'ce_que_cest': subject.get('details', str(e)), 'a_quoi_ca_sert': '', 'comment_sen_servir': ''}

    # 7. Résultat
    if args.json:
        result = {
            'subject': subject,
            'plant': plant_info,
            'synthesis': synthesis,
            'cure_mode': cure_mode,
            'deep_mode': bool(deep_results),
            'sources': {
                k: {'url': v.get('url'), 'title': v.get('title')}
                for k, v in enriched.items() if v
            },
            'deep_sources': [
                {'url': s.get('url'), 'title': s.get('title'), 'domain': s.get('domain')}
                for s in deep_results
            ] if deep_results else []
        }
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(format_text(subject, plant_info, synthesis, enriched, cure_mode))

    # 8. Publication NOSTR
    if args.publish_email is not None:
        pub_email = None if args.publish_email == "__captainemail__" else args.publish_email
        text_for_pub = format_text(subject, plant_info, synthesis, enriched, cure_mode)
        pub = publish_kind1(text_for_pub, args.image_source, pub_email)
        if pub:
            if args.json:
                print(json.dumps(pub.get('event', pub), ensure_ascii=False))
            else:
                print(f"\n✅ Publié kind 1 → {pub.get('event_id', '?')}")
        else:
            if not args.json:
                print("\n⚠️  Publication NOSTR échouée.")


if __name__ == "__main__":
    main()
