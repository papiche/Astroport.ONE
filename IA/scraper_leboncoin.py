#!/usr/bin/env python3
import requests
import json
import argparse
import sys
from datetime import datetime
from http.cookiejar import MozillaCookieJar

# URL de l'API de recherche de Leboncoin
API_URL = "https://api.leboncoin.fr/finder/search"

# Headers de base pour simuler un navigateur réel
BASE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding": "gzip, deflate, br",
    "Content-Type": "application/json",
    "Origin": "https://www.leboncoin.fr",
    "Referer": "https://www.leboncoin.fr/",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-site",
    "Sec-Ch-Ua": '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
    "Sec-Ch-Ua-Mobile": "?0",
    "Sec-Ch-Ua-Platform": '"Windows"',
}

def read_cookie_from_file(file_path):
    """
    Reads cookie from file - supports both Netscape cookie format and raw cookie string.
    Returns a requests.Session with cookies loaded, or a cookie dict for manual handling.
    """
    session = requests.Session()
    
    try:
        with open(file_path, 'r') as f:
            content = f.read().strip()
        
        # Check if it's a Netscape format cookie file (has tab separators)
        if '\t' in content and ('# Netscape HTTP Cookie File' in content or '# HTTP Cookie File' in content or content.count('\t') > 5):
            print(f"Detected Netscape cookie format, extracting leboncoin.fr cookies...", file=sys.stderr)
            
            # Try to use MozillaCookieJar for proper cookie handling
            try:
                cookie_jar = MozillaCookieJar(file_path)
                cookie_jar.load(ignore_discard=True, ignore_expires=True)
                
                # Filter cookies for leboncoin.fr domains
                leboncoin_cookies = {}
                for cookie in cookie_jar:
                    if 'leboncoin.fr' in cookie.domain:
                        leboncoin_cookies[cookie.name] = cookie.value
                
                if leboncoin_cookies:
                    session.cookies.update(leboncoin_cookies)
                    print(f"Extracted {len(leboncoin_cookies)} cookies for leboncoin.fr using cookie jar", file=sys.stderr)
                    return session
            except Exception as e:
                print(f"Warning: Could not use MozillaCookieJar, falling back to manual parsing: {e}", file=sys.stderr)
            
            # Fallback: manual parsing
            cookies = {}
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
                        cookies[cookie_name] = cookie_value
            
            if cookies:
                session.cookies.update(cookies)
                print(f"Extracted {len(cookies)} cookies for leboncoin.fr", file=sys.stderr)
                return session
            else:
                print(f"Warning: No leboncoin.fr cookies found in file", file=sys.stderr)
                # Fallback: try to use all cookies
                cookies = {}
                for line in content.split('\n'):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    parts = line.split('\t')
                    if len(parts) >= 7:
                        cookie_name = parts[5].strip()
                        cookie_value = parts[6].strip()
                        cookies[cookie_name] = cookie_value
                if cookies:
                    session.cookies.update(cookies)
                    return session
        
        # Raw cookie string format - parse it
        # Format: "name1=value1; name2=value2" or just "name1=value1"
        if '=' in content and (';' in content or content.count('=') == 1):
            cookies = {}
            for cookie_pair in content.split(';'):
                cookie_pair = cookie_pair.strip()
                if '=' in cookie_pair:
                    name, value = cookie_pair.split('=', 1)
                    cookies[name.strip()] = value.strip()
            if cookies:
                session.cookies.update(cookies)
                return session
        
        # If we get here, treat as raw cookie string and add to session
        # This is a fallback for edge cases
        print(f"Warning: Treating cookie file as raw string", file=sys.stderr)
        return session
        
    except FileNotFoundError:
        print(f"Error: Cookie file '{file_path}' not found.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading cookie file: {e}", file=sys.stderr)
        sys.exit(1)

def search_leboncoin(session, query, lat, lon, radius, donation_only=False, owner_type_private=True, limit=100):
    """Interroge l'API de Leboncoin et retourne les annonces."""
    
    # Construction du payload pour la requête POST
    filters = {
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
    }
    
    # Add keywords filter if query is provided
    if query:
        filters["keywords"] = {
            "text": query
        }
    
    # Add donation filter if requested
    if donation_only:
        filters["donation"] = 1
        print("Filtre donation activé pour rechercher uniquement les annonces de dons", file=sys.stderr)
    
    # Add owner type filter if requested
    if owner_type_private:
        filters["owner_type"] = "private"
        print("Filtre owner_type=private activé", file=sys.stderr)
    
    payload = {
        "filters": filters,
        "limit": limit,  # Nombre d'annonces par page
        "sort_by": "date",
        "sort_order": "desc" # Trier par date, du plus récent au plus ancien
    }
    
    # Use session with proper headers
    session.headers.update(BASE_HEADERS)

    try:
        print("Envoi de la requête de recherche à Leboncoin...", file=sys.stderr)
        
        # First, make a GET request to the main page to establish session
        # This helps avoid captcha by showing we're browsing normally
        try:
            session.get("https://www.leboncoin.fr/", timeout=10)
        except:
            pass  # Ignore errors on this pre-request
        
        # Now make the actual API request
        response = session.post(API_URL, json=payload, timeout=15, allow_redirects=True)
        
        # Lève une exception si la requête a échoué (ex: 401, 403, 500)
        response.raise_for_status() 
        
        data = response.json()
        total = data.get('total', 0)
        ads = data.get('ads', [])
        print(f"Succès ! {total} annonces trouvées au total, {len(ads)} annonces retournées.", file=sys.stderr)
        
        # Return full response data for JSON output
        return {
            'total': total,
            'ads': ads,
            'full_response': data  # Include all data from API response
        }

    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 401:
            print("Erreur HTTP 401 : Non autorisé. Votre cookie est probablement invalide ou expiré.", file=sys.stderr)
        elif e.response.status_code == 403:
            print("Erreur HTTP 403 : Accès interdit. Leboncoin a détecté un bot ou demande un captcha.", file=sys.stderr)
            print("Solutions possibles :", file=sys.stderr)
            print("  1. Vérifiez que vos cookies sont à jour et valides", file=sys.stderr)
            print("  2. Essayez de vous connecter manuellement sur leboncoin.fr avec votre navigateur", file=sys.stderr)
            print("  3. Exportez à nouveau vos cookies après connexion", file=sys.stderr)
            if hasattr(e.response, 'text') and e.response.text:
                print(f"Détails de la réponse : {e.response.text[:500]}", file=sys.stderr)
        else:
            print(f"Erreur HTTP : {e}", file=sys.stderr)
            if hasattr(e.response, 'text') and e.response.text:
                print(f"Détails de la réponse : {e.response.text[:500]}", file=sys.stderr)
        return None
    except requests.exceptions.RequestException as e:
        print(f"Une erreur réseau est survenue : {e}", file=sys.stderr)
        return None
    except json.JSONDecodeError as e:
        print(f"Erreur : Impossible de décoder la réponse JSON. Le site a peut-être changé sa structure. {e}", file=sys.stderr)
        return None

