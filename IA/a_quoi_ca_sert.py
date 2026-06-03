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


def _ollama_text(prompt, model=None, num_predict=1200):
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
        options={'temperature': 0.2, 'num_predict': num_predict, 'repeat_penalty': 1.2}
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

IDENTIFY_PROMPT = """Regarde cette image attentivement. Réponds UNIQUEMENT avec un objet JSON valide, sans texte avant ou après.
Format exact :
{"type":"TYPE","name":"nom précis en français","confidence":0.0,"details":"description visuelle en 1 phrase"}
Types possibles (choisis le plus précis) :
  plant    = plante, arbre, fleur, champignon, algue
  animal   = animal, insecte, oiseau, poisson, reptile
  food     = aliment, plat cuisiné, boisson, fruit, légume
  object   = objet manufacturé, meuble, véhicule, bâtiment, machine
  tool     = outil, appareil, instrument, équipement
  place    = lieu géographique, paysage, architecture
  person   = personne, portrait, groupe humain
  astro    = objet astronomique : nébuleuse, galaxie, planète, étoile, amas stellaire, comète
  art      = œuvre d'art, peinture, dessin, sculpture, photo artistique
  other    = tout ce qui ne rentre pas dans les catégories ci-dessus
Exemples : nébuleuse d'Orion → astro, tournesol → plant, marteau → tool, Paris → place."""


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
    # Botanique / médecine
    'pfaf.org', 'tela-botanica.org', 'botanical.com', 'henriettes-herb.com',
    'ethnobotanical.com', 'plants.usda.gov', 'gbif.org', 'inaturalist.org',
    'ncbi.nlm.nih.gov', 'pubmed.ncbi', 'sciencedirect.com',
    'passeportsante.net', 'doctissimo.fr', 'vidal.fr',
    # Astronomie / sciences
    'britannica.com', 'nasa.gov', 'esa.int', 'astro.unistra.fr',
    'apod.nasa.gov', 'simbad.u-strasbg.fr', 'cosmos.esa.int',
    'skyandtelescope.org', 'astronomie.fr', 'futura-sciences.com',
    # Encyclopédies généralistes
    'larousse.fr', 'universalis.fr', 'belin.fr',
]
_DEEP_SKIP = [
    # Réseaux sociaux / commerce
    'facebook.com', 'twitter.com', 'instagram.com', 'youtube.com',
    'amazon.', 'ebay.', 'shop', 'boutique', 'acheter', 'buy',
    # Wikimedia
    'wikidata.org', 'wikimedia.org', 'commons.wikimedia',
    # Fichiers d'autorité bibliographique — aucun contenu utile
    'viaf.org', 'catalogue.bnf.fr', 'data.bnf.fr', 'id.loc.gov',
    'd-nb.info', 'nli.org.il', 'lccn.loc.gov', 'isni.org',
    'worldcat.org', 'openlibrary.org', 'oclc.org',
    'denstoredanske', 'encyklopedia.pwn', 'snl.no',
    'archive.wikiwix.com', 'wikiwix.com',
    '/authorities/', '/authority/', '/catalog/', '/notice/',
    # Bases de données taxonomiques — ne contiennent que des métadonnées
    'ncbi.nlm.nih.gov/Taxonomy', 'ncbi.nlm.nih.gov/taxonomy',
    'gbif.org/species', 'gbif.org/fr/species',
    'inaturalist.org/taxa',
    'itis.gov/servlet', 'catalogueoflife.org/data/taxon',
    'iucnredlist.org/details', 'iucngisd.org/gisd',
    'biolib.cz/en/taxon', 'dyntaxa.se/taxon',
    'calflora.org/cgi-bin', 'florabase.dpaw',
    'ecocrop.fao.org', 'arkive.org',
    'biodiversity.org.au', 'floraofalabama.org/Plant',
    'florida.plantatlas', 'plantatlas.usf',
    'taxref.mnhn.fr', 'inpn.mnhn.fr',
    'tela-botanica.org/bdtfx', 'tela-botanica.org/page:eflore',
    'sophy.u-3mrs.fr',
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


def _generate_pdf(url, log=None):
    """Génère un PDF depuis une URL.
    Pour les pages Wikipedia, utilise l'API officielle /api/rest_v1/page/pdf
    (rendu natif Wikipedia, bien meilleur que Playwright).
    Pour les autres URLs, utilise Playwright."""
    import tempfile
    import re as _re

    pdf_path = tempfile.mktemp(suffix='.pdf')

    # Détecter Wikipedia et extraire lang + titre
    m = _re.match(r'https?://([a-z]+)\.wikipedia\.org/wiki/(.+)', url)
    if m:
        lang, title = m.group(1), m.group(2)
        api_url = f"https://{lang}.wikipedia.org/api/rest_v1/page/pdf/{title}"
        if log:
            log(f"PDF via API Wikipedia ({lang}) : {title}")
        try:
            r = requests.get(api_url, timeout=60,
                             headers={'User-Agent': 'a_quoi_ca_sert/1.0'})
            r.raise_for_status()
            with open(pdf_path, 'wb') as f:
                f.write(r.content)
            if log:
                size = os.path.getsize(pdf_path)
                log(f"PDF téléchargé ({size // 1024} Ko)")
            return pdf_path
        except Exception as e:
            if log:
                log(f"API Wikipedia PDF échouée ({e}), fallback Playwright…")
            # Fallback Playwright ci-dessous

    # Fallback Playwright pour les URLs non-Wikipedia
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={'width': 1200, 'height': 900})
        try:
            page.goto(url, wait_until='networkidle', timeout=40000)
            page.add_style_tag(content="""
                img, figure, .thumb, .thumbinner {
                    break-inside: avoid !important;
                    page-break-inside: avoid !important;
                    float: none !important;
                    display: block !important;
                    max-width: 100% !important;
                    height: auto !important;
                    margin: 8px auto !important;
                }
                table { break-inside: avoid !important; max-width: 100% !important; }
                h2, h3 { break-after: avoid !important; }
            """)
            page.pdf(path=pdf_path, format='A4', print_background=True,
                     margin={'top': '15mm', 'bottom': '15mm',
                             'left': '12mm', 'right': '12mm'})
            if log:
                size = os.path.getsize(pdf_path)
                log(f"PDF Playwright ({size // 1024} Ko)")
            return pdf_path
        except Exception as e:
            if log:
                log(f"PDF échoué : {e}")
            return None
        finally:
            browser.close()


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

    # Présentation : summary > description > fallback intro raw_sections
    presented = False
    for key in ('summary', 'description'):
        val = wiki.get(key, '').strip()
        if val:
            parts.append(f"\n[Présentation]\n{_trim(val, lim)}")
            presented = True
            break
    if not presented:
        # Fallback : utiliser les premiers blocs de l'intro raw_sections
        intro = next((s for s in wiki.get('raw_sections', []) if s['title'] == '__intro__'), None)
        if intro and intro.get('content'):
            text = '\n\n'.join(intro['content'][:3])
            parts.append(f"\n[Présentation]\n{_trim(text, lim)}")
            presented = True

    if wiki.get('uses'):
        parts.append(f"\n[Utilisations et propriétés]\n{_trim(wiki['uses'], lim)}")

    if wiki.get('how_to_use'):
        parts.append(f"\n[Préparation / culture / utilisation pratique]\n{_trim(wiki['how_to_use'], lim)}")

    if wiki.get('warnings'):
        parts.append(f"\n[Précautions / toxicité]\n{_trim(wiki['warnings'], 500 if cure_mode else 300)}")

    # Sections non catégorisées : toujours en cure, sinon les 2 premières seulement
    max_other = None if cure_mode else 2
    other_count = 0
    for s in wiki.get('raw_sections', []):
        if s['title'] == '__intro__':
            continue
        cat = _categorize_section(s['title'])
        if cat == 'other' and s.get('content'):
            if max_other is not None and other_count >= max_other:
                break
            text = '\n'.join(s['content'])
            parts.append(f"\n[{s['title']}]\n{_trim(text, 600)}")
            other_count += 1

    # Sources profondes (--deep)
    if deep_results:
        for src in deep_results:
            domain = src.get('domain', src.get('url', '')[:40])
            label = src.get('_link_label') or src.get('title', '')
            text = _trim(src.get('text', ''), 600)
            if text:
                parts.append(f"\n[Source externe : {label or domain}]\n{text}")

    return '\n'.join(parts)


