# Copyright  2014-2024 Vincent Texier <vit@free.fr>
#
# DuniterPy is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# DuniterPy is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import json
from typing import Optional

from duniterpy.constants import G1_CURRENCY_CODENAME
from duniterpy.documents import Document
from duniterpy.key import SigningKey
from duniterpy.tools import get_ws2p_challenge


class HandshakeMessage(Document):
    version = 2
    auth = ""

    def __init__(
        self,
        pubkey: str,
        challenge: Optional[str] = None,
        signature: Optional[str] = None,
        currency: str = G1_CURRENCY_CODENAME,
    ) -> None:
        """
        Init Connect message document

        :param pubkey: Public key of the node
        :param challenge: [Optional, default=None] Big random string, typically an uuid
        :param signature: [Optional, default=None] Base64 encoded signature of raw formated document
        :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
        """
        super().__init__(self.version, currency)

        self.pubkey = pubkey

        if challenge is None:
            # create challenge
            self.challenge = get_ws2p_challenge()
        else:
            self.challenge = challenge

        if signature is not None:
            self.signature = signature
            self.check_signature(pubkey)

    def raw(self):
        """
        Return the document in raw format

        :return:
        """
        return f"WS2P:{self.auth}:{self.currency}:{self.pubkey}:{self.challenge}"

    def get_signed_json(self, signing_key: SigningKey) -> str:
        """
        Return the signed message in json format

        :param signing_key: Signing key instance

        :return:
        """
        self.sign(signing_key)
        data = {
            "auth": self.auth,
            "pub": self.pubkey,
            "challenge": self.challenge,
            "sig": self.signature,
        }
        return json.dumps(data)

    def __str__(self) -> str:
        return self.raw()


class Connect(HandshakeMessage):
    auth = "CONNECT"


class Ack(HandshakeMessage):
    auth = "ACK"

    def __init__(
        self,
        pubkey: str,
        challenge: str,
        signature: Optional[str] = None,
        currency: str = G1_CURRENCY_CODENAME,
    ) -> None:
        """
        Init Connect message document

        :param pubkey: Public key of the node
        :param challenge: Big random string, typically an uuid
        :param signature: [Optional, default=None] Base64 encoded signature of raw formated document
        :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
        """
        super().__init__(pubkey, challenge, signature, currency)

    def get_signed_json(self, signing_key: SigningKey) -> str:
        """
        Return the signed message in json format

        :param signing_key: Signing key instance

        :return:
        """
        self.sign(signing_key)
        data = {"auth": self.auth, "pub": self.pubkey, "sig": self.signature}
        return json.dumps(data)


class Ok(HandshakeMessage):
    auth = "OK"

    def __init__(
        self,
        pubkey: str,
        challenge: str,
        signature: Optional[str] = None,
        currency: str = G1_CURRENCY_CODENAME,
    ) -> None:
        """
        Init Connect message document

        :param pubkey: Public key of the node
        :param challenge: Big random string, typically an uuid
        :param signature: [Optional, default=None] Base64 encoded signature of raw formated document
        :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
        """
        super().__init__(pubkey, challenge, signature, currency)

    def get_signed_json(self, signing_key: SigningKey) -> str:
        """
        Return the signed message in json format

        :param signing_key: Signing key instance

        :return:
        """
        self.sign(signing_key)
        data = {"auth": self.auth, "sig": self.signature}
        return json.dumps(data)


class DocumentMessage:
    PEER_TYPE_ID = 0
    TRANSACTION_TYPE_ID = 1
    MEMBERSHIP_TYPE_ID = 2
    CERTIFICATION_TYPE_ID = 3
    IDENTITY_TYPE_ID = 4
    BLOCK_TYPE_ID = 5

    DOCUMENT_TYPE_NAMES = {
        0: "peer",
        1: "transaction",
        2: "membership",
        3: "certification",
        4: "identity",
        5: "block",
    }

    def get_json(self, document_type_id: int, document: str) -> str:
        """
        Return the document message in json format

        :param document_type_id: Id of the document type, use class properties
        :param document: Raw or Inline Document to send
        """
        data = {
            "body": {
                "name": document_type_id,
                self.DOCUMENT_TYPE_NAMES[document_type_id]: document,
            }
        }
        return json.dumps(data)
