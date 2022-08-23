import os, sys, ast, requests, json, base58, base64
from time import time
from datetime import datetime
from termcolor import colored
from lib.natools import fmt, get_privkey, box_decrypt, box_encrypt
from lib.cesiumCommon import CesiumCommon, pp_json, PUBKEY_REGEX


#################### Reading class ####################


class ReadFromCesium(CesiumCommon):
    # Configure JSON document to send
    def configDoc(self, nbrMsg, outbox):
        boxType = "issuer" if outbox else "recipient"

        data = {}
        data['sort'] = { "time": "desc" }
        data['from'] = 0
        data['size'] = nbrMsg
        data['_source'] = ['issuer','recipient','title','content','time','nonce','read_signature']
        data['query'] = {}
        data['query']['bool'] = {}
        data['query']['bool']['filter'] = {}
        data['query']['bool']['filter']['term'] = {}
        data['query']['bool']['filter']['term'][boxType] = self.pubkey

        document = json.dumps(data)
        return document

    def sendDocument(self, nbrMsg, outbox):
        boxType = "outbox" if outbox else "inbox"

        document = self.configDoc(nbrMsg, outbox)
        headers = {
            'Content-type': 'application/json',
        }

        # Send JSON document and get JSON result
        result = requests.post('{0}/message/{1}/_search'.format(self.pod, boxType), headers=headers, data=document)
        if result.status_code == 200:
            return result.json()["hits"]
        else:
            sys.stderr.write("Echec de l'envoi du document de lecture des messages...\n" + result.text)

    # Parse JSON result and display messages
    def readMessages(self, msgJSON, nbrMsg, outbox):
        def decrypt(msg):
            msg64 = base64.b64decode(msg)
            return box_decrypt(msg64, get_privkey(self.dunikey, "pubsec"), self.issuer, nonce).decode()

        # Get terminal size
        rows = int(os.popen('stty size', 'r').read().split()[1])

        totalMsg = msgJSON["total"]
        if nbrMsg > totalMsg:
            nbrMsg = totalMsg

        if totalMsg == 0:
            print(colored("Aucun message à afficher.", 'yellow'))
            return True
        else:
            infoTotal = "  Nombre de messages: " + str(nbrMsg) + "/" + str(totalMsg) + "  "
            print(colored(infoTotal.center(rows, '#'), "yellow"))
            for hits in msgJSON["hits"]:
                self.idMsg = hits["_id"]
                msgSrc = hits["_source"]
                self.issuer = msgSrc["issuer"]
                nonce = msgSrc["nonce"]
                nonce = base58.b58decode(nonce)
                self.dateS = msgSrc["time"]
                date = datetime.fromtimestamp(self.dateS).strftime(", le %d/%m/%Y à %H:%M  ")
                if outbox:
                    startHeader = "  À " + msgSrc["recipient"]
                else:
                    startHeader = "  De " + self.issuer
                headerMsg = startHeader + date + "(ID: {})".format(self.idMsg) + "  "

                print('-'.center(rows, '-'))
                print(colored(headerMsg, "blue").center(rows+9, '-'))
                print('-'.center(rows, '-'))
                try:
                    self.title = decrypt(msgSrc["title"])
                    self.content = decrypt(msgSrc["content"])
                except Exception as e:
                    sys.stderr.write(colored(str(e), 'red') + '\n')
                    pp_json(hits)
                    continue
                print('\033[1m' + self.title + '\033[0m')
                print(self.content)
                
            print(colored(infoTotal.center(rows, '#'), "yellow"))
    
    # Parse JSON result and display messages
    def jsonMessages(self, msgJSON, nbrMsg, outbox):
        def decrypt(msg):
            msg64 = base64.b64decode(msg)
            return box_decrypt(msg64, get_privkey(self.dunikey, "pubsec"), self.issuer, nonce).decode()

        totalMsg = msgJSON["total"]
        if nbrMsg > totalMsg:
            nbrMsg = totalMsg

        if totalMsg == 0:
            print("Aucun message à afficher")
            return True
        else:
            data = []
            # data.append({})
            # data[0]['total'] = totalMsg
            for i, hits in enumerate(msgJSON["hits"]):
                self.idMsg = hits["_id"]
                msgSrc = hits["_source"]
                self.issuer = msgSrc["issuer"]
                nonce = msgSrc["nonce"]
                nonce = base58.b58decode(nonce)
                self.date = msgSrc["time"]

                if outbox:
                    pubkey = msgSrc["recipient"]
                else:
                    pubkey = self.issuer

                try:
                    self.title = decrypt(msgSrc["title"])
                    self.content = decrypt(msgSrc["content"])
                except Exception as e:
                    sys.stderr.write(colored(str(e), 'red') + '\n')
                    pp_json(hits)
                    continue

                data.append(i)
                data[i] = {}
                data[i]['id'] = self.idMsg
                data[i]['date'] = self.date
                data[i]['pubkey'] = pubkey
                data[i]['title'] = self.title
                data[i]['content'] = self.content

            data = json.dumps(data, indent=2)
            return data


