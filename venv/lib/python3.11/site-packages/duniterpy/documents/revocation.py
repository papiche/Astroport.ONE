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
from typing import Any, Optional, Type, TypeVar, Union

from ..constants import (
    BLOCK_ID_REGEX,
    G1_CURRENCY_CODENAME,
    PUBKEY_REGEX,
    SIGNATURE_REGEX,
)

# required to type hint cls in classmethod
from ..key import SigningKey
from .document import Document, MalformedDocumentError
from .identity import Identity

RevocationType = TypeVar("RevocationType", bound="Revocation")

VERSION = 10


class Revocation(Document):
    """
    A document describing a self-revocation.
    """

    re_inline = re.compile(f"({PUBKEY_REGEX}):({SIGNATURE_REGEX})\n")
    re_type = re.compile("Type: (Revocation)")
    re_issuer = re.compile(f"Issuer: ({PUBKEY_REGEX})\n")
    re_uniqueid = re.compile("IdtyUniqueID: ([^\n]+)\n")
    re_block_id = re.compile(f"IdtyTimestamp: ({BLOCK_ID_REGEX})\n")
    re_idtysignature = re.compile(f"IdtySignature: ({SIGNATURE_REGEX})\n")

    fields_parsers = {
        **Document.fields_parsers,
        **{
            "Type": re_type,
            "Issuer": re_issuer,
            "IdtyUniqueID": re_uniqueid,
            "IdtyTimestamp": re_block_id,
            "IdtySignature": re_idtysignature,
        },
    }

    def __init__(
        self,
        identity: Union[Identity, str],
        signing_key: Optional[SigningKey] = None,
        version: int = VERSION,
        currency: str = G1_CURRENCY_CODENAME,
    ) -> None:
        """
        Init Revocation instance

        :param identity: Identity instance or identity pubkey
        :param signing_key: SigningKey instance to sign the document (default=None)
        :param version: Document version (default=revocation.VERSION)
        :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
        """
        super().__init__(version, currency)

        self.identity = identity if isinstance(identity, Identity) else None
        self.pubkey = identity.pubkey if isinstance(identity, Identity) else identity

        if signing_key is not None:
            self.sign(signing_key)

    def __eq__(self, other: Any) -> bool:
        """
        Check Revocation instances equality
        """
        if not isinstance(other, Revocation):
            return NotImplemented
        return super().__eq__(other) and self.identity == other.identity

    def __hash__(self) -> int:
        return hash(
            (
                self.identity,
                self.version,
                self.currency,
                self.signature,
            )
        )

    @classmethod
    def from_inline(
        cls: Type[RevocationType],
        inline: str,
        version: int = VERSION,
        currency: str = G1_CURRENCY_CODENAME,
    ) -> RevocationType:
        """
        Return Revocation document instance from inline string

        Only self.pubkey is populated.
        You must populate self.identity with an Identity instance to use raw/sign/signed_raw methods

        :param inline: Inline document
        :param version: Document version (default=revocation.VERSION)
        :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
        :return:
        """
        cert_data = Revocation.re_inline.match(inline)
        if cert_data is None:
            raise MalformedDocumentError("Revokation")
        pubkey = cert_data.group(1)
        signature = cert_data.group(2)
        revocation = cls(pubkey, version=version, currency=currency)

        # return revocation with signature
        revocation.signature = signature
        return revocation

    @classmethod
    def from_signed_raw(cls: Type[RevocationType], signed_raw: str) -> RevocationType:
        """
        Return Revocation document instance from a signed raw string

        :param signed_raw: raw document file in duniter format
        :return:
        """
        lines = signed_raw.splitlines(True)
        n = 0

        version = int(Revocation.parse_field("Version", lines[n]))
        n += 1

        Revocation.parse_field("Type", lines[n])
        n += 1

        currency = Revocation.parse_field("Currency", lines[n])

        n += 5
        signature = Revocation.parse_field("Signature", lines[n])

        identity = Identity.from_revocation_raw(signed_raw)

        revocation = cls(identity, version=version, currency=currency)

        # return revocation with signature
        revocation.signature = signature
        return revocation

    @staticmethod
    def extract_self_cert(signed_raw: str) -> Identity:
        """
        Return self-certified Identity instance from the signed raw Revocation document

        :param signed_raw: Signed raw revocation document string
        :return:
        """
        return Identity.from_revocation_raw(signed_raw)

    def inline(self) -> str:
        """
        Return inline document string

        :return:
        """
        return f"{self.pubkey}:{self.signature}"

    def raw(self) -> str:
        """
        Return Revocation raw document string

        :return:
        """
        if not isinstance(self.identity, Identity):
            raise MalformedDocumentError(
                "Can not return full revocation document created from inline"
            )

        return f"Version: {self.version}\n\
Type: Revocation\n\
Currency: {self.currency}\n\
Issuer: {self.identity.pubkey}\n\
IdtyUniqueID: {self.identity.uid}\n\
IdtyTimestamp: {self.identity.block_id}\n\
IdtySignature: {self.identity.signature}\n"

    def sign(self, key: SigningKey) -> None:
        """
        Sign the current document

        :param key: Libnacl key instance
        :return:
        """
        if not isinstance(self.identity, Identity):
            raise MalformedDocumentError(
                "Can not return full revocation document created from inline"
            )
        super().sign(key)

    def signed_raw(self) -> str:
        """
        Return Revocation signed raw document string

        :return:
        """
        if not isinstance(self.identity, Identity):
            raise MalformedDocumentError(
                "Identity is not defined or properly defined. Can not create raw format"
            )
        if self.signature is None:
            raise MalformedDocumentError("Signature is None, can not create raw format")

        return f"{self.raw()}{self.signature}\n"
