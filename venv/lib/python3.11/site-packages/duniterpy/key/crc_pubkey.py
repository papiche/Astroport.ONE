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

import hashlib
import re
from typing import Type, TypeVar

import base58

from duniterpy.constants import PUBKEY_REGEX
from duniterpy.tools import ensure_str

# required to type hint cls in classmethod
CRCPubkeyType = TypeVar("CRCPubkeyType", bound="CRCPubkey")


class CRCPubkeyException(Exception):
    pass


class CRCPubkey:
    """
    Class to implement a crc on a pubkey
    """

    re_crc_pubkey = re.compile(f"({PUBKEY_REGEX}):([A-Za-z0-9]{{3}})")

    def __init__(self, pubkey: str, crc: str) -> None:
        """
        Creates a pubkey with a crc

        :param pubkey: Public key
        :param crc: CRC
        """
        self.pubkey = pubkey
        self.crc = crc

    @classmethod
    def from_str(cls: Type[CRCPubkeyType], crc_pubkey: str) -> CRCPubkeyType:
        """
        Return CRCPubkey instance from CRC public key string

        :param crc_pubkey: CRC public key
        :return:
        """
        data = CRCPubkey.re_crc_pubkey.match(crc_pubkey)
        if data is None:
            raise CRCPubkeyException(f"Could not parse CRC public key {crc_pubkey}")
        pubkey = data.group(1)
        crc = data.group(2)
        return cls(pubkey, crc)

    @classmethod
    def from_pubkey(cls: Type[CRCPubkeyType], pubkey: str) -> CRCPubkeyType:
        """
        Return CRCPubkey instance from public key string

        :param pubkey: Public key
        :return:
        """
        hash_root = hashlib.sha256()
        hash_root.update(base58.b58decode(pubkey))
        hash_squared = hashlib.sha256()
        hash_squared.update(hash_root.digest())
        b58_checksum = ensure_str(base58.b58encode(hash_squared.digest()))

        crc = b58_checksum[:3]
        return cls(pubkey, crc)

    def is_valid(self) -> bool:
        """
        Return True if CRC is valid
        :return:
        """
        return CRCPubkey.from_pubkey(self.pubkey).crc == self.crc

    def __str__(self) -> str:
        """
        Return string representation of instance
        :return:
        """
        return f"{self.pubkey}:{self.crc}"