# Champs par type de sujet
_FIELDS_BASE    = ('ce_que_cest', 'a_quoi_ca_sert', 'comment_sen_servir')
_FIELDS_CURE    = ('ce_que_cest', 'proprietes', 'preparations', 'usages_culinaires',
                   'precautions', 'comment_sen_servir')
_FIELDS_ASTRO   = ('ce_que_cest', 'caracteristiques', 'comment_observer', 'interet')
_FIELDS_PLACE   = ('ce_que_cest', 'histoire', 'a_voir', 'comment_visiter')
_FIELDS_ART     = ('ce_que_cest', 'contexte', 'analyse', 'interet')

SYNTHESIS_PROMPT_TMPL = """Contexte sur le sujet observé :
{context}

Réponds UNIQUEMENT avec ce JSON compact, sans markdown, sans code fence, sans commentaire :
{{"ce_que_cest":"définition précise avec caractéristiques clés, 2-3 phrases","a_quoi_ca_sert":"usages concrets et bénéfices avec détails techniques si disponibles, 3-4 phrases","comment_sen_servir":"conseils pratiques précis issus du contexte, 3-4 phrases"}}
Inclus des faits précis tirés du contexte. Pas de généralités vagues."""

CURE_PROMPT_TMPL = """Contexte détaillé sur le sujet observé :
{context}

Tu es un herboriste expert. Réponds UNIQUEMENT avec ce JSON compact (sans markdown, sans code fence) :
{{"ce_que_cest":"1-2 phrases","proprietes":"propriétés thérapeutiques, nutritionnelles et actifs principaux en 3-4 phrases","preparations":"méthodes de préparation précises : infusion (quelle partie, quelle dose, combien de minutes), décoction, macération, huile essentielle, usage externe/interne, etc. — 3-5 phrases","usages_culinaires":"comment l'utiliser en cuisine, quelles associations, comment le conserver — 2-3 phrases","precautions":"contre-indications, interactions médicamenteuses, dosage maximum, personnes à risque — 2-3 phrases","comment_sen_servir":"conseils pratiques de récolte, conservation et usage quotidien — 2-3 phrases"}}"""

