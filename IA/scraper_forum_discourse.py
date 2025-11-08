#!/usr/bin/env python3
import requests
import json
import argparse
import sys
from datetime import datetime, timedelta
from http.cookiejar import MozillaCookieJar

# Discourse API endpoints
LATEST_POSTS_URL = "/latest.json"
TOPICS_URL = "/topics.json"
POSTS_URL = "/posts.json"

# Headers to simulate a real browser
BASE_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json, text/html, */*",
    "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding": "gzip, deflate, br",
    "Referer": "https://forum.monnaie-libre.fr/",
    "Origin": "https://forum.monnaie-libre.fr",
}

def read_cookie_from_file(file_path):
    """
    Reads cookie from file - supports both Netscape cookie format and raw cookie string.
    Returns a requests.Session with cookies loaded.
    """
    session = requests.Session()
    
    try:
        with open(file_path, 'r') as f:
            content = f.read().strip()
        
        # Check if it's a Netscape format cookie file
        if '\t' in content and ('# Netscape HTTP Cookie File' in content or '# HTTP Cookie File' in content or content.count('\t') > 5):
            print(f"Detected Netscape cookie format, extracting forum.monnaie-libre.fr cookies...", file=sys.stderr)
            
            # Try to use MozillaCookieJar for proper cookie handling
            try:
                cookie_jar = MozillaCookieJar(file_path)
                cookie_jar.load(ignore_discard=True, ignore_expires=True)
                
                # Filter cookies for forum.monnaie-libre.fr domain
                forum_cookies = {}
                for cookie in cookie_jar:
                    if 'monnaie-libre.fr' in cookie.domain:
                        forum_cookies[cookie.name] = cookie.value
                
                if forum_cookies:
                    session.cookies.update(forum_cookies)
                    print(f"Extracted {len(forum_cookies)} cookies for forum.monnaie-libre.fr using cookie jar", file=sys.stderr)
                    return session
            except Exception as e:
                print(f"Warning: Could not use MozillaCookieJar, falling back to manual parsing: {e}", file=sys.stderr)
            
            # Fallback: manual parsing
            cookies = {}
            lines = content.split('\n')
            for line in lines:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                parts = line.split('\t')
                if len(parts) >= 7:
                    domain = parts[0].strip()
                    cookie_name = parts[5].strip()
                    cookie_value = parts[6].strip()
                    
                    if 'monnaie-libre.fr' in domain:
                        cookies[cookie_name] = cookie_value
            
            if cookies:
                session.cookies.update(cookies)
                print(f"Extracted {len(cookies)} cookies for forum.monnaie-libre.fr", file=sys.stderr)
                return session
        
        # Raw cookie string format
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
        
        print(f"Warning: Treating cookie file as raw string", file=sys.stderr)
        return session
        
    except FileNotFoundError:
        print(f"Error: Cookie file '{file_path}' not found.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading cookie file: {e}", file=sys.stderr)
        sys.exit(1)

def get_today_posts(session, base_url, days_back=1):
    """
    Fetch posts from Discourse forum published today (or last N days).
    Returns a list of posts with their details.
    """
    session.headers.update(BASE_HEADERS)
    
    # Calculate date threshold (today minus days_back)
    threshold_date = datetime.now() - timedelta(days=days_back)
    
    try:
        print(f"Fetching latest posts from {base_url}...", file=sys.stderr)
        
        # First, make a GET request to establish session
        try:
            session.get(base_url, timeout=10)
        except:
            pass
        
        # Get latest topics/posts
        latest_url = f"{base_url}{LATEST_POSTS_URL}"
        print(f"Requesting: {latest_url}", file=sys.stderr)
        
        response = session.get(latest_url, params={"order": "created"}, timeout=15)
        response.raise_for_status()
        
        data = response.json()
        
        # Extract topic list
        topics = data.get('topic_list', {}).get('topics', [])
        
        # Filter topics from today
        today_posts = []
        for topic in topics:
            # Parse created_at timestamp
            created_at_str = topic.get('created_at', '')
            created_at = None
            
            if created_at_str:
                try:
                    # Discourse can use ISO format, Unix timestamp, or other formats
                    if isinstance(created_at_str, (int, float)):
                        # Unix timestamp
                        created_at = datetime.fromtimestamp(created_at_str)
                    elif 'T' in created_at_str:
                        # ISO format with T separator
                        created_at_str_clean = created_at_str.replace('Z', '+00:00')
                        if '+' in created_at_str_clean or created_at_str_clean.count('-') >= 3:
                            created_at = datetime.fromisoformat(created_at_str_clean)
                        else:
                            created_at = datetime.strptime(created_at_str, "%Y-%m-%dT%H:%M:%S")
                    else:
                        # Try standard format
                        created_at = datetime.strptime(created_at_str, "%Y-%m-%d %H:%M:%S")
                except (ValueError, TypeError, OSError) as e:
                    print(f"Warning: Could not parse date '{created_at_str}': {e}", file=sys.stderr)
                    # Try to continue with other topics
                    continue
            
            # Check if post is from today or within days_back
            if created_at and created_at >= threshold_date:
                        # Get full post details
                        post_id = topic.get('id')
                        if post_id:
                            # Fetch post content
                            post_url = f"{base_url}/t/{topic.get('slug', '')}/{post_id}.json"
                            try:
                                post_response = session.get(post_url, timeout=10)
                                if post_response.status_code == 200:
                                    post_data = post_response.json()
                                    post_content = post_data.get('post_stream', {}).get('posts', [])
                                    if post_content:
                                        first_post = post_content[0]
                                        # Extract category information
                                        category = topic.get('category_id', None)
                                        category_name = None
                                        if category:
                                            # Try to get category name from topic list metadata
                                            categories = data.get('topic_list', {}).get('categories', [])
                                            for cat in categories:
                                                if cat.get('id') == category:
                                                    category_name = cat.get('name', '')
                                                    break
                                        
                                        today_posts.append({
                                            'id': post_id,
                                            'title': topic.get('title', ''),
                                            'author': topic.get('last_poster_username', ''),
                                            'created_at': created_at_str,
                                            'url': f"{base_url}/t/{topic.get('slug', '')}/{post_id}",
                                            'content': first_post.get('cooked', '')[:800],  # First 800 chars for better analysis
                                            'reply_count': topic.get('reply_count', 0),
                                            'like_count': topic.get('like_count', 0),
                                            'views': topic.get('views', 0),
                                            'category_id': category,
                                            'category_name': category_name or 'Non classé',
                                        })
                            except:
                                # If we can't get full post, use topic info
                                category = topic.get('category_id', None)
                                category_name = None
                                if category:
                                    categories = data.get('topic_list', {}).get('categories', [])
                                    for cat in categories:
                                        if cat.get('id') == category:
                                            category_name = cat.get('name', '')
                                            break
                                
                                today_posts.append({
                                    'id': post_id,
                                    'title': topic.get('title', ''),
                                    'author': topic.get('last_poster_username', ''),
                                    'created_at': created_at_str,
                                    'url': f"{base_url}/t/{topic.get('slug', '')}/{post_id}",
                                    'content': '',
                                    'reply_count': topic.get('reply_count', 0),
                                    'like_count': topic.get('like_count', 0),
                                    'views': topic.get('views', 0),
                                    'category_id': category,
                                    'category_name': category_name or 'Non classé',
                                })
                except (ValueError, TypeError) as e:
                    print(f"Warning: Could not parse date {created_at_str}: {e}", file=sys.stderr)
                    continue
        
        print(f"Found {len(today_posts)} posts from the last {days_back} day(s)", file=sys.stderr)
        return today_posts
        
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 401:
            print("Error HTTP 401: Unauthorized. Your cookie may be invalid or expired.", file=sys.stderr)
        elif e.response.status_code == 403:
            print("Error HTTP 403: Forbidden. The forum may require authentication.", file=sys.stderr)
        else:
            print(f"HTTP Error: {e}", file=sys.stderr)
            if hasattr(e.response, 'text') and e.response.text:
                print(f"Response details: {e.response.text[:500]}", file=sys.stderr)
        return []
    except requests.exceptions.RequestException as e:
        print(f"Network error: {e}", file=sys.stderr)
        return []
    except json.JSONDecodeError as e:
        print(f"Error: Could not decode JSON response. {e}", file=sys.stderr)
        return []

def main():
    """
    Main function to scrape Discourse forum and return JSON with today's posts.
    """
    parser = argparse.ArgumentParser(
        description="Scraper for Discourse forum posts. Returns posts from today or last N days.",
        epilog="Example: python scraper_forum_discourse.py ./cookie.txt https://forum.monnaie-libre.fr"
    )
    
    parser.add_argument("cookie_file", help="Path to cookie file (Netscape format or raw cookie string)")
    parser.add_argument("forum_url", help="Base URL of the Discourse forum (e.g., https://forum.monnaie-libre.fr)")
    parser.add_argument("--days", type=int, default=1, help="Number of days back to fetch posts (default: 1)")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")
    
    args = parser.parse_args()
    
    # Normalize forum URL (remove trailing slash)
    base_url = args.forum_url.rstrip('/')
    
    # Read cookie from file
    session = read_cookie_from_file(args.cookie_file)
    
    # Fetch today's posts
    posts = get_today_posts(session, base_url, days_back=args.days)
    
    # Output results
    if args.json:
        output = {
            'forum_url': base_url,
            'days_back': args.days,
            'total_posts': len(posts),
            'posts': posts,
            'fetched_at': datetime.now().isoformat()
        }
        print(json.dumps(output, indent=2, ensure_ascii=False))
    else:
        # Display formatted results
        if not posts:
            print("No posts found for the specified period.")
        else:
            print(f"\n--- Posts from the last {args.days} day(s) ---\n")
            for post in posts:
                print(f"Title: {post.get('title', 'N/A')}")
                print(f"Author: {post.get('author', 'N/A')}")
                print(f"Date: {post.get('created_at', 'N/A')}")
                print(f"URL: {post.get('url', 'N/A')}")
                print(f"Replies: {post.get('reply_count', 0)}, Likes: {post.get('like_count', 0)}, Views: {post.get('views', 0)}")
                if post.get('content'):
                    print(f"Content preview: {post.get('content', '')[:200]}...")
                print("-" * 50)

if __name__ == "__main__":
    main()

