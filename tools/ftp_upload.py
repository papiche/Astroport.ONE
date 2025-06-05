#!/usr/bin/env python3
"""
Script FTP avancé avec configuration par fichier ftp_client.conf
Valeurs par défaut :
- Host: ftp.vuqo5290.odns.fr
- User: sagittarius@oooz.fr
"""

import os
import argparse
import configparser
from ftplib import FTP
from getpass import getpass
from pathlib import Path
import logging
from datetime import datetime

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# Chemin du fichier de configuration
CONFIG_FILE = 'ftp_client.conf'

# Valeurs par défaut
DEFAULT_CONFIG = {
    'ftp': {
        'host': 'ftp.vuqo5290.odns.fr',
        'user': 'sagittarius@oooz.fr',
        'password': '',
        'local_dir': './',
        'remote_dir': '/'
    }
}

class FTPConfig:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.load_config()

    def load_config(self):
        """Charge la configuration depuis le fichier ou crée le fichier avec les valeurs par défaut"""
        if not os.path.exists(CONFIG_FILE):
            self.create_default_config()

        self.config.read(CONFIG_FILE)

        # Vérifie que toutes les sections et options existent
        for section, options in DEFAULT_CONFIG.items():
            if not self.config.has_section(section):
                self.config.add_section(section)
            for option, value in options.items():
                if not self.config.has_option(section, option):
                    self.config.set(section, option, str(value))

    def create_default_config(self):
        """Crée le fichier de configuration avec les valeurs par défaut"""
        self.config.read_dict(DEFAULT_CONFIG)
        with open(CONFIG_FILE, 'w') as configfile:
            self.config.write(configfile)
        logger.info(f"Fichier de configuration créé: {CONFIG_FILE}")
        os.chmod(CONFIG_FILE, 0o600)  # Permissions restrictives

    def get(self, section, option):
        """Récupère une valeur de configuration"""
        return self.config.get(section, option)

    def set(self, section, option, value):
        """Définit une valeur de configuration"""
        self.config.set(section, option, value)
        with open(CONFIG_FILE, 'w') as configfile:
            self.config.write(configfile)

class FTPClient:
    def __init__(self, host, user, password):
        self.ftp = FTP(host)
        self.ftp.login(user, password)
        logger.info(f"Connecté à {host}")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.ftp.quit()
        logger.info("Déconnexion FTP")

    def list_directory(self, remote_path='/'):
        """Liste récursivement le contenu distant avec tailles et dates"""
        def _list_recursive(path, indent=0):
            try:
                files = []
                self.ftp.cwd(path)
                self.ftp.retrlines('LIST', files.append)

                for line in files:
                    parts = line.split()
                    if len(parts) < 9:
                        continue

                    perm, _, owner, group, size, mon, day, time_or_year, name = parts[:9]
                    is_dir = perm.startswith('d')
                    full_path = f"{path}/{name}" if path != '/' else f"/{name}"

                    print(f"{' ' * indent}{'📁' if is_dir else '📄'} {name}")

                    if is_dir:
                        _list_recursive(full_path, indent + 2)
            except Exception as e:
                logger.error(f"Erreur listing {path}: {e}")

        print(f"\nContenu de {remote_path}:")
        _list_recursive(remote_path)

    def get_remote_files(self, remote_path):
        """Récupère la liste des fichiers distants avec leurs tailles et dates"""
        files = {}
        try:
            self.ftp.cwd(remote_path)
            lines = []
            self.ftp.retrlines('LIST', lines.append)

            for line in lines:
                parts = line.split()
                if len(parts) < 9:
                    continue

                name = parts[-1]
                size = int(parts[4])
                date_str = ' '.join(parts[5:8])

                try:
                    date = datetime.strptime(date_str, '%b %d %Y')
                except:
                    try:
                        date = datetime.strptime(date_str, '%b %d %H:%M')
                        date = date.replace(year=datetime.now().year)
                    except:
                        date = datetime.now()

                files[name] = {
                    'size': size,
                    'date': date,
                    'path': f"{remote_path}/{name}" if remote_path != '/' else f"/{name}"
                }
        except Exception as e:
            logger.error(f"Erreur scan distant {remote_path}: {e}")
        return files

    def upload_directory(self, local_path, remote_path, sync=False):
        """Upload récursif avec option sync"""
        local_files = {}
        for root, _, files in os.walk(local_path):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, local_path)
                local_files[rel_path] = {
                    'path': full_path,
                    'size': os.path.getsize(full_path),
                    'date': datetime.fromtimestamp(os.path.getmtime(full_path))
                }

        remote_files = self.get_remote_files(remote_path) if sync else {}

        for rel_path, local in local_files.items():
            remote_file_path = f"{remote_path}/{rel_path}".replace('\\', '/')
            remote_dir = os.path.dirname(remote_file_path)

            self._ensure_remote_path(remote_dir)

            if sync and rel_path in remote_files:
                remote = remote_files[rel_path]
                if (local['size'] == remote['size'] and
                    local['date'] <= remote['date']):
                    logger.debug(f"Fichier à jour - ignoré: {rel_path}")
                    continue

            logger.info(f"Upload: {rel_path}")
            with open(local['path'], 'rb') as f:
                self.ftp.storbinary(f'STOR {remote_file_path}', f)

    def _ensure_remote_path(self, remote_path):
        """Crée l'arborescence distante si nécessaire"""
        try:
            self.ftp.cwd(remote_path)
            return
        except:
            pass

        parts = [p for p in remote_path.split('/') if p]
        current_path = ""
        for part in parts:
            current_path += f"/{part}"
            try:
                self.ftp.mkd(current_path)
                logger.debug(f"Créé: {current_path}")
            except:
                pass