ASTRO_PROMPT_TMPL = """Contexte sur l'objet astronomique observé :
{context}

Tu es un astronome expert. Utilise les données du contexte. Réponds UNIQUEMENT avec ce JSON compact (sans markdown, sans code fence) :
{{"ce_que_cest":"nature, type et localisation précise (constellation, distance en années-lumière) en 2 phrases","caracteristiques":"données physiques concrètes : taille, magnitude, composition, âge, particularités — 3-4 phrases avec chiffres","comment_observer":"quand, où dans le ciel, avec quel instrument (œil nu / jumelles / télescope), magnitude et conseils — 3 phrases","interet":"découverte historique, importance scientifique, phénomènes remarquables — 2-3 phrases"}}"""

PLACE_PROMPT_TMPL = """Contexte sur le lieu observé :
{context}

Réponds UNIQUEMENT avec ce JSON compact (sans markdown, sans code fence) :
{{"ce_que_cest":"description géographique et identité du lieu en 1-2 phrases","histoire":"origines et faits historiques marquants en 2-3 phrases","a_voir":"points d'intérêt, attraits, activités en 2-3 phrases","comment_visiter":"accès, meilleure période, conseils pratiques en 2 phrases"}}"""

ART_PROMPT_TMPL = """Contexte sur l'œuvre ou l'image artistique observée :
{context}

Réponds UNIQUEMENT avec ce JSON compact (sans markdown, sans code fence) :
{{"ce_que_cest":"description de l'œuvre, auteur supposé, technique en 1-2 phrases","contexte":"époque, mouvement artistique, commande ou contexte de création en 2 phrases","analyse":"composition, symbolique, éléments remarquables en 2-3 phrases","interet":"pourquoi cette œuvre est notable ou influente en 1-2 phrases"}}"""


def _synthesis_config(subject_type, cure_mode):
    """Retourne (prompt_template, fields) selon le type de sujet."""
    if cure_mode and subject_type in ('plant', 'food', 'animal'):
        return CURE_PROMPT_TMPL, _FIELDS_CURE
    if subject_type == 'astro':
        return ASTRO_PROMPT_TMPL, _FIELDS_ASTRO
    if subject_type == 'place':
        return PLACE_PROMPT_TMPL, _FIELDS_PLACE
    if subject_type == 'art':
        return ART_PROMPT_TMPL, _FIELDS_ART
    return SYNTHESIS_PROMPT_TMPL, _FIELDS_BASE


