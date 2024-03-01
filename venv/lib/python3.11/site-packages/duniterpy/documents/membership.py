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
from typing import Any, Optional, Type, TypeVar

from ..constants import (
    BLOCK_ID_REGEX,
    G1_CURRENCY_CODENAME,
    PUBKEY_REGEX,
    SIGNATURE_REGEX,
)

# required to type hint cls in classmethod
from ..key import SigningKey
from .block_id import BlockID
from .document import Document, MalformedDocumentError

MembershipType = TypeVar("MembershipType", bound="Membership")

VERSION = 10


class Membership(Document):
    """
    .. note:: A membership document is specified by the following format :

        | Version: VERSION
        | Type: Membership
        | Currency: CURRENCY_NAME
        | Issuer: ISSUER
        | Block: NUMBER-HASH
        | Membership: MEMBERSHIP_TYPE
        | UserID: USER_ID
        | CertTS: CERTIFICATION_TS

    """

    # PUBLIC_KEY:SIGNATURE:NUMBER:HASH:TIMESTAMP:USER_ID
    re_inline = re.compile(
        f"({PUBKEY_REGEX}):({SIGNATURE_REGEX}):({BLOCK_ID_REGEX}):({BLOCK_ID_REGEX}):([^\n]+)\n"
    )
    re_type = re.compile("Type: (Membership)")
    re_issuer = re.compile(f"Issuer: ({PUBKEY_REGEX})\n")
    re_block = re.compile(f"Block: ({BLOCK_ID_REGEX})\n")
    re_membership_type = re.compile("Membership: (IN|OUT)")
    re_userid = re.compile("UserID: ([^\n]+)\n")
    re_certts = re.compile(f"CertTS: ({BLOCK_ID_REGEX})\n")

    fields_parsers = {
        **Document.fields_parsers,
        **{
            "Type": re_type,
            "Issuer": re_issuer,
            "Block": re_block,
            "Membership": re_membership_type,
            "UserID": re_userid,
            "CertTS": re_certts,
        },
    }

    def __init__(
        self,
        issuer: str,
        membership_block_id: BlockID,
        uid: str,
        identity_block_id: BlockID,
        signing_key: Optional[SigningKey] = None,
        version: int = VERSION,
        currency: str = G1_CURRENCY_CODENAME,
        membership_type: str = "IN",
    ) -> None:
        """
        Create a membership document

        :param issuer: Public key of the issuer
        :param membership_block_id: BlockID of this membership
        :param uid: Unique identifier of the identity
        :param identity_block_id:  BlockID of the identity
        :param signing_key: SigningKey instance to sign the document (default=None)
        :param version: Document version (default=membership.VERSION)
        :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
        :param membership_type: "IN" or "OUT" to enter or quit the community. Default "IN"
        """
        super().__init__(version, currency)

        self.issuer = issuer
        self.membership_block_id = membership_block_id
        self.membership_type = membership_type
        self.uid = uid
        self.identity_block_id = identity_block_id

        if signing_key is not None:
            self.sign(signing_key)

    def __eq__(self, other: Any) -> bool:
        """
        Check Membership instances equality
        """
        if not isinstance(other, Membership):
            return NotImplemented
        return (
            super().__eq__(other)
            and self.issuer == other.issuer
            and self.membership_block_id == other.membership_block_id
            and self.uid == other.uid
            and self.identity_block_id == other.identity_block_id
            and self.membership_type == other.membership_type
        )

    def __hash__(self) -> int:
        return hash(
            (
                self.issuer,
                self.membership_block_id,
                self.uid,
                self.identity_block_id,
                self.membership_type,
                self.version,
                self.currency,
                self.signature,
            )
        )

    @classmethod
    def from_inline(
        cls: Type[MembershipType],
        inline: str,
        version: int = VERSION,
        currency: str = G1_CURRENCY_CODENAME,
        membership_type: str = "IN",
    ) -> MembershipType:
        """
        Return Membership instance from inline format

        :param inline: Inline string format
        :param version: Document version (default=membership.VERSION)
        :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
        :param membership_type: "IN" or "OUT" to enter or exit membership. Default "IN"
        :return:
        """
        data = Membership.re_inline.match(inline)
        if data is None:
            raise MalformedDocumentError(f"Inline membership ({inline})")
        issuer = data.group(1)
        signature = data.group(2)
        membership_block_id = BlockID.from_str(data.group(3))
        identity_block_id = BlockID.from_str(data.group(4))
        uid = data.group(5)
        membership = cls(
            issuer,
            membership_block_id,
            uid,
            identity_block_id,
            version=version,
            currency=currency,
            membership_type=membership_type,
        )

        # return membership with signature
        membership.signature = signature
        return membership

    @classmethod
    def from_signed_raw(cls: Type[MembershipType], signed_raw: str) -> MembershipType:
        """
        Return Membership instance from signed raw format

        :param signed_raw: Signed raw format string
        :return:
        """
        lines = signed_raw.splitlines(True)
        n = 0

        version = int(Membership.parse_field("Version", lines[n]))
        n += 1

        Membership.parse_field("Type", lines[n])
        n += 1

        currency = Membership.parse_field("Currency", lines[n])
        n += 1

        issuer = Membership.parse_field("Issuer", lines[n])
        n += 1

        membership_block_id = BlockID.from_str(
            Membership.parse_field("Block", lines[n])
        )
        n += 1

        membership_type = Membership.parse_field("Membership", lines[n])
        n += 1

        uid = Membership.parse_field("UserID", lines[n])
        n += 1

        identity_block_id = BlockID.from_str(Membership.parse_field("CertTS", lines[n]))
        n += 1

        signature = Membership.parse_field("Signature", lines[n])
        n += 1

        membership = cls(
            issuer,
            membership_block_id,
            uid,
            identity_block_id,
            version=version,
            currency=currency,
            membership_type=membership_type,
        )

        # return membership with signature
        membership.signature = signature
        return membership

    def raw(self) -> str:
        """
        Return signed raw format string of the Membership instance

        :return:
        """
        return f"Version: {self.version}\n\
Type: Membership\n\
Currency: {self.currency}\n\
Issuer: {self.issuer}\n\
Block: {self.membership_block_id}\n\
Membership: {self.membership_type}\n\
UserID: {self.uid}\n\
CertTS: {self.identity_block_id}\n"

    def inline(self) -> str:
        """
        Return inline string format of the Membership instance
        :return:
        """
        return f"{self.issuer}:{self.signature}:{self.membership_block_id}:{self.identity_block_id}:{self.uid}"
