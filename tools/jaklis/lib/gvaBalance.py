#!/usr/bin/env python3

import sys, re, os.path, json, ast
from termcolor import colored
from lib.natools import fmt, sign, get_privkey
from gql import gql, Client
from gql.transport.aiohttp import AIOHTTPTransport

PUBKEY_REGEX = "(?![OIl])[1-9A-Za-z]{42,45}"

class Balance:

    def __init__(self, dunikey, node, pubkey, useMempool=False):
        self.dunikey = dunikey
        self.pubkey = pubkey if pubkey else get_privkey(dunikey, "pubsec").pubkey
        self.useMempool = useMempool
        if not re.match(PUBKEY_REGEX, self.pubkey) or len(self.pubkey) > 45:
            sys.stderr.write("La clé publique n'est pas au bon format.\n")
            sys.exit(1)

        # Define Duniter GVA node
        transport = AIOHTTPTransport(url=node)
        self.client = Client(transport=transport, fetch_schema_from_transport=True)

    def sendDoc(self):
        # Build balance generation document
        queryBuild = gql(
            """
            query ($pubkey: PkOrScriptGva!){
                balance(script: $pubkey) {
                    amount
                }
            }
        """
        )
        paramsBuild = {
            "pubkey": self.pubkey
        }

        # Send balance document
        try:
            balanceResult = self.client.execute(queryBuild, variable_values=paramsBuild)
        except Exception as e:
            message = ast.literal_eval(str(e))["message"]
            sys.stderr.write("Echec de récupération du solde:\n" + message + "\n")
            sys.exit(1)
            
        if (balanceResult['balance'] == None): balanceValue = 'null'
        else:
            balanceValue = balanceResult['balance']['amount']/100

        # print(balanceValue)
        return balanceValue
