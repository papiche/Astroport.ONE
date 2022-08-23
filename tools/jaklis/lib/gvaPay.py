#!/usr/bin/env python3

import sys, re, os.path, json, ast
from termcolor import colored
from lib.natools import fmt, sign, get_privkey
from gql import gql, Client
from gql.transport.aiohttp import AIOHTTPTransport

PUBKEY_REGEX = "(?![OIl])[0-9A-Za-z]{42,45}"

class Transaction:

    def __init__(self, dunikey, node, recipient, amount, comment='', useMempool=False, verbose=False):
        self.dunikey = dunikey
        self.recipient = recipient
        self.amount = int(amount*100)
        self.comment = comment
        self.issuer = get_privkey(dunikey, "pubsec").pubkey
        self.useMempool = useMempool
        self.verbose = verbose
        self.node = node
        self._isChange = False

        try:
            if not re.match(PUBKEY_REGEX, recipient) or len(recipient) > 45:
                raise ValueError("La clé publique n'est pas au bon format.")
        except:
            sys.stderr.write("La clé publique n'est pas au bon format.\n")
            raise


        try:
            if recipient == self.issuer:
                raise ValueError('Le destinataire ne peut pas être vous même.')
        except:
            sys.stderr.write("Le destinataire ne peut pas être vous même.\n")
            raise


        # Define Duniter GVA node
        transport = AIOHTTPTransport(url=node)
        self.client = Client(transport=transport, fetch_schema_from_transport=True)

    def genDoc(self):
        # Build TX generation document
        if self.verbose: print("useMempool:", str(self.useMempool))
        queryBuild = gql(
            """
            query ($recipient: PkOrScriptGva!, $issuer: PubKeyGva!, $amount: Int!, $comment: String!, $useMempool: Boolean!){ genTx(
            amount: $amount
            comment: $comment
            issuer: $issuer
            recipient: $recipient
            useMempoolSources: $useMempool
            )
        }
        """
        )
        paramsBuild = {
            "recipient": self.recipient,
            "issuer": self.issuer,
            "amount": int(self.amount),
            "comment": self.comment,
            "useMempool": self.useMempool
        }

        # Send TX document
        try:
            # self.txDoc = []
            self.txDoc =  self.client.execute(queryBuild, variable_values=paramsBuild)['genTx']
            if self.verbose: print(self.txDoc[0])
            return self.txDoc
        except Exception as e:
            message = ast.literal_eval(str(e))["message"]
            sys.stderr.write("Echec de la génération du document:\n" + message + "\n")
            raise


    # Check document
    def checkTXDoc(self):
        issuerRaw=[];outAmount=[];outPubkey=[];commentRaw=[]
        for docs in self.txDoc:
            docList = docs.splitlines()
            for i, line in enumerate(docList):
                if re.search("Issuers:", line):
                    issuerRaw.append(docList[(i + 1) % len(docList)])
                if re.search("Outputs:", line):
                    outputRaw = docList[(i + 1) % len(docList)].split(":")
                    outAmount.append(int(outputRaw[0]))
                    outPubkey.append(outputRaw[2].split("SIG(")[1].replace(')',''))
                if re.search("Comment:", line):
                    commentRaw.append(line.split(': ', 1)[1])

        # Check if it's only a change transaction
        if all(i == self.issuer for i in outPubkey):
            print("Le document contient une transaction de change")
            self.isChange = True
        # Check validity of the document
        elif all(i != self.issuer for i in issuerRaw) or sum(outAmount) != self.amount or all(i != self.recipient for i in outPubkey) or all(i != self.comment for i in commentRaw):
            sys.stderr.write(colored("Le document généré est corrompu !\nLe noeud " + self.node + "a peut être un dysfonctionnement.\n", 'red'))
            sys.stderr.write(colored(issuerRaw[0] + " envoi " + str(outAmount[0]) + " vers " + outPubkey[0] + " with comment: " + commentRaw[0] + "\n", "yellow"))
            raise ValueError('Le document généré est corrompu !')
        else:
            print("Le document généré est conforme.")
            self.isChange = False
            return self.txDoc

    def signDoc(self):
        # Sign TX documents
        signature=[]
        self.signedDoc=[]
        for i, docs in enumerate(self.txDoc):
            signature.append(fmt["64"](sign(docs.encode(), get_privkey(self.dunikey, "pubsec"))[:-len(docs.encode())]))
            self.signedDoc.append(docs + signature[i].decode())
        return self.signedDoc


    def sendTXDoc(self):
        # Build TX documents
        txResult=[]
        for docs in self.signedDoc:
            querySign = gql(
                """
                mutation ($signedDoc: String!){ tx(
                rawTx: $signedDoc
                ) {
                    version
                    issuers
                    outputs
                }
            }
            """
            )
            paramsSign = {
                "signedDoc": docs
            }

            # Send TX Signed document
            try:
                txResult.append(str(self.client.execute(querySign, variable_values=paramsSign)))
            except Exception as e:
                message = ast.literal_eval(str(e))["message"]
                sys.stderr.write("Echec de la transaction:\n" + message + "\n")
                if self.verbose:
                    sys.stderr.write("Document final:\n" + docs)
                raise ValueError(message)
            else:
                if self.isChange:
                    self.send()
                else:
                    print(colored("Transaction effectué avec succès !", "green"))
                    if self.verbose:
                        print(docs)
                    break

        return txResult

    def _getIsChange(self):
        return self._isChange
    def _setIsChange(self, newChange):
        if self.verbose: print("_setIsChange: ", str(newChange))
        self._isChange = newChange
        if newChange: self.useMempool == True
    isChange = property(_getIsChange, _setIsChange)

    def send(self):
        result = self.genDoc()
        result = self.checkTXDoc()
        result = self.signDoc()
        result = self.sendTXDoc()
        return result