def _normalize_key(k):
    """Supprime les accents pour comparaison de clés JSON."""
    import unicodedata
    return ''.join(c for c in unicodedata.normalize('NFD', k)
                   if unicodedata.category(c) != 'Mn').lower()


def _extract_field(raw, field):
    import re
    # Chercher la clé exacte OU avec/sans accents
    field_norm = _normalize_key(field)
    pattern = rf'"([^"]*?)"\s*:\s*"((?:[^"\\]|\\.)*)"'
    for m in re.finditer(pattern, raw):
        key_raw, val = m.group(1), m.group(2)
        if _normalize_key(key_raw) == field_norm:
            val = val.replace('\\"', '"').replace('\\n', ' ').strip()
            last = re.search(r'^(.*[.!?])\s*$', val, re.DOTALL)
            return last.group(1).strip() if last else val
    return ''


def synthesize(subject, plant_info, enriched, cure_mode=False, deep_results=None):
    import re
    stype = subject.get('type', 'other')
    context = _build_context(subject, plant_info, enriched, cure_mode, deep_results)
    tmpl, fields = _synthesis_config(stype, cure_mode)
    prompt = tmpl.format(context=context)
    tokens = 2000 if cure_mode else 1400
    raw = _ollama_text(prompt, num_predict=tokens)

    raw = re.sub(r'```(?:json)?', '', raw).strip().rstrip('`').strip()

    m = re.search(r'\{.*\}', raw, re.DOTALL)
    if m:
        try:
            return json.loads(m.group())
        except Exception:
            pass

    result = {f: _extract_field(raw, f) for f in fields}
    if any(result.values()):
        return result

    return {'ce_que_cest': raw[:400]}


# ─── Publication NOSTR kind 1 ──────────────────────────────────────────────────

def _ipfs_url(cid):
    gateway = os.getenv('myLIBRA', 'https://ipfs.copylaradio.com').rstrip('/')
    if gateway.endswith('/ipfs'):
        gateway = gateway[:-5]
    return f"{gateway}/ipfs/{cid}"


def publish_kind1(text_content, image_source, email=None, pdf_ipfs_url=None):
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
        tags.append(["imeta", f"url {ipfs_url}", "m image/jpeg"])
        tags.append(["r", ipfs_url])
    if pdf_ipfs_url:
        tags.append(["r", pdf_ipfs_url])

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


# Mapping champ → (emoji, label)
_FIELD_LABELS = {
    'ce_que_cest':       ('📖', "Ce que c'est"),
    'a_quoi_ca_sert':    ('✅', 'À quoi ça sert'),
    'comment_sen_servir':('🛠️ ', 'Comment s\'en servir'),
    'proprietes':        ('🧪', 'Propriétés'),
    'preparations':      ('⚗️ ', 'Préparations'),
    'usages_culinaires': ('🍽️ ', 'Usages culinaires'),
    'precautions':       ('⚠️ ', 'Précautions'),
    'caracteristiques':  ('🔭', 'Caractéristiques'),
    'comment_observer':  ('🌌', 'Comment l\'observer'),
    'interet':           ('💡', 'Intérêt'),
    'histoire':          ('📜', 'Histoire'),
    'a_voir':            ('👁️ ', 'À voir'),
    'comment_visiter':   ('🗺️ ', 'Comment visiter'),
    'contexte':          ('🎨', 'Contexte'),
    'analyse':           ('🔍', 'Analyse'),
}

