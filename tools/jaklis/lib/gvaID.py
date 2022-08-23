#!/usr/bin/env python3

import sys, re, os.path, json, ast
from termcolor import colored
from lib.natools import fmt, sign, get_privkey
from gql import gql, Client
from gql.transport.aiohttp import AIOHTTPTransport

PUBKEY_REGEX = "(?![OIl])[1-9A-Za-z]{42,45}"

class Id:

    def __init__(self, dunikey, node, pubkey='', username=''):
       
        self.dunikey = dunikey
        self.pubkey = pubkey if pubkey else get_privkey(dunikey, "pubsec").pubkey
        self.username = username
        # if not re.match(PUBKEY_REGEX, self.pubkey) or len(self.pubkey) > 45:
        #     sys.stderr.write("La clé publique n'est pas au bon format.\n")
        #     sys.exit(1)

        # Define Duniter GVA node
        transport = AIOHTTPTransport(url=node)
        self.client = Client(transport=transport, fetch_schema_from_transport=True)

    def sendDoc(self, getBalance=False):
        # Build balance generation document
        if (getBalance):
            queryBuild = gql(
                """
                query ($pubkey: PubKeyGva!, $script: PkOrScriptGva!){
                    idty (pubkey: $pubkey) {
                        isMember
                        username
                    }
                    balance(script: $script) {
                    amount
                    }
                }
            """
            )
        else:
            queryBuild = gql(
                """
                query ($pubkey: PubKeyGva!){
                    idty (pubkey: $pubkey) {
                        isMember
                        username
                    }
                }
            """
            )
        
        paramsBuild = {
            "pubkey": self.pubkey,
            "script": f"SIG({self.pubkey})"
        }

        # Send balance document
        try:
            queryResult = self.client.execute(queryBuild, variable_values=paramsBuild)
        except Exception as e:
            sys.stderr.write("Echec de récupération du solde:\n" + str(e) + "\n")
            sys.exit(1)

        jsonBrut = queryResult
        
        if (getBalance):            
            if (queryResult['balance'] == None):
                jsonBrut['balance'] = {"amount": 0.0}
            else:
                jsonBrut['balance'] = queryResult['balance']['amount']/100
                
        if (queryResult['idty'] == None):
            username = 'Matiou'
            isMember = False
        else:
            username = queryResult['idty']['username']
            isMember = queryResult['idty']['isMember']

        return json.dumps(jsonBrut, indent=2)
