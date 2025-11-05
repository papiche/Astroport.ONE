#!/usr/bin/env python3
import requests
import json
import argparse
import sys
from datetime import datetime

# URL de l'API de recherche de Leboncoin
API_URL = "https://api.leboncoin.fr/finder/search"

# Headers de base pour simuler un navigateur
# Le cookie sera ajouté dynamiquement
BASE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36",
    "Content-Type": "application/json",
}

def read_cookie_from_file(file_path):
    """
    Reads cookie from file - supports both Netscape cookie format and raw cookie string.
    
    If file_path is a Netscape format cookie file (with tabs), extracts cookies for leboncoin.fr.
    Otherwise, reads the raw cookie string.
    """
    try:
        with open(file_path, 'r') as f:
            content = f.read().strip()
        
        # Check if it's a Netscape format cookie file (has tab separators)
        if '\t' in content and ('# Netscape HTTP Cookie File' in content or '# HTTP Cookie File' in content or content.count('\t') > 5):
            print(f"Detected Netscape cookie format, extracting leboncoin.fr cookies...", file=sys.stderr)
            
            # Extract cookies for leboncoin.fr domain
            cookies = []
            lines = content.split('\n')
            for line in lines:
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue
                # Parse cookie line (domain, flag, path, secure, expiration, name, value)
                parts = line.split('\t')
                if len(parts) >= 7:
                    domain = parts[0].strip()
                    cookie_name = parts[5].strip()
                    cookie_value = parts[6].strip()
                    
                    # Only include leboncoin.fr cookies
                    if 'leboncoin.fr' in domain:
                        cookies.append(f"{cookie_name}={cookie_value}")
            
            if cookies:
                cookie_string = '; '.join(cookies)
                print(f"Extracted {len(cookies)} cookies for leboncoin.fr", file=sys.stderr)
                return cookie_string
            else:
                print(f"Warning: No leboncoin.fr cookies found in file", file=sys.stderr)
                # Fallback: try to use all cookies
                cookies = []
                for line in content.split('\n'):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    parts = line.split('\t')
                    if len(parts) >= 7:
                        cookie_name = parts[5].strip()
                        cookie_value = parts[6].strip()
                        cookies.append(f"{cookie_name}={cookie_value}")
                if cookies:
                    return '; '.join(cookies)
        
        # Raw cookie string format
        return content
        
    except FileNotFoundError:
        print(f"Error: Cookie file '{file_path}' not found.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading cookie file: {e}", file=sys.stderr)
        sys.exit(1)

def search_leboncoin(cookie, query, lat, lon, radius):
    """Interroge l'API de Leboncoin et retourne les annonces."""
    
    # Construction du payload pour la requête POST
    # C'est ici que l'on définit les critères de recherche
    payload = {
        "filters": {
            "keywords": {
                "text": query
            },
            "location": {
                "locations": [
                    {
                        "locationType": "area",
                        "lat": lat,
                        "lon": lon,
                        "radius": radius # Le rayon est en mètres
                    }
                ]
            }
        },
        "limit": 35,  # Nombre d'annonces par page (maximum habituel)
        "sort_by": "date",
        "sort_order": "desc" # Trier par date, du plus récent au plus ancien
    }
    
    # Ajout du cookie aux headers
    headers = BASE_HEADERS.copy()
    headers["Cookie"] = cookie

    try:
        print("Envoi de la requête de recherche à Leboncoin...", file=sys.stderr)
        response = requests.post(API_URL, headers=headers, json=payload, timeout=10)
        
        # Lève une exception si la requête a échoué (ex: 401, 403, 500)
        response.raise_for_status() 
        
        data = response.json()
        print(f"Succès ! {data.get('total', 0)} annonces trouvées au total.", file=sys.stderr)
        
        return data.get('ads', [])

    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 401:
            print("Erreur HTTP 401 : Non autorisé. Votre cookie est probablement invalide ou expiré.", file=sys.stderr)
        else:
            print(f"Erreur HTTP : {e}", file=sys.stderr)
            print(f"Détails de la réponse : {e.response.text}", file=sys.stderr)
        return None
    except requests.exceptions.RequestException as e:
        print(f"Une erreur réseau est survenue : {e}", file=sys.stderr)
        return None
    except json.JSONDecodeError:
        print("Erreur : Impossible de décoder la réponse JSON. Le site a peut-être changé sa structure.", file=sys.stderr)
        return None

def display_results(ads):
    """Affiche les résultats de manière lisible."""
    if not ads:
        print("Aucune annonce ne correspond à vos critères.")
        return
        
    print("\n--- Résultats de la recherche ---\n")
    for ad in ads:
        titre = ad.get('subject', 'N/A')
        url = ad.get('url', 'N/A')
        
        # Gestion de la localisation
        location = ad.get('location', {})
        ville = location.get('city_label', 'N/A')
        code_postal = location.get('zipcode', '')
        lieu = f"{ville} ({code_postal})" if code_postal else ville
        
        # Gestion de la date
        date_str = ad.get('first_publication_date', 'N/A')
        try:
            # Conversion de la date au format français
            date_obj = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")
            date_fr = date_obj.strftime("%d/%m/%Y à %Hh%M")
        except (ValueError, TypeError):
            date_fr = date_str

        print(f"Titre: {titre}")
        print(f"Lieu: {lieu}")
        print(f"Date: {date_fr}")
        print(f"URL: {url}")
        print("-" * 30)

def main():
    """
    Main function to manage arguments and launch the script.
    
    Example usage:
    - With raw cookie file: python scraper_leboncoin.py ./mon_cookie.txt "table a donner" 48.8566 2.3522 10000
    - With Netscape format: python scraper_leboncoin.py ~/.zen/game/nostr/user@email.com/.leboncoin.fr.cookie "table a donner" 48.8566 2.3522 10000
    - With MULTIPASS EMAIL: python scraper_leboncoin.py ~/.zen/game/nostr/user@email.com/.leboncoin.fr.cookie "table a donner" 48.8566 2.3522 10000
    """
    parser = argparse.ArgumentParser(
        description="Scraper for Leboncoin ads within a geographic area. Supports Netscape cookie format and raw cookie strings.",
        epilog="Example: python scraper_leboncoin.py ./mon_cookie.txt \"table a donner\" 48.8566 2.3522 10000"
    )
    
    parser.add_argument("cookie_file", help="Path to cookie file (Netscape format or raw cookie string). Can be domain-specific like .leboncoin.fr.cookie")
    parser.add_argument("search_query", help="Search term (e.g., 'donne', 'gratuit', 'canapé').")
    parser.add_argument("latitude", type=float, help="Latitude of search center.")
    parser.add_argument("longitude", type=float, help="Longitude of search center.")
    parser.add_argument("radius", type=int, help="Search radius in meters (e.g., 5000 for 5km).")
    
    args = parser.parse_args()
    
    # 1. Read cookie from file (supports both Netscape and raw format)
    cookie_string = read_cookie_from_file(args.cookie_file)
    
    # 2. Launch search
    ads = search_leboncoin(cookie_string, args.search_query, args.latitude, args.longitude, args.radius)
    
    # 3. Display results
    if ads is not None:
        display_results(ads)

if __name__ == "__main__":
    main()