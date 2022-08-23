#!/usr/bin/env python3

import sys, re, os.path, json, ast, time, hashlib
from datetime import datetime
from duniterpy.key import base58
from termcolor import colored
from lib.natools import fmt, sign, get_privkey
from gql import gql, Client
from gql.transport.aiohttp import AIOHTTPTransport

PUBKEY_REGEX = "(?![OIl])[1-9A-Za-z]{42,45}"

class History:

    def __init__(self, dunikey, node, pubkey):
        self.dunikey = dunikey
        self.pubkey = pubkey if pubkey else get_privkey(dunikey, "pubsec").pubkey
        self.node = node
        if not re.match(PUBKEY_REGEX, self.pubkey) or len(self.pubkey) > 45:
            sys.stderr.write("La clé publique n'est pas au bon format.\n")
            sys.exit(1)

        # Define Duniter GVA node
        transport = AIOHTTPTransport(url=node)
        self.client = Client(transport=transport, fetch_schema_from_transport=True)

    def sendDoc(self, number):
        # Build history generation document
        queryBuild = gql(
            """
            query ($pubkey: PubKeyGva!, $script: PkOrScriptGva!, $number: Int!){
                txsHistoryBc(
                    script: $script
                    pagination: { pageSize: $number, ord: DESC }
                ) {
                    both {
                        pageInfo {
                            hasPreviousPage
                            hasNextPage
                        }
                        edges {
                            direction
                            node {
                                currency
                                issuers
                                outputs
                                comment
                                writtenTime
                            }
                        }
                    }
                }
                txsHistoryMp(pubkey: $pubkey) {
                    receiving {
                        currency
                        issuers
                        comment
                        outputs
                        receivedTime
                    }
                    receiving {
                        currency
                        issuers
                        comment
                        outputs
                        receivedTime
                    }
                }
                balance(script: $script) {
                    amount
                    base
                }
                node {
                    peer {
                        currency
                    }
                }
                currentUd {
                    amount
                    base
                }
            }
        """
        )
        paramsBuild = {
            "pubkey": self.pubkey,
            "number": number,
            "script": f"SIG({self.pubkey})",
        }

        # Send history document
        try:
            self.historyDoc = self.client.execute(queryBuild, variable_values=paramsBuild)
        except Exception as e:
            message = ast.literal_eval(str(e))["message"]
            sys.stderr.write("Echec de récupération de l'historique:\n" + message + "\n")
            sys.exit(1)


    def parseHistory(self):
        trans = []
        i = 0

        currentBase = int(self.historyDoc['currentUd']['base'])
        self.UD = self.historyDoc['currentUd']['amount']/100


        # Parse transactions in blockchain
        resBc = []
        resBc = self.historyDoc['txsHistoryBc']['both']['edges']
        for j, transaction in enumerate(resBc):
            # print(transaction)
            direction = resBc[j]['direction']
            transaction = resBc[j]['node']
            output = transaction['outputs'][0]
            outPubkey = output.split("SIG(")[1].replace(')','')
            # if direction == 'RECEIVED' or self.pubkey != outPubkey:
            trans.append(i)
            trans[i] = []
            trans[i].append(direction)
            trans[i].append(transaction['writtenTime'])
            if direction == 'SENT':
                trans[i].append(outPubkey)
                amount = int('-' + output.split(':')[0])
            else:
                trans[i].append(transaction['issuers'][0])
                amount = int(output.split(':')[0])
            base = int(output.split(':')[1])
            applyBase = base-currentBase
            amount = round(amount*pow(10,applyBase)/100, 2)
            # if referential == 'DU': amount = round(amount/UD, 2)
            trans[i].append(amount)
            trans[i].append(round(amount/self.UD, 2))
            trans[i].append(transaction['comment'])
            trans[i].append(base)
            i += 1

        # Parse transactions in mempool
        for direction in self.historyDoc['txsHistoryMp']:
            resBc = []
            resBc = self.historyDoc['txsHistoryMp'][direction]
            for j, transaction in enumerate(resBc):
                # print(transaction)
                transaction = resBc[j]
                output = transaction['outputs'][0]
                outPubkey = output.split("SIG(")[1].replace(')','')
                # if direction == 'RECEIVING' or self.pubkey != outPubkey:
                trans.append(i)
                trans[i] = []
                trans[i].append(direction)
                trans[i].append(int(time.time()))
                if direction == 'SENDING':
                    trans[i].append(outPubkey)
                    amount = int('-' + output.split(':')[0])
                else:
                    trans[i].append(transaction['issuers'][0])
                    amount = int(output.split(':')[0])
                base = int(output.split(':')[1])
                applyBase = base-currentBase
                amount = round(amount*pow(10,applyBase)/100, 2)
                # if referential == 'DU': amount = round(amount/UD, 2)
                trans[i].append(amount)
                trans[i].append(round(amount/self.UD, 2))
                trans[i].append(transaction['comment'])
                trans[i].append(base)
                i += 1

        # Order transactions by date
        trans.sort(key=lambda x: x[1])

        # Keep only base if there is base change
        lastBase = 0
        for i in trans:
            if i[6] == lastBase: i[6] = None
            else: lastBase = i[6]
        
        return trans

    def printHistory(self, trans, noColors):
        # Get balance
        if (self.historyDoc['balance'] == None): 
            balance = balanceUD = 'null'
        else:
    
            balance = self.historyDoc['balance']['amount']/100
            balanceUD = round(balance/self.UD, 2)

        # Get currency
        currency = self.historyDoc['node']['peer']['currency']
        if currency == 'g1': currency = 'Ḡ1'
        elif currency == 'g1-test': currency = 'GT'
        # if referential == 'DU': currency = 'DU/' + currency.lower()

        # Get terminal size
        rows = int(os.popen('stty size', 'r').read().split()[1])

        # Display history
        print('+', end='')
        print('-'.center(rows-1, '-'))
        if noColors: isBold = isBoldEnd = ''
        else:
            isBold = '\033[1m'
            isBoldEnd = '\033[0m'
        print(isBold + "|{: <19} | {: <12} | {: <7} | {: <7} | {: <30}".format("        Date","   De / À","  {0}".format(currency)," DU/{0}".format(currency.lower()),"Commentaire") + isBoldEnd)
        print('|', end='')
        for t in trans:
            if t[0] == "RECEIVED": color = "green"
            elif t[0] == "SENT": color = "blue"
            elif t[0] == "receiving": color = "yellow"
            elif t[0] == "sending": color = "red"
            else: color = None
            if noColors:
                color = None
                if t[0] in ('RECEIVING','SENDING'):
                    comment = '(EN ATTENTE) ' + t[5]
                else:
                    comment = t[5]
            else:
                comment = t[5]

            date = datetime.fromtimestamp(t[1]).strftime("%d/%m/%Y à %H:%M")
            print('-'.center(rows-1, '-'))
            if t[6]:
                print('|', end='')
                print('  Changement de base : {0}  '.format(t[6]).center(rows-1, '#'))
                print('|', end='')
                print('-'.center(rows-1, '-'))
            print('|', end='')
            checksum = self.gen_checksum(t[2])
            shortPubkey = t[2][0:4] + '\u2026' + t[2][-4:] + ':' + checksum
            if noColors:
                print(" {: <18} | {: <12} | {: <7} | {: <7} | {: <30}".format(date, shortPubkey, t[3], t[4], comment))
            else:
                print(colored(" {: <18} | {: <12} | {: <7} | {: <7} | {: <30}".format(date, shortPubkey, t[3], t[4], comment), color))
            print('|', end='')
        print('-'.center(rows-1, '-'))
        print('|', end='')
        print(isBold + 'Solde du compte: {0} {1} ({2} DU/{3})'.format(balance, currency, balanceUD, currency.lower()).center(rows-1, ' ') + isBoldEnd)
        print('+', end='')
        print(''.center(rows-1, '-'))
        if not noColors:
            print(colored('Reçus', 'green'), '-', colored('En cours de réception', 'yellow'), '-', colored('Envoyé', 'blue'), '-', colored("En cours d'envoi", 'red'))

        return trans
    
    def gen_checksum(self, pubkey):
        """
        Returns the checksum of the input pubkey (encoded in b58)
        thx Matograine
        """
        pubkey_byte = base58.Base58Encoder.decode(str.encode(pubkey))
        hash = hashlib.sha256(hashlib.sha256(pubkey_byte).digest()).digest()
        return base58.Base58Encoder.encode(hash)[:3]

    def jsonHistory(self, transList):
        dailyJSON = []
        for i, trans in enumerate(transList):
            dailyJSON.append(i)
            dailyJSON[i] = {}
            dailyJSON[i]['date'] = trans[1]
            dailyJSON[i]['pubkey'] = trans[2]
            dailyJSON[i]['amount'] = trans[3]
            dailyJSON[i]['amountUD'] = trans[4]
            dailyJSON[i]['comment'] = trans[5]

        dailyJSON = json.dumps(dailyJSON, indent=2)
        # If we want to write JSON to a file
        #jsonFile = open("history-{0}.json".format(self.pubkey[0:8]), "w")
        #jsonFile.writelines(dailyJSON + '\n')
        #jsonFile.close()
        return dailyJSON