def main():
    # Chargement de la configuration
    config = FTPConfig()

    parser = argparse.ArgumentParser(
        description="Client FTP avancé avec fichier de configuration",
        epilog=f"""
        Configuration par défaut stockée dans {CONFIG_FILE}
        Valeurs par défaut:
        - Host: {DEFAULT_CONFIG['ftp']['host']}
        - User: {DEFAULT_CONFIG['ftp']['user']}
        """
    )

    # Arguments communs
    parser.add_argument('--host', help="Serveur FTP", default=config.get('ftp', 'host'))
    parser.add_argument('--user', help="Utilisateur FTP", default=config.get('ftp', 'user'))
    parser.add_argument('--password', help="Mot de passe FTP", default=config.get('ftp', 'password'))
    parser.add_argument('--debug', help="Mode debug", action='store_true')

    # Sous-commandes
    subparsers = parser.add_subparsers(dest='command', required=True)

    # Commande list
    list_parser = subparsers.add_parser('list', help="Lister le contenu distant")
    list_parser.add_argument('--remote-dir', help="Répertoire distant", default=config.get('ftp', 'remote_dir'))

    # Commande upload
    upload_parser = subparsers.add_parser('upload', help="Uploader un répertoire")
    upload_parser.add_argument('--local-dir', help="Répertoire local", default=config.get('ftp', 'local_dir'))
    upload_parser.add_argument('--remote-dir', help="Répertoire distant", default=config.get('ftp', 'remote_dir'))

    # Commande sync
    sync_parser = subparsers.add_parser('sync', help="Synchroniser un répertoire")
    sync_parser.add_argument('--local-dir', help="Répertoire local", default=config.get('ftp', 'local_dir'))
    sync_parser.add_argument('--remote-dir', help="Répertoire distant", default=config.get('ftp', 'remote_dir'))

    args = parser.parse_args()

    if args.debug:
        logger.setLevel(logging.DEBUG)
        logger.debug("Mode debug activé")

    # Récupération des credentials
    ftp_host = args.host
    ftp_user = args.user
    ftp_pass = args.password or getpass("Mot de passe FTP: ")

    try:
        with FTPClient(ftp_host, ftp_user, ftp_pass) as client:
            if args.command == 'list':
                client.list_directory(args.remote_dir)
            elif args.command == 'upload':
                client.upload_directory(args.local_dir, args.remote_dir)
            elif args.command == 'sync':
                client.upload_directory(args.local_dir, args.remote_dir, sync=True)

    except Exception as e:
        logger.error(f"Erreur: {e}")

if __name__ == "__main__":
    main()
