#!/usr/bin/env python3

"""
ZetCode Tkinter tutorial

In this example, we use the pack
manager to create a review example.

Author: Jan Bodnar
Website: www.zetcode.com
"""

import PySimpleGUI as sg
from lib.gva import GvaApi
import sys, os, threading
from shutil import copyfile
from os.path import join, dirname
from dotenv import load_dotenv
from lib.natools import get_privkey
import requests

class StdoutRedirector(object):
    def __init__(self, text_widget):
        self.text_widget = text_widget
 
    def write(self, s):
        self.text_widget.insert('end', s)
        self.text_widget.see('end')

    def flush(self):
        pass


MY_PATH = os.path.realpath(os.path.dirname(sys.argv[0])) + '/'

# Get variables environment
if not os.path.isfile(MY_PATH + '.env'):
    copyfile(MY_PATH + ".env.template",MY_PATH +  ".env")
dotenv_path = join(dirname(__file__),MY_PATH +  '.env')
load_dotenv(dotenv_path)

dunikey = os.getenv('DUNIKEY')
if not os.path.isfile(dunikey):
    HOME = os.getenv("HOME")
    dunikey = HOME + dunikey
    if not os.path.isfile(dunikey):
        sys.stderr.write('Le fichier de trousseau {0} est introuvable.\n'.format(dunikey))
        sys.exit(1)
node = os.getenv('NODE')
issuer = get_privkey(dunikey, "pubsec").pubkey


def ProceedPaiement(recipient, amount, comment):
    if not recipient:
        raise ValueError("Veuillez indiquer un destinataire de paiement")
    elif not amount:
        raise ValueError("Veuillez indiquer le montant de la transaction")

    amount = int(float(amount.replace(',','.'))*100)
    print("Paiement en cours vers", recipient)
    gva = GvaApi(dunikey, node, recipient)
    gva.pay(amount, comment, False, False)

    recipient = amount = comment = None


sg.theme('DarkGrey2')
layout = [  [sg.Text('Noeud utilisé: ' + node)],
            [sg.Text('Votre clé publique: ' + issuer)],
            [sg.Text('')],
            [sg.Text('Destinataire:  '), sg.InputText(size=(55, None),default_text=issuer)],
            [sg.Text('Montant:        '), sg.InputText(size=(7, None)), sg.Text('Ḡ1')],
            [sg.Text('Commentaire:'), sg.InputText(size=(55, None))],
            [sg.Button('Envoyer')] ]

# Create the Window
window = sg.Window('Paiement Ḡ1 - GVA', layout)
# availablePubkeys = requests.get('https://g1-stats.axiom-team.fr/data/wallets-g1.txt')
while True:
    try:
        event, values = window.read()
        if event == sg.WIN_CLOSED:
            break
        if event == 'Envoyer':
            ProceedPaiement(values[0], values[1], values[2])
    except Exception as e:
        loc = window.CurrentLocation()
        sg.popup(e, title="ERREUR", button_color=('black','red'), location=(loc))
    else:
        loc = window.CurrentLocation()
        sg.popup(f'Transaction effectué avec succès !', title="Envoyé", location=(loc))


window.close()
