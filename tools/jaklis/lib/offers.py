import sys, re, json, requests, base64
from time import time
from lib.cesiumCommon import CesiumCommon, PUBKEY_REGEX

class Offers(CesiumCommon):
    # Configure JSON document SET to send
    def configDocSet(self, title, description, city, localisation, category, price: float, picture):
        timeSent = int(time())

# {"parent":"cat90","localizedNames":{"en":"Fruits &amp; Vegetables","es-ES":"Frutas y Vegetales","fr-FR":"Fruits &amp; Légumes"},"name":"Fruits &amp; Légumes","id":"cat92"}

        data = {}
        if title: data['title'] = title
        if description: data['description'] = description
        if city: data['city'] = city
        if localisation: 
            geoPoint = {}
            geoPoint['lat'] = localisation[0]
            geoPoint['lon'] = localisation[1]
            data['geoPoint'] = geoPoint
        if picture:
            picture = open(picture, 'rb').read()
            picture = base64.b64encode(picture).decode()
            data['thumbnail'] = {}
            data['thumbnail']['_content'] = picture
            data['thumbnail']['_content_type'] = "image/png"
        # if category: data['category'] = category
        # else: 
        data['category'] = {"parent":"cat24","localizedNames":{"en":"DVD / Films","es-ES":"DVDs / Cine","fr-FR":"DVD / Films"},"name":"DVD / Films","id":"cat25"}
        if price: data['price'] = float(price) * 100
        data['type'] = 'offer'
        data['time'] = timeSent
        data['creationTime'] = timeSent
        data['issuer'] = self.pubkey
        data['pubkey'] = self.pubkey
        data['version'] = 2
        data['currency'] = 'g1'
        data['unit'] = None
        data['fees'] = None
        data['feesCurrency'] = None
        if picture: data['picturesCount'] = 1
        else: data['picturesCount'] = 0
        data['stock'] = 1
        data['tags'] = []

        document =  json.dumps(data)

        return self.signDoc(document)

    # Configure JSON document SET to send
    def configDocErase(self, id):
        timeSent = int(time())

# "currency":"g1","unit":null,"fees":null,"feesCurrency":null,"picturesCount":0,"stock":0,"tags":[],"id":"AXehXeyZaml2THvBAeS5","creationTime":1613320117}
#AXehXeyZaml2THvBAeS5


        offerToDeleteBrut = self.sendDocumentGet(id, 'get')
        offerToDelete = json.loads(self.parseJSON(offerToDeleteBrut))

        title = offerToDelete['title']
        creationTime = offerToDelete['time']
        issuer = offerToDelete['issuer']
        pubkey = offerToDelete['pubkey']

        data = {}
        data['title'] = title
        data['time'] = timeSent
        data['creationTime'] = creationTime
        data['id'] = id
        data['issuer'] = issuer
        data['pubkey'] = pubkey
        data['version'] = 2
        data['type'] = "offer"
        data['currency'] = "g1"
        data['unit'] = None
        data['fees'] = None
        data['feesCurrency'] = None
        data['picturesCount'] = 0
        data['stock'] = 0
        data['tags'] = []

        document =  json.dumps(data)

        return self.signDoc(document)

    def sendDocumentGet(self, id, type):

        headers = {
            'Content-type': 'application/json',
        }

        # Send JSON document and get JSON result
        if type == 'set':
            reqQuery = '{0}/market/record'.format(self.pod)
        elif type == 'get':
            reqQuery = '{0}/market/record/{1}?_source=category,title,description,issuer,time,creationTime,location,address,city,price,unit,currency,thumbnail._content_type,thumbnail._content,picturesCount,type,stock,fees,feesCurrency,geoPoint,pubkey,freePrice'.format(self.pod, id)
        elif type == 'erase':
            reqQuery = '{0}/market/delete'.format(self.pod)
            

        result = requests.get(reqQuery, headers=headers)
        # print(result)
        if result.status_code == 200:
            # print(result.text)
            return result.text
        else:
            sys.stderr.write("Echec de l'envoi du document...\n" + result.text + '\n')


    def sendDocumentSet(self, document, type, id=None):
    
        headers = {
            'Content-type': 'application/json',
        }

        # Send JSON document and get JSON result
        if type == 'set':
            reqQuery = '{0}/market/record'.format(self.pod)
        if type == 'delete':
            reqQuery = '{0}/market/record/{1}/_update'.format(self.pod, id)

        result = requests.post(reqQuery, headers=headers, data=document)
        if result.status_code == 200:
            # print(result.text)
            return result.text
        else:
            sys.stderr.write("Echec de l'envoi du document...\n" + result.text + '\n')

    def parseJSON(self, doc):
        doc = json.loads(doc)['_source']
        if doc:
            # pubkey = { "pubkey": doc['issuer'] }
            # rest = { "description": doc['description'] }
            # final = {**pubkey, **rest}
            return json.dumps(doc, indent=2)
        else:
            return 'Profile vide'
