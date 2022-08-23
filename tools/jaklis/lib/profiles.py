import sys, re, json, requests, base64
from time import time
from lib.cesiumCommon import CesiumCommon, PUBKEY_REGEX


class Profiles(CesiumCommon):
    # Configure JSON document SET to send
    def configDocSet(self, name, description, city, address, pos, socials, avatar):
        timeSent = int(time())

        data = {}
        if name: data['title'] = name
        if description: data['description'] = description
        if address: data['address'] = address
        if city: data['city'] = city
        if pos: 
            geoPoint = {}
            geoPoint['lat'] = pos[0]
            geoPoint['lon'] = pos[1]
            data['geoPoint'] = geoPoint
        if socials:
            data['socials'] = []
            data['socials'].append({})
            data['socials'][0]['type'] = "web"
            data['socials'][0]['url'] = socials
        if avatar:
            avatar = open(avatar, 'rb').read()
            avatar = base64.b64encode(avatar).decode()
            data['avatar'] = {}
            data['avatar']['_content'] = avatar
            data['avatar']['_content_type'] = "image/png"
        data['time'] = timeSent
        data['issuer'] = self.pubkey
        data['version'] = 2
        data['tags'] = []

        document =  json.dumps(data)

        return self.signDoc(document)

   # Configure JSON document GET to send
    def configDocGet(self, profile, scope='title', getAvatar=None):

        if getAvatar:
            avatar = "avatar"
        else:
            avatar = "avatar._content_type"

        data = {
                "query": {
                "bool": {
                    "should":[
                        {
                            "match":{
                                scope:{
                                    "query": profile,"boost":2
                                }
                            }
                        },{
                            "prefix": {scope: profile}
                        }
                    ]
                }
            },"highlight": {
                    "fields": {
                        "title":{},
                        "tags":{}
                    }
                },"from":0,
                "size":100,
                "_source":["title", avatar,"description","city","address","socials.url","creationTime","membersCount","type","geoPoint"],
                "indices_boost":{"user":100,"page":1,"group":0.01
                }
        }

        document =  json.dumps(data)

        return document

    # Configure JSON document SET to send
    def configDocErase(self):
        timeSent = int(time())

        data = {}
        data['time'] = timeSent
        data['id'] = self.pubkey
        data['issuer'] = self.pubkey
        data['version'] = 2
        data['index'] = "user"
        data['type'] = "profile"

        document =  json.dumps(data)

        return self.signDoc(document)

    def sendDocument(self, document, type):

        headers = {
            'Content-type': 'application/json',
        }

        # Send JSON document and get JSON result
        if type == 'set':
            reqQuery = '{0}/user/profile?pubkey={1}/_update?pubkey={1}'.format(self.pod, self.pubkey)
        elif type == 'get':
            reqQuery = '{0}/user,page,group/profile,record/_search'.format(self.pod)
        elif type == 'erase':
            reqQuery = '{0}/history/delete'.format(self.pod)

        result = requests.post(reqQuery, headers=headers, data=document)
        if result.status_code == 200:
            # print(result.text)
            return result.text
        else:
            sys.stderr.write("Echec de l'envoi du document...\n" + result.text + '\n')

    def parseJSON(self, doc):
        doc = json.loads(doc)['hits']['hits']
        if doc:
            pubkey = { "pubkey": doc[0]['_id'] }
            rest = doc[0]['_source']
            final = {**pubkey, **rest}
            return json.dumps(final, indent=2)
        else:
            return 'Profile vide'
