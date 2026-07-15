#!/usr/bin/env python3
# ZICMAMA laptop — portail captif walled-garden.
#
# Aucune route n'est ouverte entre le réseau ZICMAMA et Internet (voir
# zicmama-ap-firewall.sh) : ce process fait lui-même office de proxy vers
# PORTAL_URL. Par défaut PORTAL_URL pointe vers l'UPassport de CETTE station
# (127.0.0.1:54321/earth/atomic_demo.html — compte ATOM4LOVE local, sans
# MULTIPASS) : aucun accès Internet n'est nécessaire. Les visiteurs ne
# voient jamais que cette seule page/origine.
import os
import urllib.error
import urllib.request
from urllib.parse import urlsplit
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORTAL_URL = os.environ.get("PORTAL_URL", "http://127.0.0.1:54321/earth/atomic_demo.html")
GATEWAY_IP = os.environ.get("GATEWAY_IP", "0.0.0.0")
# Port dédié (pas 80) : sur cette machine, docker-proxy (NPM) occupe déjà
# 0.0.0.0:80. zicmama-ap-firewall.sh redirige le port 80 entrant sur
# l'interface AP vers ce port via une règle nat REDIRECT.
PORTAL_PORT = int(os.environ.get("PORTAL_PORT", "8090"))

_parsed = urlsplit(PORTAL_URL)
PORTAL_SCHEME = _parsed.scheme or "https"
PORTAL_NETLOC = _parsed.netloc
PORTAL_ROOT_PATH = _parsed.path or "/"

HOP_BY_HOP = {
    "connection", "keep-alive", "transfer-encoding", "upgrade",
    "proxy-authenticate", "proxy-authorization", "te", "trailer",
}


PORTAL_ASSET_PREFIX = PORTAL_ROOT_PATH.rsplit("/", 1)[0] + "/"  # ex: "/earth/"


class ProxyHandler(BaseHTTPRequestHandler):
    def _proxy(self, method):
        # Tout chemin qui n'est pas une ressource réelle de la page (sous /earth/)
        # est redirigé vers le portail — pas seulement "/". Android (generate_204),
        # iOS (hotspot-detect.html), Windows (connecttest.txt) sondent des chemins
        # arbitraires sur les domaines wildcardés par dnsmasq vers cette passerelle :
        # sans ce catch-all, ces sondes tombaient sur un 404 brut du backend au lieu
        # d'être renvoyées vers la page, et l'OS concluait "pas de portail captif
        # utilisable" plutôt que d'ouvrir la fenêtre de connexion.
        if not self.path.startswith(PORTAL_ASSET_PREFIX):
            self.send_response(302)
            self.send_header("Location", PORTAL_ROOT_PATH)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        target = f"{PORTAL_SCHEME}://{PORTAL_NETLOC}{self.path}"
        try:
            req = urllib.request.Request(
                target, method=method,
                headers={"User-Agent": self.headers.get("User-Agent", "ZICMAMA-portal")},
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                self.send_response(resp.status)
                for key, value in resp.getheaders():
                    if key.lower() not in HOP_BY_HOP:
                        self.send_header(key, value)
                self.end_headers()
                if method != "HEAD":
                    self.wfile.write(resp.read())
        except urllib.error.HTTPError as exc:
            self.send_response(exc.code)
            self.end_headers()
        except Exception:
            self.send_response(502)
            self.end_headers()

    def do_GET(self):
        self._proxy("GET")

    def do_HEAD(self):
        self._proxy("HEAD")

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer((GATEWAY_IP, PORTAL_PORT), ProxyHandler).serve_forever()
