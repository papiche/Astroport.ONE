#!/usr/bin/env python3
"""
BRO link understanding: extract URLs from message, fetch and extract main content.
Output: combined text for Ollama context (inspired by openclaw link-understanding).
Usage: bro_url_content.py "message with https://example.com and text"
   or: echo "message" | bro_url_content.py
"""
import re
import sys
import urllib.request
import urllib.error
from html.parser import HTMLParser

DEFAULT_TIMEOUT = 15
MAX_URLS = 5
MAX_CONTENT_CHARS = 30000

# Bare HTTP(S) URLs; strip markdown [text](url) first
MARKDOWN_LINK_RE = re.compile(r"\[[^\]]*\]\((https?://\S+?)\)", re.I)
BARE_LINK_RE = re.compile(r"https?://[^\s#>\]\)]+")


def strip_markdown_links(text: str) -> str:
    return MARKDOWN_LINK_RE.sub(" ", text or "")


def extract_urls(message: str, max_urls: int = MAX_URLS) -> list[str]:
    if not (message or message.strip()):
        return []
    sanitized = strip_markdown_links(message)
    seen = set()
    out = []
    for m in BARE_LINK_RE.finditer(sanitized):
        raw = m.group(0).strip()
        # Skip localhost
        if "127.0.0.1" in raw or "localhost" in raw.lower():
            continue
        if raw in seen:
            continue
        seen.add(raw)
        out.append(raw)
        if len(out) >= max_urls:
            break
    return out


class StripHTMLParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.text_parts = []

    def handle_data(self, data):
        self.text_parts.append(data)

    def get_text(self) -> str:
        return " ".join(self.text_parts).replace("\n", " ").strip()


def strip_html_fallback(html: str) -> str:
    parser = StripHTMLParser()
    try:
        parser.feed(html)
        return parser.get_text()
    except Exception:
        return re.sub(r"<[^>]+>", " ", html).replace("\n", " ").strip()


def extract_main_content(html: str, url: str) -> str:
    try:
        from readability import Document
        doc = Document(html)
        title = doc.title() or ""
        content = doc.summary() or ""
        # Remove tags for readability output (it returns HTML)
        content = re.sub(r"<[^>]+>", " ", content).replace("\n", " ").strip()
        content = re.sub(r"\s+", " ", content)
        if title:
            return f"{title}\n{content}"
        return content
    except ImportError:
        pass
    except Exception:
        pass
    return strip_html_fallback(html)


def fetch_url(url: str, timeout: int = DEFAULT_TIMEOUT) -> str | None:
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "BRO-url-content/1.0 (UPlanet IA)"},
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.headers.get_content_type().split(";")[0].strip().lower() != "text/html":
                return None
            return resp.read().decode("utf-8", errors="replace")
    except Exception:
        return None


def main() -> None:
    if len(sys.argv) > 1:
        message = " ".join(sys.argv[1:])
    else:
        message = sys.stdin.read()
    urls = extract_urls(message)
    if not urls:
        sys.exit(0)
    parts = []
    for url in urls:
        html = fetch_url(url)
        if not html:
            continue
        text = extract_main_content(html, url)
        if not text or len(text) < 20:
            continue
        if len(text) > MAX_CONTENT_CHARS:
            text = text[:MAX_CONTENT_CHARS] + "..."
        parts.append(f"URL: {url}\n{text}")
    if parts:
        print("\n\n---\n\n".join(parts))


if __name__ == "__main__":
    main()
