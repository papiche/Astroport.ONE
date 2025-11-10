#!/usr/bin/env python3
"""
TMDB Scraper - Extracts metadata from The Movie Database pages
Usage: python3 scraper.TMDB.py <tmdb_url>
Output: JSON metadata to stdout
"""
import sys
import json
import re
import urllib.request
import urllib.parse

try:
    from bs4 import BeautifulSoup
except ImportError:
    print("Error: beautifulsoup4 is required. Install it with: pip install beautifulsoup4", file=sys.stderr)
    sys.exit(1)

def scrape_tmdb_page(url):
    """Scrape TMDB page and extract metadata using BeautifulSoup"""
    try:
        # Add headers to avoid blocking
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read().decode('utf-8')
        
        # Parse HTML with BeautifulSoup
        soup = BeautifulSoup(html, 'html.parser')
        metadata = {}
        
        # Extract title - try multiple selectors based on actual TMDB structure
        title_text = None
        year_from_title = None
        
        # Method 1: h2 with link and span.release_date (actual TMDB structure)
        # <h2><a>Sexy Beast</a> <span class="tag release_date">(2024)</span></h2>
        title_elem = soup.find('h2', class_=re.compile('title|10', re.I))
        if title_elem:
            title_link = title_elem.find('a')
            if title_link:
                title_text = title_link.get_text(strip=True)
            else:
                title_text = title_elem.get_text(strip=True)
            
            # Extract year from span.release_date
            release_date_span = title_elem.find('span', class_=re.compile('release_date|tag', re.I))
            if release_date_span:
                year_match = re.search(r'\((\d{4})\)', release_date_span.get_text())
                if year_match:
                    year_from_title = year_match.group(1)
        
        # Method 2: data-testid="title"
        if not title_text:
            title_elem = soup.find('h2', {'data-testid': 'title'})
            if title_elem:
                title_text = title_elem.get_text(strip=True)
        
        # Method 3: og:title meta tag (usually more reliable and includes year)
        if not title_text:
            og_title = soup.find('meta', property='og:title')
            if og_title and og_title.get('content'):
                title_text = og_title['content']
        
        # Method 4: h2 with title class (fallback)
        if not title_text:
            title_elem = soup.find('h2', class_=re.compile('title', re.I))
            if title_elem:
                title_text = title_elem.get_text(strip=True)
        
        if title_text:
            # Use year from release_date span if found, otherwise try to extract from title text
            if year_from_title:
                metadata['year'] = year_from_title
                metadata['title'] = title_text.strip()
            else:
                # Extract year if present in title (e.g., "They Live (1988)" or "Sexy Beast (2024)")
                year_match = re.search(r'\((\d{4})\)', title_text)
                if year_match:
                    metadata['year'] = year_match.group(1)
                    metadata['title'] = re.sub(r'\s*\(\d{4}\)\s*', '', title_text).strip()
                else:
                    metadata['title'] = title_text.strip()
        
        # Try to extract year from various sources
        if 'year' not in metadata or not metadata['year']:
            # For TV shows: try "First Air Date" or "Premiere Date"
            for label in ['First Air Date', 'Premiere Date']:
                label_elem = soup.find(string=re.compile(label, re.I))
                if label_elem:
                    parent = label_elem.find_parent()
                    if parent:
                        date_elem = parent.find_next('span')
                        if date_elem:
                            date_str = date_elem.get_text(strip=True)
                            if date_str:
                                year_match = re.search(r'(\d{4})', date_str)
                                if year_match:
                                    year_candidate = year_match.group(1)
                                    if 1900 <= int(year_candidate) <= 2100:
                                        metadata['year'] = year_candidate
                                        break
            
            # For movies: try "Release Date"
            if 'year' not in metadata or not metadata['year']:
                release_label = soup.find(string=re.compile('Release Date', re.I))
                if release_label:
                    parent = release_label.find_parent()
                    if parent:
                        date_elem = parent.find_next('span')
                        if date_elem:
                            date_str = date_elem.get_text(strip=True)
                            if date_str:
                                year_match = re.search(r'(\d{4})', date_str)
                                if year_match:
                                    year_candidate = year_match.group(1)
                                    if 1900 <= int(year_candidate) <= 2100:
                                        metadata['year'] = year_candidate
        
        # Extract overview/plot - try multiple methods with BeautifulSoup
        overview_text = None
        
        # Method 1: div.overview > p (actual TMDB structure)
        # <div class="overview"><p>Années 1990...</p></div>
        overview_elem = soup.find('div', class_='overview')
        if overview_elem:
            overview_p = overview_elem.find('p')
            if overview_p:
                overview_text = overview_p.get_text(strip=True)
            else:
                overview_text = overview_elem.get_text(strip=True)
        
        # Method 2: Try data-testid="plot" (alternative structure)
        if not overview_text or len(overview_text) < 20:
            plot_elem = soup.find('div', {'data-testid': 'plot'})
            if plot_elem:
                overview_text = plot_elem.get_text(strip=True)
        
        # Method 3: Try other class-based selectors
        if not overview_text or len(overview_text) < 20:
            for class_name in ['description', 'plot', 'synopsis']:
                overview_elem = soup.find('div', class_=re.compile(class_name, re.I))
                if overview_elem:
                    text = overview_elem.get_text(strip=True)
                    if len(text) > len(overview_text or ''):
                        overview_text = text
        
        # Method 4: Try meta description tag
        if not overview_text or len(overview_text) < 20:
            meta_desc = soup.find('meta', {'name': 'description'})
            if meta_desc and meta_desc.get('content'):
                overview_text = meta_desc['content'].strip()
        
        # Method 5: Try og:description
        if not overview_text or len(overview_text) < 20:
            og_desc = soup.find('meta', property='og:description')
            if og_desc and og_desc.get('content'):
                overview_text = og_desc['content'].strip()
        
        # Method 6: Try to find in JSON-LD structured data
        if not overview_text or len(overview_text) < 20:
            json_ld_scripts = soup.find_all('script', type='application/ld+json')
            for script in json_ld_scripts:
                try:
                    json_ld = json.loads(script.string)
                    if isinstance(json_ld, dict):
                        if 'description' in json_ld:
                            overview_text = json_ld['description'].strip()
                    elif isinstance(json_ld, list) and len(json_ld) > 0:
                        if isinstance(json_ld[0], dict) and 'description' in json_ld[0]:
                            overview_text = json_ld[0]['description'].strip()
                    if overview_text:
                        break
                except:
                    continue
        
        # Method 7: Try to find paragraph after "Overview" or "Synopsis" heading
        if not overview_text or len(overview_text) < 20:
            for heading_text in ['Overview', 'Synopsis']:
                overview_heading = soup.find(string=re.compile(f'^{heading_text}$', re.I))
                if overview_heading:
                    parent = overview_heading.find_parent()
                    if parent:
                        next_p = parent.find_next('p')
                        if next_p:
                            overview_text = next_p.get_text(strip=True)
                            break
        
        # Method 8: Try to find in all paragraphs and select the longest one (likely to be description)
        if not overview_text or len(overview_text) < 50:
            paragraphs = soup.find_all('p')
            for p in paragraphs:
                text = p.get_text(strip=True)
                # Filter out very short paragraphs and navigation text
                if len(text) > 50 and len(text) > len(overview_text or ''):
                    # Skip if it looks like navigation or UI text
                    if not re.search(r'^(Home|About|Contact|Login|Sign)', text, re.I):
                        overview_text = text
        
        if overview_text and len(overview_text) > 10:
            # Clean up the text (remove extra whitespace)
            overview_text = re.sub(r'\s+', ' ', overview_text).strip()
            metadata['overview'] = overview_text
        
        # Extract tagline - target actual TMDB structure
        # <h3 class="tagline">Once upon a crime.</h3>
        tagline_elem = soup.find('h3', class_='tagline')
        if tagline_elem:
            metadata['tagline'] = tagline_elem.get_text(strip=True)
        else:
            # Fallback: try with regex
            tagline_elem = soup.find('h3', class_=re.compile('tagline', re.I))
            if tagline_elem:
                metadata['tagline'] = tagline_elem.get_text(strip=True)
        
        # Extract genres - target actual TMDB structure
        # <span class="genres"><a href="/genre/18-drame/tv">Drame</a>,&nbsp;<a href="/genre/80-crime/tv">Crime</a></span>
        genres = []
        genres_span = soup.find('span', class_='genres')
        if genres_span:
            genre_links = genres_span.find_all('a', href=re.compile(r'/genre/\d+-'))
            for link in genre_links:
                genre_name = link.get_text(strip=True)
                if genre_name:
                    genres.append(genre_name)
        
        # Fallback: find all genre links in the page
        if not genres:
            genre_links = soup.find_all('a', href=re.compile(r'/genre/\d+-'))
            for link in genre_links:
                genre_name = link.get_text(strip=True)
                if genre_name and genre_name not in genres:
                    genres.append(genre_name)
        
        if genres:
            metadata['genres'] = genres
        
        # Extract director (for movies)
        director_label = soup.find(string=re.compile('^Director$', re.I))
        if director_label:
            parent = director_label.find_parent()
            if parent:
                director_link = parent.find_next('a', href=re.compile(r'/person/\d+'))
                if director_link:
                    metadata['director'] = director_link.get_text(strip=True)
        
        # Extract creator (for TV shows)
        # Look for "Creator" or "Créateur" or "Créatrice" in the people section
        creator_labels = soup.find_all(string=re.compile('Creator|Créateur|Créatrice', re.I))
        for creator_label in creator_labels:
            parent = creator_label.find_parent()
            if parent:
                # Look for link to person in the same list item or nearby
                creator_link = parent.find('a', href=re.compile(r'/person/\d+'))
                if creator_link:
                    creator_name = creator_link.get_text(strip=True)
                    if creator_name:
                        metadata['creator'] = creator_name
                        break
        
        # Alternative: Look in people list with class "profile"
        if 'creator' not in metadata:
            people_list = soup.find('ol', class_='people')
            if people_list:
                profiles = people_list.find_all('li', class_='profile')
                for profile in profiles:
                    character_text = profile.find('p', class_='character')
                    if character_text and re.search('Creator|Créateur', character_text.get_text(), re.I):
                        name_link = profile.find('a', href=re.compile(r'/person/\d+'))
                        if name_link:
                            metadata['creator'] = name_link.get_text(strip=True)
                            break
        
        # Extract runtime
        runtime_elem = soup.find(string=re.compile(r'\d+\s*minutes?', re.I))
        if runtime_elem:
            runtime_match = re.search(r'(\d+)\s*minutes?', runtime_elem, re.IGNORECASE)
            if runtime_match:
                metadata['runtime'] = runtime_match.group(1) + " minutes"
        
        # Extract vote average
        vote_elem = soup.find(attrs={'data-testid': 'vote-average'})
        if vote_elem:
            metadata['vote_average'] = vote_elem.get_text(strip=True)
        
        # Extract budget and revenue from JSON-LD if available
        json_ld_scripts = soup.find_all('script', type='application/ld+json')
        for script in json_ld_scripts:
            try:
                json_ld = json.loads(script.string)
                if isinstance(json_ld, dict):
                    if 'aggregateRating' in json_ld:
                        if 'ratingValue' in json_ld['aggregateRating']:
                            metadata['vote_average'] = str(json_ld['aggregateRating']['ratingValue'])
                        if 'reviewCount' in json_ld['aggregateRating']:
                            metadata['vote_count'] = str(json_ld['aggregateRating']['reviewCount'])
                    # Extract production companies
                    if 'productionCompany' in json_ld:
                        companies = []
                        if isinstance(json_ld['productionCompany'], list):
                            for company in json_ld['productionCompany']:
                                if isinstance(company, dict) and 'name' in company:
                                    companies.append(company['name'])
                        elif isinstance(json_ld['productionCompany'], dict) and 'name' in json_ld['productionCompany']:
                            companies.append(json_ld['productionCompany']['name'])
                        if companies:
                            metadata['production_companies'] = companies
                    # Extract countries
                    if 'countryOfOrigin' in json_ld:
                        countries = []
                        if isinstance(json_ld['countryOfOrigin'], list):
                            for country in json_ld['countryOfOrigin']:
                                if isinstance(country, dict) and 'name' in country:
                                    countries.append(country['name'])
                                elif isinstance(country, str):
                                    countries.append(country)
                        elif isinstance(json_ld['countryOfOrigin'], dict) and 'name' in json_ld['countryOfOrigin']:
                            countries.append(json_ld['countryOfOrigin']['name'])
                        elif isinstance(json_ld['countryOfOrigin'], str):
                            countries.append(json_ld['countryOfOrigin'])
                        if countries:
                            metadata['countries'] = countries
                    # Extract languages
                    if 'inLanguage' in json_ld:
                        languages = []
                        if isinstance(json_ld['inLanguage'], list):
                            for lang in json_ld['inLanguage']:
                                if isinstance(lang, dict) and 'name' in lang:
                                    languages.append(lang['name'])
                                elif isinstance(lang, str):
                                    languages.append(lang)
                        elif isinstance(json_ld['inLanguage'], dict) and 'name' in json_ld['inLanguage']:
                            languages.append(json_ld['inLanguage']['name'])
                        elif isinstance(json_ld['inLanguage'], str):
                            languages.append(json_ld['inLanguage'])
                        if languages:
                            metadata['languages'] = languages
                    # Extract content rating/certification
                    if 'contentRating' in json_ld:
                        if isinstance(json_ld['contentRating'], str):
                            metadata['certification'] = json_ld['contentRating']
                        elif isinstance(json_ld['contentRating'], dict) and 'ratingValue' in json_ld['contentRating']:
                            metadata['certification'] = str(json_ld['contentRating']['ratingValue'])
            except:
                continue
        
        # Extract network (for TV shows)
        if metadata.get('media_type') == 'tv':
            # Look for network in various places
            network_labels = soup.find_all(string=re.compile('Network|Réseau', re.I))
            for network_label in network_labels:
                parent = network_label.find_parent()
                if parent:
                    network_link = parent.find_next('a', href=re.compile(r'/network/\d+'))
                    if network_link:
                        metadata['network'] = network_link.get_text(strip=True)
                        break
            
            # Alternative: look in facts section
            if 'network' not in metadata:
                facts_section = soup.find('section', class_=re.compile('facts', re.I))
                if facts_section:
                    network_elem = facts_section.find(string=re.compile('Network|Réseau', re.I))
                    if network_elem:
                        parent = network_elem.find_parent()
                        if parent:
                            network_link = parent.find_next('a')
                            if network_link:
                                metadata['network'] = network_link.get_text(strip=True)
            
            # Extract status (Returning Series, Ended, etc.)
            status_labels = soup.find_all(string=re.compile('Status|Statut', re.I))
            for status_label in status_labels:
                parent = status_label.find_parent()
                if parent:
                    status_elem = parent.find_next('span') or parent.find_next('p')
                    if status_elem:
                        status_text = status_elem.get_text(strip=True)
                        if status_text and status_text not in ['Status', 'Statut']:
                            metadata['status'] = status_text
                            break
            
            # Extract number of seasons and episodes
            # Look for "Seasons" or "Saisons"
            seasons_labels = soup.find_all(string=re.compile('Seasons?|Saisons?', re.I))
            for seasons_label in seasons_labels:
                parent = seasons_label.find_parent()
                if parent:
                    # Look for number after the label
                    text = parent.get_text()
                    seasons_match = re.search(r'(\d+)\s*(?:Seasons?|Saisons?)', text, re.I)
                    if seasons_match:
                        metadata['number_of_seasons'] = int(seasons_match.group(1))
                        break
            
            # Look for "Episodes" or "Épisodes"
            episodes_labels = soup.find_all(string=re.compile('Episodes?|Épisodes?', re.I))
            for episodes_label in episodes_labels:
                parent = episodes_label.find_parent()
                if parent:
                    text = parent.get_text()
                    episodes_match = re.search(r'(\d+)\s*(?:Episodes?|Épisodes?)', text, re.I)
                    if episodes_match:
                        metadata['number_of_episodes'] = int(episodes_match.group(1))
                        break
        
        # Extract certification/rating (for movies and TV)
        # Look for certification in various formats
        certification_labels = soup.find_all(string=re.compile('Certification|Rating|Classification', re.I))
        for cert_label in certification_labels:
            parent = cert_label.find_parent()
            if parent:
                cert_elem = parent.find_next('span') or parent.find_next('p')
                if cert_elem:
                    cert_text = cert_elem.get_text(strip=True)
                    if cert_text and cert_text not in ['Certification', 'Rating', 'Classification']:
                        metadata['certification'] = cert_text
                        break
        
        # Alternative: look for common rating patterns (PG, PG-13, R, 18+, etc.)
        if 'certification' not in metadata:
            rating_patterns = soup.find_all(string=re.compile(r'\b(PG|PG-13|R|NC-17|G|18\+|16\+|12\+)\b', re.I))
            if rating_patterns:
                metadata['certification'] = rating_patterns[0].strip()
        
        # Extract production companies (from HTML links)
        if 'production_companies' not in metadata:
            production_links = soup.find_all('a', href=re.compile(r'/company/\d+'))
            if production_links:
                companies = []
                for link in production_links:
                    company_name = link.get_text(strip=True)
                    if company_name and company_name not in companies:
                        companies.append(company_name)
                if companies:
                    metadata['production_companies'] = companies
        
        # Extract countries (from HTML)
        if 'countries' not in metadata:
            country_links = soup.find_all('a', href=re.compile(r'/country/[a-z]{2}'))
            if country_links:
                countries = []
                for link in country_links:
                    country_name = link.get_text(strip=True)
                    if country_name and country_name not in countries:
                        countries.append(country_name)
                if countries:
                    metadata['countries'] = countries
        
        # Extract TMDB ID from URL
        id_match = re.search(r'/movie/(\d+)|/tv/(\d+)', url)
        if id_match:
            metadata['tmdb_id'] = id_match.group(1) or id_match.group(2)
        
        # Determine media type
        if '/movie/' in url:
            metadata['media_type'] = 'movie'
        elif '/tv/' in url:
            metadata['media_type'] = 'tv'
            # Check if this is a season page
            season_match = re.search(r'/tv/\d+.*?/season/(\d+)', url)
            if season_match:
                metadata['season_number'] = int(season_match.group(1))
                metadata['is_season_page'] = True
                # Try to extract season year from page
                season_title = soup.find('h2')
                if season_title:
                    season_text = season_title.get_text()
                    year_match = re.search(r'\((\d{4})\)', season_text)
                    if year_match and 'year' not in metadata:
                        metadata['year'] = year_match.group(1)
        
        metadata['tmdb_url'] = url
        
        return metadata
        
    except Exception as e:
        print(f"Error scraping TMDB: {e}", file=sys.stderr)
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scraper.TMDB.py <tmdb_url>", file=sys.stderr)
        sys.exit(1)
    
    url = sys.argv[1]
    
    # Validate URL
    if not url.startswith('https://www.themoviedb.org/'):
        print("Error: Invalid TMDB URL", file=sys.stderr)
        sys.exit(1)
    
    metadata = scrape_tmdb_page(url)
    
    if metadata:
        print(json.dumps(metadata, indent=2, ensure_ascii=False))
    else:
        print("Error: Failed to scrape metadata", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()

