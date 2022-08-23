import sys, re, json
from hashlib import sha256
from lib.natools import fmt, sign, get_privkey

PUBKEY_REGEX = "(?![OIl])[1-9A-Za-z]{42,45}"

def pp_json(json_thing, sort=True, indents=4):
    # Print beautifull JSON
    if type(json_thing) is str:
        print(json.dumps(json.loads(json_thing), sort_keys=sort, indent=indents))
    else:
        print(json.dumps(json_thing, sort_keys=sort, indent=indents))
    return None

class CesiumCommon:
    def __init__(self, dunikey, pod, noNeedDunikey=False):
        self.pod = pod
        self.noNeedDunikey = noNeedDunikey
        # Get my pubkey from my private key
        try:
            self.dunikey = dunikey
            if not dunikey:
                raise ValueError("Dunikey is empty")
        except:
            sys.stderr.write("Please fill the path to your private key (PubSec)\n")
            sys.exit(1)

        if noNeedDunikey:
            self.pubkey = self.dunikey
        else:
            self.pubkey = get_privkey(dunikey, "pubsec").pubkey

        if not re.match(PUBKEY_REGEX, self.pubkey) or len(self.pubkey) > 45:
            sys.stderr.write("La clé publique n'est pas au bon format.\n")
            sys.exit(1)

    def signDoc(self, document):
        # Generate hash of document
        hashDoc = sha256(document.encode()).hexdigest().upper()

        # Generate signature of document
        signature = fmt["64"](sign(hashDoc.encode(), get_privkey(self.dunikey, "pubsec"))[:-len(hashDoc.encode())]).decode()

        # Build final document
        data = {}
        data['hash'] = hashDoc
        data['signature'] = signature
        signJSON = json.dumps(data)
        finalJSON = {**json.loads(signJSON), **json.loads(document)}

        return json.dumps(finalJSON)
