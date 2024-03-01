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
import hashlib
import logging
import re
from typing import Any, Dict, Optional, Pattern, Type, TypeVar

from ..constants import SIGNATURE_REGEX
from ..key import SigningKey, VerifyingKey


class SignatureException(Exception):
    pass


class MalformedDocumentError(Exception):
    """
    Malformed document exception
    """

    def __init__(self, field_name: str) -> None:
        """
        Init exception instance

        :param field_name: Name of the wrong field
        """
        super().__init__(f"Could not parse field {field_name}")


# required to type hint cls in classmethod
DocumentType = TypeVar("DocumentType", bound="Document")


class Document:
    re_version = re.compile("Version: ([0-9]+)\n")
    re_currency = re.compile("Currency: ([^\n]+)\n")
    re_signature = re.compile(f"({SIGNATURE_REGEX})\n")

    fields_parsers: Dict[str, Pattern] = {
        "Version": re_version,
        "Currency": re_currency,
        "Signature": re_signature,
    }

    def __init__(self, version: int, currency: str) -> None:
        """
        Init Document instance

        :param version: Version of the Document
        :param currency: Name of the currency
        """
        self.version = version
        self.currency = currency
        self.signature: Optional[str] = None

    def __eq__(self, other: Any) -> bool:
        """
        Check Document instances equality
        """
        if not isinstance(other, Document):
            return NotImplemented
        return (
            self.version == other.version
            and self.currency == other.currency
            and self.signature == other.signature
        )

    def __hash__(self) -> int:
        return hash(
            (
                self.version,
                self.currency,
                self.signature,
            )
        )

    @classmethod
    def parse_field(cls: Type[DocumentType], field_name: str, line: str) -> Any:
        """
        Parse a document field with regular expression and return the value

        :param field_name: Name of the field
        :param line: Line string to parse
        :return:
        """
        try:
            match = cls.fields_parsers[field_name].match(line)
            if match is None:
                raise AttributeError
            value = match.group(1)
        except AttributeError:
            raise MalformedDocumentError(field_name) from AttributeError
        return value

    def sign(self, key: SigningKey) -> None:
        """
        Sign the current document with key

        :param key: Libnacl key instance
        """
        signature = base64.b64encode(key.signature(bytes(self.raw(), "ascii")))
        logging.debug("Signature:\n%s", signature.decode("ascii"))
        self.signature = signature.decode("ascii")

    def raw(self) -> str:
        """
        Returns the raw document in string format
        """
        raise NotImplementedError("raw() is not implemented")

    def signed_raw(self) -> str:
        """
        :return:
        """
        if self.signature is None:
            raise MalformedDocumentError(
                "Signature is not defined, can not create signed raw format"
            )

        return f"{self.raw()}{self.signature}\n"

    @property
    def sha_hash(self) -> str:
        """
        Return uppercase hex sha256 hash from signed raw document

        :return:
        """
        return hashlib.sha256(self.signed_raw().encode("ascii")).hexdigest().upper()

    def check_signature(self, pubkey: str) -> bool:
        """
        Check if the signature is from pubkey

        :param pubkey: Base58 public key

        :return:
        """
        if self.signature is None:
            raise SignatureException(
                "Signature is not defined, can not check signature"
            )

        verifying_key = VerifyingKey(pubkey)

        return verifying_key.check_signature(self.raw(), self.signature)
