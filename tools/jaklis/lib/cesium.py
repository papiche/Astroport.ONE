import re, string, random, base64
from lib.cesiumCommon import CesiumCommon, PUBKEY_REGEX
from lib.messaging import ReadFromCesium, SendToCesium, DeleteFromCesium
from lib.profiles import Profiles
from lib.stars import ReadLikes, SendLikes, UnLikes
from lib.offers import Offers

class CesiumPlus(CesiumCommon):

    #################### Messaging ####################

    def read(self, nbrMsg, outbox, isJSON):
        readCesium = ReadFromCesium(self.dunikey,  self.pod)
        jsonMsg = readCesium.sendDocument(nbrMsg, outbox)
        if isJSON:
            jsonFormat = readCesium.jsonMessages(jsonMsg, nbrMsg, outbox)
            print(jsonFormat)
        else:
            readCesium.readMessages(jsonMsg, nbrMsg, outbox)

    def send(self, title, msg, recipient, outbox):
        sendCesium = SendToCesium(self.dunikey, self.pod)
        sendCesium.recipient = recipient

        # Generate pseudo-random nonce
        nonce=[]
        for _ in range(32):
            nonce.append(random.choice(string.ascii_letters + string.digits))
        sendCesium.nonce = base64.b64decode(''.join(nonce))

        finalDoc = sendCesium.configDoc(sendCesium.encryptMsg(title), sendCesium.encryptMsg(msg))       # Configure JSON document to send
        sendCesium.sendDocument(finalDoc, outbox)                                                       # Send final signed document

    def delete(self, idsMsgList, outbox):
        deleteCesium = DeleteFromCesium(self.dunikey,  self.pod)
        # deleteCesium.issuer = recipient
        for idMsg in idsMsgList:
            finalDoc = deleteCesium.configDoc(idMsg, outbox)
            deleteCesium.sendDocument(finalDoc, idMsg)

    #################### Profiles ####################

    def set(self, name=None, description=None, ville=None, adresse=None, position=None, site=None, avatar=None):
        setProfile = Profiles(self.dunikey,  self.pod)
        document = setProfile.configDocSet(name, description, ville, adresse, position, site, avatar)
        result = setProfile.sendDocument(document,'set')

        print(result)
        return result
    
    def get(self, profile=None, avatar=None):
        getProfile = Profiles(self.dunikey,  self.pod, self.noNeedDunikey)
        if not profile:
            profile = self.pubkey
        if not re.match(PUBKEY_REGEX, profile) or len(profile) > 45:
            scope = 'title'
        else:
            scope = '_id'
        
        document = getProfile.configDocGet(profile, scope, avatar)
        resultJSON = getProfile.sendDocument(document, 'get')
        result = getProfile.parseJSON(resultJSON)

        print(result)

    def erase(self):
        eraseProfile = Profiles(self.dunikey,  self.pod)
        document = eraseProfile.configDocErase()
        result = eraseProfile.sendDocument(document,'erase')

        print(result)

    #################### Likes ####################

    def readLikes(self, profile=False):
        likes = ReadLikes(self.dunikey,  self.pod, self.noNeedDunikey)
        document = likes.configDoc(profile)
        result = likes.sendDocument(document)
        result = likes.parseResult(result)

        print(result)

    def like(self, stars, profile=False):
        likes = SendLikes(self.dunikey,  self.pod)
        document = likes.configDoc(profile, stars)
        if document:
            likes.sendDocument(document, profile)

    def unLike(self, pubkey, silent=False):
        likes = UnLikes(self.dunikey,  self.pod)
        idLike = likes.checkLike(pubkey)
        if idLike:
            document = likes.configDoc(idLike)
            likes.sendDocument(document, silent)

    #################### Offer ####################

    def setOffer(self, title=None, description=None, city=None, localisation=None, category=None, price=None, picture=None):
        setOffer = Offers(self.dunikey,  self.pod)
        document = setOffer.configDocSet(title, description, city, localisation, category, price, picture)
        result = setOffer.sendDocumentSet(document,'set')

        # print(result)
        return result
    
    def getOffer(self, id, avatar=None):
        getOffer = Offers(self.dunikey,  self.pod, self.noNeedDunikey)
        
        resultJSON = getOffer.sendDocumentGet(id, 'get')
        # print(resultJSON)
        result = getOffer.parseJSON(resultJSON)

        print(result)

    def deleteOffer(self, id):
        eraseOffer = Offers(self.dunikey,  self.pod)
        document = eraseOffer.configDocErase(id)
        result = eraseOffer.sendDocumentSet(document,'delete', id)

        print(result)