def filter_relevant_ads(ads, search_query, lat, lon, radius):
    """
    Filter ads to keep only those relevant to the search query.
    Since the API already filters donations when donation=1 is set,
    this is mainly a safety check to ensure relevance.
    """
    if not ads:
        return []
    
    # Normalize search query to lowercase for matching
    query_lower = search_query.lower() if search_query else ""
    
    # Keywords that indicate free items
    free_keywords = ['donne', 'donner', 'donné', 'donnée', 'gratuit', 'gratuite', 'gratuits', 'gratuites', 'offert', 'offerte']
    
    # Check if search is for free items
    is_free_search = any(keyword in query_lower for keyword in free_keywords)
    
    filtered_ads = []
    for ad in ads:
        titre = ad.get('subject', '').lower()
        
        # If searching for free items, verify the ad is actually a donation
        # (API should already filter, but this is a safety check)
        if is_free_search:
            # Double-check that the title contains donation keywords
            if not any(keyword in titre for keyword in free_keywords):
                # Skip if title doesn't contain donation keywords
                # (API might return some false positives)
                continue
        
        # For non-donation searches, verify query relevance
        if query_lower and not is_free_search:
            # Check if at least one significant word from query appears in title
            query_words = query_lower.split()
            if query_words and not any(word in titre for word in query_words if len(word) > 3):
                # Skip if no relevant words found
                continue
        
        filtered_ads.append(ad)
    
    return filtered_ads

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
    - JSON output with donations only: python scraper_leboncoin.py cookie.txt "" 48.8566 2.3522 100000 --donation-only --json
    """
    parser = argparse.ArgumentParser(
        description="Scraper for Leboncoin ads within a geographic area. Supports Netscape cookie format and raw cookie strings.",
        epilog="Example: python scraper_leboncoin.py ./mon_cookie.txt \"table a donner\" 48.8566 2.3522 10000"
    )
    
    parser.add_argument("cookie_file", help="Path to cookie file (Netscape format or raw cookie string). Can be domain-specific like .leboncoin.fr.cookie")
    parser.add_argument("search_query", nargs='?', default="", help="Search term (e.g., 'donne', 'gratuit', 'canapé'). Optional if --donation-only is used.")
    parser.add_argument("latitude", type=float, help="Latitude of search center.")
    parser.add_argument("longitude", type=float, help="Longitude of search center.")
    parser.add_argument("radius", type=int, help="Search radius in meters (e.g., 100000 for 100km).")
    parser.add_argument("--donation-only", action="store_true", help="Only search for donation ads (donation=1).")
    parser.add_argument("--owner-type", default="private", choices=["private", "pro", "all"], help="Filter by owner type (default: private).")
    parser.add_argument("--json", action="store_true", help="Output results as JSON instead of formatted text.")
    parser.add_argument("--limit", type=int, default=100, help="Maximum number of results to return (default: 100).")
    
    args = parser.parse_args()
    
    # 1. Read cookie from file (supports both Netscape and raw format)
    # Returns a requests.Session with cookies loaded
    session = read_cookie_from_file(args.cookie_file)
    
    # Determine if we should filter by donation
    donation_only = args.donation_only
    owner_type_private = (args.owner_type == "private")
    
    # 2. Launch search
    result = search_leboncoin(session, args.search_query or None, args.latitude, args.longitude, args.radius, 
                             donation_only=donation_only, owner_type_private=owner_type_private, limit=args.limit)
    
    # 3. Output results
    if result is not None:
        if args.json:
            # Output full JSON response
            output = {
                'total': result.get('total', 0),
                'ads': result.get('ads', []),
                'search_params': {
                    'query': args.search_query,
                    'latitude': args.latitude,
                    'longitude': args.longitude,
                    'radius_meters': args.radius,
                    'donation_only': donation_only,
                    'owner_type': args.owner_type
                }
            }
            # Include full API response if available
            if 'full_response' in result:
                output['api_response'] = result['full_response']
            
            print(json.dumps(output, indent=2, ensure_ascii=False))
        else:
            # Filter and display formatted results
            ads = result.get('ads', [])
            filtered_ads = filter_relevant_ads(ads, args.search_query, args.latitude, args.longitude, args.radius)
            if len(filtered_ads) < len(ads):
                print(f"Filtrage : {len(ads)} annonces trouvées, {len(filtered_ads)} annonces pertinentes conservées.", file=sys.stderr)
            
            display_results(filtered_ads)

if __name__ == "__main__":
    main()