# Mots-clés → emoji pour les titres de sections Wikipedia
_SECTION_EMOJI_MAP = [
    (['alimentaire', 'cuisine', 'culinaire', 'recette', 'comestible'], '🍽️'),
    (['pharmaceutique', 'médecin', 'médical', 'médicinal', 'thérapeutique', 'phytothérapie'], '💊'),
    (['propriété', 'composition', 'chimique', 'actif', 'pharmacol'], '🧪'),
    (['préparation', 'décoction', 'infusion', 'macération', 'usage'], '⚗️'),
    (['précaution', 'toxicité', 'danger', 'contre-indication', 'allergie', 'poison'], '⚠️'),
    (['culture', 'plantation', 'jardinage', 'semis', 'entretien'], '🌱'),
    (['récolte', 'cueillette', 'conservation', 'séchage'], '✂️'),
    (['historique', 'histoire', 'étymologie', 'nomenclature', 'origine'], '📜'),
    (['distribution', 'répartition', 'habitat', 'écologie', 'environnement'], '🗺️'),
    (['espèce', 'taxonomie', 'classification', 'systématique'], '🔬'),
    (['végétatif', 'morphologie', 'description', 'caractéristique', 'appareil'], '🌿'),
    (['reproducteur', 'fleur', 'floraison', 'fruit', 'graine'], '🌸'),
    (['envahissante', 'invasive', 'conséquence', 'éradication'], '🚫'),
    (['observation', 'observer', 'télescope', 'astronomie'], '🔭'),
    (['connexe', 'voir aussi', 'annexe', 'galerie'], '🔗'),
    (['outil', 'machine', 'équipement', 'instrument'], '🔧'),
    (['technique', 'procédé', 'méthode', 'processus'], '⚙️'),
    (['application', 'utilisation', 'usage', 'emploi'], '✅'),
]


def _section_emoji(title):
    t = title.lower()
    for keywords, emoji in _SECTION_EMOJI_MAP:
        if any(k in t for k in keywords):
            return emoji
    return '▸'


def _md_to_nostr(text):
    """Convertit le texte markdown en texte plain NOSTR : **titre** → emoji titre."""
    import re
    def replace_bold(m):
        title = m.group(1).strip()
        return f"\n{_section_emoji(title)} {title}"
    text = re.sub(r'\*\*(.+?)\*\*', replace_bold, text)
    # Nettoyer les doubles sauts de ligne excessifs
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


TYPE_EMOJI = {
    'plant': '🌿', 'food': '🍽️', 'animal': '🐾', 'astro': '🌌',
    'place': '🗺️', 'art': '🎨', 'tool': '🔧', 'object': '📦',
    'person': '👤', 'other': '🔍',
}


