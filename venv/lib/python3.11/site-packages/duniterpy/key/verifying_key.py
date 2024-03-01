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

import base64

import libnacl.encode
import libnacl.sign

from .base58 import Base58Encoder


class VerifyingKey(libnacl.sign.Verifier):
    """
    Class to verify documents
    """

    def __init__(self, pubkey: str) -> None:
        """
        Creates a Verify class from base58 pubkey
        :param pubkey:
        """
        key = libnacl.encode.hex_encode(Base58Encoder.decode(pubkey))
        super().__init__(key)

    def get_verified_data(self, data: bytes) -> bytes:
        """
        Check specified signed data signature and return data without signature

        Raise exception if signature is not valid

        :param data: Data + signature
        :return:
        """
        return self.verify(data)

    def check_signature(self, data: str, signature: str) -> bool:
        """
        Check if data signature is valid and from self.pubkey

        :param data: Data to check
        :param signature: Signature to check
        :return:
        """
        prepended = base64.b64decode(signature) + bytes(data, "ascii")
        try:
            self.verify(prepended)
        except ValueError:
            return False

        return True