#################### Sending class ####################


class SendToCesium(CesiumCommon):
    def encryptMsg(self, msg):
        return fmt["64"](box_encrypt(msg.encode(), get_privkey(self.dunikey, "pubsec"), self.recipient, self.nonce)).decode()

    def configDoc(self, title, msg):
        b58nonce = base58.b58encode(self.nonce).decode()

        # Get current timestamp
        timeSent = int(time())

        # Generate custom JSON
        data = {}
        data['issuer'] = self.pubkey
        data['recipient'] = self.recipient
        data['title'] = title
        data['content'] = msg
        data['time'] = timeSent
        data['nonce'] = b58nonce
        data['version'] = 2
        document = json.dumps(data)

        return self.signDoc(document)


    def sendDocument(self, document, outbox):
        boxType = "outbox" if outbox else "inbox"

        headers = {
            'Content-type': 'application/json',
        }

        # Send JSON document and get result
        try:
            result = requests.post('{0}/message/{1}?pubkey={2}'.format(self.pod, boxType, self.recipient), headers=headers, data=document)
        except Exception as e:
            sys.stderr.write("Impossible d'envoyer le message:\n" + str(e))
            sys.exit(1)
        else:
            if result.status_code == 200:
                print(colored("Message envoyé avec succès !", "green"))
                print("ID: " + result.text)
                return result
            else:
                sys.stderr.write("Erreur inconnue:" + '\n')
                print(str(pp_json(result.text)) + '\n')


#################### Deleting class ####################


class DeleteFromCesium(CesiumCommon):
    def configDoc(self, idMsg, outbox):
        # Get current timestamp
        timeSent = int(time())

        boxType = "outbox" if outbox else "inbox"

        # Generate document to customize
        data = {}
        data['version'] = 2
        data['index'] = "message"
        data['type'] = boxType
        data['id'] = idMsg
        data['issuer'] = self.pubkey
        data['time'] = timeSent
        document = json.dumps(data)

        return self.signDoc(document)

    def sendDocument(self, document, idMsg):
        headers = {
            'Content-type': 'application/json',
        }

        # Send JSON document and get result
        try:
            result = requests.post('{0}/history/delete'.format(self.pod), headers=headers, data=document)
            if result.status_code == 404:
                raise ValueError("Message introuvable")
            elif result.status_code == 403:
                raise ValueError("Vous n'êtes pas l'auteur de ce message.")
        except Exception as e:
            sys.stderr.write(colored("Impossible de supprimer le message {0}:\n".format(idMsg), 'red') + str(e) + "\n")
            return False
        else:
            if result.status_code == 200:
                print(colored("Message {0} supprimé avec succès !".format(idMsg), "green"))
                return result
            else:
                sys.stderr.write("Erreur inconnue.")
