from lib.currentUd import currentUd
import sys, re
from lib.natools import get_privkey
from lib.gvaPay import Transaction, PUBKEY_REGEX
from lib.gvaHistory import History
from lib.gvaBalance import Balance
from lib.gvaID import Id

class GvaApi():
    def __init__(self, dunikey, node, pubkey, noNeedDunikey=False):
        self.noNeedDunikey = noNeedDunikey
        self.dunikey = dunikey
        self.node = node
        if noNeedDunikey:
            self.pubkey = self.dunikey
        else:
            self.pubkey = get_privkey(dunikey, "pubsec").pubkey

        if pubkey:
            self.destPubkey = pubkey
        else:
            self.destPubkey = self.pubkey

        try:
            if not re.match(PUBKEY_REGEX, self.pubkey) or len(self.pubkey) > 45:
                raise ValueError("La clé publique n'est pas au bon format.")
        except:
            sys.stderr.write("La clé publique n'est pas au bon format.\n")
            raise

        try:
            if not re.match(PUBKEY_REGEX, self.destPubkey) or len(self.destPubkey) > 45:
                raise ValueError("La clé publique n'est pas au bon format.")
        except:
            sys.stderr.write("La clé publique n'est pas au bon format.\n")
            raise

    #################### Payments ####################

    def pay(self, amount, comment, mempool, verbose):
        gva = Transaction(self.dunikey, self.node, self.destPubkey, amount, comment, mempool, verbose)
        gva.genDoc()
        gva.checkTXDoc()
        gva.signDoc()
        return gva.sendTXDoc()

    def history(self, isJSON=False, noColors=False, number=10):
        gva = History(self.dunikey, self.node, self.destPubkey)
        gva.sendDoc(number)
        transList = gva.parseHistory()

        if isJSON:
            transJson = gva.jsonHistory(transList)
            print(transJson)
        else:
            gva.printHistory(transList, noColors)
    
    def balance(self, useMempool):
        gva = Balance(self.dunikey, self.node, self.destPubkey, useMempool)
        balanceValue = gva.sendDoc()
        print(balanceValue)
    
    def id(self, pubkey, username):
        gva = Id(self.dunikey, self.node, pubkey, username)
        result = gva.sendDoc()
        print(result)

    def idBalance(self, pubkey):
        gva = Id(self.dunikey, self.node, pubkey)
        result = gva.sendDoc(True)
        print(result)
    
    def currentUd(self):
        gva = currentUd(self.node)
        result = gva.sendDoc()
        print(result)