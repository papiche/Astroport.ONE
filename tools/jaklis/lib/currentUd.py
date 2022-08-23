#!/usr/bin/env python3

import sys, re, os.path, json, ast
from termcolor import colored
from lib.natools import fmt, sign, get_privkey
from gql import gql, Client
from gql.transport.aiohttp import AIOHTTPTransport

class currentUd:

    def __init__(self, node):
        # Define Duniter GVA node
        transport = AIOHTTPTransport(url=node)
        self.client = Client(transport=transport, fetch_schema_from_transport=True)

    def sendDoc(self):
        # Build UD generation document
        queryBuild = gql(
            """
            query {
                currentUd {
                    amount
                }
            }
        """
        )
        paramsBuild = {
        }

        # Send UD document
        try:
            udValue = self.client.execute(queryBuild, variable_values=paramsBuild)
        except Exception as e:
            message = ast.literal_eval(str(e))["message"]
            sys.stderr.write("Echec de récupération du DU:\n" + message + "\n")
            sys.exit(1)
            
        udValueFinal = udValue['currentUd']['amount']
    
        return udValueFinal