def format_text(subject, plant_info, synthesis, enriched, cure_mode=False, deep_results=None, pdf_ipfs_url=None):
    lines = []
    stype = subject.get('type', 'other')

    # En-tête
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
        ico = TYPE_EMOJI.get(stype, '🔍')
        lines.append(f"{ico} {subject.get('name', '?')}")

    lines.append('')

    # Champs dans l'ordre défini par _synthesis_config
    _, fields = _synthesis_config(stype, cure_mode)
    first = True
    for field in fields:
        val = _safe_field(synthesis.get(field))
        if val:
            emoji, label = _FIELD_LABELS.get(field, ('•', field))
            prefix = '' if first else '\n'
            lines.append(f"{prefix}{emoji} {label}\n{val}")
            first = False

    # Détails Wikipedia — sections utiles non incluses dans la synthèse Ollama
    wiki = enriched.get('wikipedia', {})
    detail_parts = []
    # Utilisations / préparations / avertissements (contenu factuel direct)
    for key, label in (('uses', None), ('how_to_use', None), ('warnings', '⚠️ Précautions')):
        val = wiki.get(key, '').strip()
        if val and len(val) > 80:
            detail_parts.append((f"{label}\n" if label else '') + _trim(val, 600))
    # Sections spécialisées non catégorisées (pas intro, pas déjà dans synthesis)
    shown_cats = {'description', 'uses', 'how_to_use', 'warnings'}
    for s in wiki.get('raw_sections', []):
        if s['title'] == '__intro__' or not s.get('content'):
            continue
        cat = _categorize_section(s['title'])
        if cat not in shown_cats:
            text = '\n'.join(s['content'])
            if len(text) > 80:
                detail_parts.append(f"**{s['title']}**\n{_trim(text, 400)}")
    if detail_parts:
        lines.append('\n📚 En détail')
        lines.append('─' * 40)
        lines.append(_md_to_nostr('\n\n'.join(detail_parts)))

    # Sources
    sources = []
    if wiki.get('url'):
        sources.append(f"🔗 Wikipedia : {wiki['url']}")
    for src in (deep_results or []):
        url = src.get('url', '')
        title = src.get('title') or src.get('domain') or url[:60]
        if url and not src.get('error') and len(src.get('text', '')) > 200:
            sources.append(f"🌐 {title} : {url}")
    if pdf_ipfs_url:
        sources.append(f"📄 PDF Wikipedia : {pdf_ipfs_url}")
    if sources:
        lines.append('\n' + '\n'.join(sources))

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

  ./a_quoi_ca_sert.py /tmp/plante.jpg --deep
      Scraping des liens externes trouvés dans Wikipedia
      (pfaf.org, tela-botanica.org, pubmed, passeportsante.net…)

  ./a_quoi_ca_sert.py /tmp/plante.jpg --cure --deep
      Mode détaillé + scraping profond des sources externes

  ./a_quoi_ca_sert.py /tmp/plante.jpg --deep --max-deep 8
      Jusqu'à 8 sources profondes (défaut: 4)

  ./a_quoi_ca_sert.py /tmp/plante.jpg --cure --deep --publish --json
      Mode complet : identification + scraping profond + synthèse + publication NOSTR

  ./a_quoi_ca_sert.py /tmp/plante.jpg --deep --verbose
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
                        help="Suivre les liens externes trouvés dans Wikipedia pour enrichir davantage")
    parser.add_argument("--max-deep", type=int, default=4, metavar="N",
                        help="Nombre max de sources profondes à scraper (défaut: 4)")
    parser.add_argument("--pdf", action="store_true",
                        help="Convertir la page Wikipedia en PDF, l'ajouter sur IPFS et l'attacher à la publication")
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

    # 5b. Génération PDF Wikipedia --pdf
    pdf_ipfs_url = None
    if args.pdf:
        wiki_url = enriched.get('wikipedia', {}).get('url')
        if wiki_url:
            log("Génération PDF Wikipedia…")
            pdf_path = _generate_pdf(wiki_url, log=vlog)
            if pdf_path:
                try:
                    r = subprocess.run(
                        ['ipfs', 'add', '--quiet', '--pin=false', pdf_path],
                        capture_output=True, text=True, timeout=60
                    )
                    cid = r.stdout.strip().split()[-1] if r.returncode == 0 else None
                    if cid:
                        pdf_ipfs_url = _ipfs_url(cid)
                        log(f"→ PDF IPFS : {pdf_ipfs_url}")
                except Exception as e:
                    log(f"ipfs add PDF échoué : {e}")
        else:
            log("--pdf : pas de page Wikipedia trouvée")

    # 5c. Scraping profond --deep
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
    stype = subject.get('type', 'other')
    context = _build_context(subject, plant_info, enriched, cure_mode, deep_results)
    vblock("Contexte envoyé à Ollama", context, max_chars=1200)

    try:
        import re as _re
        tmpl, fields = _synthesis_config(stype, cure_mode)
        prompt = tmpl.format(context=context)
        tokens = 2000 if cure_mode else 1400
        raw_response = _ollama_text(prompt, num_predict=tokens)
        vblock("Réponse brute Ollama", raw_response)
        raw_cleaned = _re.sub(r'```(?:json)?', '', raw_response).strip().rstrip('`').strip()
        m = _re.search(r'\{.*\}', raw_cleaned, _re.DOTALL)
        if m:
            try:
                synthesis = json.loads(m.group())
            except Exception:
                synthesis = {f: _extract_field(raw_cleaned, f) for f in fields}
        else:
            synthesis = {f: _extract_field(raw_cleaned, f) for f in fields}
        if not any(synthesis.values()):
            synthesis = {'ce_que_cest': raw_cleaned[:400]}
    except Exception as e:
        synthesis = {'ce_que_cest': subject.get('details', str(e))}

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
        print(format_text(subject, plant_info, synthesis, enriched, cure_mode, deep_results, pdf_ipfs_url))

    # 8. Publication NOSTR
    if args.publish_email is not None:
        pub_email = None if args.publish_email == "__captainemail__" else args.publish_email
        text_for_pub = format_text(subject, plant_info, synthesis, enriched, cure_mode, deep_results, pdf_ipfs_url)
        pub = publish_kind1(text_for_pub, args.image_source, pub_email, pdf_ipfs_url)
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
