#!/usr/bin/env python3
"""
Script pour uploader un répertoire vers un serveur FTP avec support:
- Arguments CLI
- Fichier .env
- Interactive prompt (si aucune option fournie)
"""

import os
import argparse
from ftplib import FTP
from getpass import getpass
from pathlib import Path
from dotenv import load_dotenv
import logging

# Configuration du logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

# Charger les variables d'environnement depuis .env
load_dotenv()

def upload_directory(ftp, local_path, remote_path):
    """Upload récursif d'un répertoire vers FTP"""
    try:
        ftp.mkd(remote_path)
        logger.info(f"Création du répertoire distant: {remote_path}")
    except Exception as e:
        logger.debug(f"Le répertoire existe probablement déjà: {e}")

    for item in os.listdir(local_path):
        local_item = os.path.join(local_path, item)
        remote_item = os.path.join(remote_path, item)
        
        if os.path.isfile(local_item):
            logger.info(f"Upload du fichier: {local_item} -> {remote_item}")
            with open(local_item, 'rb') as f:
                ftp.storbinary(f'STOR {remote_item}', f)
        elif os.path.isdir(local_item):
            upload_directory(ftp, local_item, remote_item)

def get_ftp_connection(host, user, password):
    """Établit une connexion FTP"""
    try:
        ftp = FTP(host)
        ftp.login(user, password)
        logger.info(f"Connecté avec succès à {host}")
        return ftp
    except Exception as e:
        logger.error(f"Erreur de connexion FTP: {e}")
        raise

def ensure_remote_path(ftp, remote_path):
    """S'assure que le chemin distant existe"""
    try:
        ftp.cwd(remote_path)
    except:
        parts = [p for p in remote_path.split('/') if p]
        current_path = ""
        for part in parts:
            current_path += f"/{part}"
            try:
                ftp.mkd(current_path)
                logger.debug(f"Création du répertoire distant: {current_path}")
            except:
                pass

def main():
    parser = argparse.ArgumentParser(
        description="Uploader un répertoire vers un serveur FTP",
        epilog="""
        Configuration via .env:
        Créez un fichier .env dans le même répertoire avec ces variables:
        FTP_HOST=your.ftp.server
        FTP_USER=your_username
        FTP_PASS=your_password
        FTP_LOCAL_DIR=./local_path
        FTP_REMOTE_DIR=/remote_path
        
        Priorité des configurations:
        1. Arguments CLI
        2. Variables d'environnement
        3. Prompt interactif
        """
    )
    
    parser.add_argument('--host', help="Adresse du serveur FTP", default=os.getenv('FTP_HOST'))
    parser.add_argument('--user', help="Nom d'utilisateur FTP", default=os.getenv('FTP_USER'))
    parser.add_argument('--password', help="Mot de passe FTP", default=os.getenv('FTP_PASS'))
    parser.add_argument('--local-dir', help="Répertoire local à uploader", default=os.getenv('FTP_LOCAL_DIR'))
    parser.add_argument('--remote-dir', help="Répertoire distant cible", default=os.getenv('FTP_REMOTE_DIR', '/'))
    parser.add_argument('--debug', help="Mode debug", action='store_true')
    
    args = parser.parse_args()
    
    if args.debug:
        logger.setLevel(logging.DEBUG)
        logger.debug("Mode debug activé")
    
    # Récupération des credentials
    ftp_host = args.host or input("Adresse du serveur FTP: ")
    ftp_user = args.user or input("Nom d'utilisateur FTP: ")
    ftp_pass = args.password or getpass("Mot de passe FTP: ")
    local_dir = args.local_dir or input("Répertoire local à uploader: ")
    remote_dir = args.remote_dir or input("Répertoire distant [default: /]: ") or '/'
    
    # Validation des chemins
    if not os.path.isdir(local_dir):
        logger.error(f"Le répertoire local n'existe pas: {local_dir}")
        return
    
    try:
        with get_ftp_connection(ftp_host, ftp_user, ftp_pass) as ftp:
            ensure_remote_path(ftp, remote_dir)
            upload_directory(ftp, local_dir, remote_dir)
            logger.info("Transfert terminé avec succès!")
    except Exception as e:
        logger.error(f"Erreur lors du transfert: {e}")

if __name__ == "__main__":
    main()