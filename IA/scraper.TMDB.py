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
from html.parser import HTMLParser

class TMDBMetadataParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.metadata = {}
        self.in_title = False
        self.in_overview = False
        self.in_genres = False
        self.current_tag = None
        self.genres = []
        self.overview = ""
        self.title = ""
        self.year = ""
        self.tagline = ""
        self.director = ""
        self.cast = []
        self.budget = ""
        self.revenue = ""
        self.runtime = ""
        self.vote_average = ""
        self.vote_count = ""
        
    def handle_starttag(self, tag, attrs):
        attrs_dict = dict(attrs)
        
        # Extract title
        if tag == 'h2' and attrs_dict.get('data-testid') == 'title':
            self.in_title = True
            
        # Extract overview
        if tag == 'div' and attrs_dict.get('data-testid') == 'plot':
            self.in_overview = True
            
        # Extract tagline
        if tag == 'h3' and attrs_dict.get('class') and 'tagline' in attrs_dict.get('class', ''):
            self.in_tagline = True
            
        # Extract genres
        if tag == 'span' and attrs_dict.get('class') and 'genres' in str(attrs_dict.get('class', '')):
            self.in_genres = True
            
    def handle_data(self, data):
        data = data.strip()
        if not data:
            return
            
        # Extract title
        if self.in_title and not self.title:
            self.title = data
            
        # Extract overview
        if self.in_overview and not self.overview:
            self.overview = data
            
        # Extract tagline
        if hasattr(self, 'in_tagline') and self.in_tagline and not self.tagline:
            self.tagline = data
            
    def handle_endtag(self, tag):
        if tag == 'h2':
            self.in_title = False
        if tag == 'div':
            self.in_overview = False
        if tag == 'h3':
            if hasattr(self, 'in_tagline'):
                self.in_tagline = False
        if tag == 'span':
            self.in_genres = False

def scrape_tmdb_page(url):
    """Scrape TMDB page and extract metadata"""
    try:
        # Add headers to avoid blocking
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response:
            html = response.read().decode('utf-8')
            
        # Extract metadata using regex (more reliable than HTMLParser for complex pages)
        metadata = {}
        
        # Extract title - try multiple patterns (prefer data-testid="title")
        title_match = re.search(r'<h2[^>]*data-testid="title"[^>]*>(.*?)</h2>', html, re.DOTALL)
        if title_match:
            title_text = re.sub(r'<[^>]+>', '', title_match.group(1)).strip()
        else:
            # Try meta tag og:title (usually more reliable)
            title_match = re.search(r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"', html)
            if title_match:
                title_text = title_match.group(1)
            else:
                # Try h2 with title class
                title_match = re.search(r'<h2[^>]*class="[^"]*title[^"]*"[^>]*>(.*?)</h2>', html, re.DOTALL)
                if title_match:
                    title_text = re.sub(r'<[^>]+>', '', title_match.group(1)).strip()
                else:
                    title_text = ""
        
        if title_text:
            # Extract year if present in title (e.g., "They Live (1988)")
            year_match = re.search(r'\((\d{4})\)', title_text)
            if year_match:
                metadata['year'] = year_match.group(1)
                metadata['title'] = re.sub(r'\s*\(\d{4}\)\s*', '', title_text).strip()
            else:
                metadata['title'] = title_text
                
        # Try to extract year from release date if not found in title
        # Look for release date in various formats
        if 'year' not in metadata or not metadata['year']:
            # Try to find release date section
            release_match = re.search(r'Release Date[^<]*<span[^>]*>([^<]+)</span>', html, re.IGNORECASE)
            if release_match:
                date_str = release_match.group(1).strip()
                year_match = re.search(r'(\d{4})', date_str)
                if year_match:
                    metadata['year'] = year_match.group(1)
            else:
                # Fallback: look for any YYYY-MM-DD pattern
                release_match = re.search(r'(\d{4})-\d{2}-\d{2}', html)
                if release_match:
                    metadata['year'] = release_match.group(1)
        
        # Extract overview/plot
        overview_match = re.search(r'<div[^>]*data-testid="plot"[^>]*>(.*?)</div>', html, re.DOTALL)
        if overview_match:
            overview_text = re.sub(r'<[^>]+>', '', overview_match.group(1)).strip()
            metadata['overview'] = overview_text
        
        # Extract tagline
        tagline_match = re.search(r'<h3[^>]*class="[^"]*tagline[^"]*"[^>]*>(.*?)</h3>', html, re.DOTALL)
        if tagline_match:
            metadata['tagline'] = re.sub(r'<[^>]+>', '', tagline_match.group(1)).strip()
        
        # Extract genres
        genres = []
        genre_matches = re.findall(r'<a[^>]*href="/genre/(\d+)-[^"]*"[^>]*>([^<]+)</a>', html)
        for genre_id, genre_name in genre_matches:
            genres.append(genre_name.strip())
        if genres:
            metadata['genres'] = genres
        
        # Extract director
        director_match = re.search(r'Director[^<]*<a[^>]*href="/person/\d+[^"]*"[^>]*>([^<]+)</a>', html, re.DOTALL)
        if director_match:
            metadata['director'] = director_match.group(1).strip()
        
        # Extract runtime
        runtime_match = re.search(r'(\d+)\s*minutes?', html, re.IGNORECASE)
        if runtime_match:
            metadata['runtime'] = runtime_match.group(1) + " minutes"
        
        # Extract vote average
        vote_match = re.search(r'data-testid="vote-average"[^>]*>([\d.]+)', html)
        if vote_match:
            metadata['vote_average'] = vote_match.group(1)
        
        # Extract budget and revenue from JSON-LD if available
        json_ld_match = re.search(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', html, re.DOTALL)
        if json_ld_match:
            try:
                json_ld = json.loads(json_ld_match.group(1))
                if isinstance(json_ld, dict):
                    if 'aggregateRating' in json_ld:
                        if 'ratingValue' in json_ld['aggregateRating']:
                            metadata['vote_average'] = str(json_ld['aggregateRating']['ratingValue'])
                        if 'reviewCount' in json_ld['aggregateRating']:
                            metadata['vote_count'] = str(json_ld['aggregateRating']['reviewCount'])
            except:
                pass
        
        # Extract TMDB ID from URL
        id_match = re.search(r'/movie/(\d+)|/tv/(\d+)', url)
        if id_match:
            metadata['tmdb_id'] = id_match.group(1) or id_match.group(2)
        
        # Determine media type
        if '/movie/' in url:
            metadata['media_type'] = 'movie'
        elif '/tv/' in url:
            metadata['media_type'] = 'tv'
        
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

