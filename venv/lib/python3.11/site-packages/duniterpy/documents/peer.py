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

import re
from typing import List, Optional, Type, TypeVar

from duniterpy.api.endpoint import Endpoint, endpoint

from ..constants import BLOCK_HASH_REGEX, G1_CURRENCY_CODENAME, PUBKEY_REGEX

# required to type hint cls in classmethod
from ..key import SigningKey
from .block_id import BlockID
from .document import Document, MalformedDocumentError

PeerType = TypeVar("PeerType", bound="Peer")

VERSION = 10


class Peer(Document):
    """
    .. note:: A peer document is specified by the following format :

        | Version: VERSION
        | Type: Peer
        | Currency: CURRENCY_NAME
        | PublicKey: NODE_PUBLICKEY
        | Block: BLOCK
        | Endpoints:
        | END_POINT_1
        | END_POINT_2
        | END_POINT_3
        | [...]

    """

    re_type = re.compile("Type: (Peer)")
    re_pubkey = re.compile(f"PublicKey: ({PUBKEY_REGEX})\n")
    re_block = re.compile(f"Block: ([0-9]+-{BLOCK_HASH_REGEX})\n")
    re_endpoints = re.compile("(Endpoints:)\n")

    fields_parsers = {
        **Document.fields_parsers,
        **{
            "Type": re_type,
            "Pubkey": re_pubkey,
            "Block": re_block,
            "Endpoints": re_endpoints,
        },
    }

    def __init__(
        self,
        pubkey: str,
        block_id: BlockID,
        endpoints: List[Endpoint],
        signing_key: Optional[SigningKey] = None,
        version: int = VERSION,
        currency: str = G1_CURRENCY_CODENAME,
    ) -> None:
        """
        Init Peer instance

        :param pubkey: Public key of the issuer
        :param block_id: BlockID instance
        :param endpoints: List of endpoints string
        :param signing_key: SigningKey instance to sign the document (default=None)
        :param version: Document version (default=peer.VERSION)
        :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
        """
        super().__init__(version, currency)

        self.pubkey = pubkey
        self.block_id = block_id
        self.endpoints: List[Endpoint] = endpoints

        if signing_key is not None:
            self.sign(signing_key)

    @classmethod
    def from_signed_raw(cls: Type[PeerType], raw: str) -> PeerType:
        """
        Return a Peer instance from a signed raw format string

        :param raw: Signed raw format string
        :return:
        """
        lines = raw.splitlines(True)
        n = 0

        version = int(Peer.parse_field("Version", lines[n]))
        n += 1

        Peer.parse_field("Type", lines[n])
        n += 1

        currency = Peer.parse_field("Currency", lines[n])
        n += 1

        pubkey = Peer.parse_field("Pubkey", lines[n])
        n += 1

        block_id = BlockID.from_str(Peer.parse_field("Block", lines[n]))
        n += 1

        Peer.parse_field("Endpoints", lines[n])
        n += 1

        endpoints = []
        while not Peer.re_signature.match(lines[n]):
            endpoints.append(endpoint(lines[n]))
            n += 1

        data = Peer.re_signature.match(lines[n])
        if data is None:
            raise MalformedDocumentError("Peer")
        signature = data.group(1)

        peer = cls(pubkey, block_id, endpoints, version=version, currency=currency)

        # return peer with signature
        peer.signature = signature
        return peer

    def raw(self) -> str:
        """
        Return a raw format string of the Peer document

        :return:
        """
        doc = f"Version: {self.version}\n\
Type: Peer\n\
Currency: {self.currency}\n\
PublicKey: {self.pubkey}\n\
Block: {self.block_id}\n\
Endpoints:\n"

        for _endpoint in self.endpoints:
            doc += f"{_endpoint.inline()}\n"

        return doc

    @classmethod
    def from_bma(cls: Type[PeerType], data: dict) -> PeerType:
        # get Peer Document from bma dict
        version = data["version"]
        currency = data["currency"]
        pubkey = data["pubkey"]
        block_id = BlockID.from_str(data["block"])

        endpoints = []
        for _endpoint in data["endpoints"]:
            endpoints.append(endpoint(_endpoint))

        signature = str(Peer.re_signature.match(data["signature"]))

        peer = cls(pubkey, block_id, endpoints, version=version, currency=currency)

        # return peer with signature
        peer.signature = signature
        return peer
