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
import re
from typing import List, Optional, Sequence, Type, TypeVar

from ..constants import BLOCK_HASH_REGEX, G1_CURRENCY_CODENAME, PUBKEY_REGEX

# required to type hint cls in classmethod
from ..key import SigningKey, VerifyingKey
from .block_id import BlockID
from .certification import Certification
from .document import Document, MalformedDocumentError
from .identity import Identity
from .membership import Membership
from .revocation import Revocation
from .transaction import Transaction

BlockType = TypeVar("BlockType", bound="Block")

VERSION = 12


class SignatureException(Exception):
    pass


class Block(Document):
    """
    The class Block handles Block documents.

    .. note:: A block document is specified by the following format :

        | Version: VERSION
        | Type: Block
        | Currency: CURRENCY
        | Nonce: NONCE
        | Number: BLOCK_NUMBER
        | PoWMin: NUMBER_OF_ZEROS
        | Time: GENERATED_ON
        | MedianTime: MEDIAN_DATE
        | UniversalDividend: DIVIDEND_AMOUNT
        | Issuer: ISSUER_KEY
        | PreviousHash: PREVIOUS_HASH
        | PreviousIssuer: PREVIOUS_ISSUER_KEY
        | Parameters: PARAMETERS
        | MembersCount: WOT_MEM_COUNT
        | Identities:
        | PUBLIC_KEY:SIGNATURE:TIMESTAMP:USER_ID
        | ...
        | Joiners:
        | PUBLIC_KEY:SIGNATURE:NUMBER:HASH:TIMESTAMP:USER_ID
        | ...
        | Actives:
        | PUBLIC_KEY:SIGNATURE:NUMBER:HASH:TIMESTAMP:USER_ID
        | ...
        | Leavers:
        | PUBLIC_KEY:SIGNATURE:NUMBER:HASH:TIMESTAMP:USER_ID
        | ...
        | Excluded:
        | PUBLIC_KEY
        | ...
        | Certifications:
        | PUBKEY_FROM:PUBKEY_TO:BLOCK_NUMBER:SIGNATURE
        | ...
        | Transactions:
        | COMPACT_TRANSACTION
        | ...
        | BOTTOM_SIGNATURE

    """

    re_type = re.compile("Type: (Block)\n")
    re_number = re.compile("Number: ([0-9]+)\n")
    re_powmin = re.compile("PoWMin: ([0-9]+)\n")
    re_time = re.compile("Time: ([0-9]+)\n")
    re_mediantime = re.compile("MedianTime: ([0-9]+)\n")
    re_universaldividend = re.compile("UniversalDividend: ([0-9]+)\n")
    re_unitbase = re.compile("UnitBase: ([0-9]+)\n")
    re_issuer = re.compile(f"Issuer: ({PUBKEY_REGEX})\n")
    re_issuers_frame = re.compile("IssuersFrame: ([0-9]+)\n")
    re_issuers_frame_var = re.compile("IssuersFrameVar: (0|-?[1-9]\\d{0,18})\n")
    re_different_issuers_count = re.compile("DifferentIssuersCount: ([0-9]+)\n")
    re_previoushash = re.compile(f"PreviousHash: ({BLOCK_HASH_REGEX})\n")
    re_previousissuer = re.compile(f"PreviousIssuer: ({PUBKEY_REGEX})\n")
    re_parameters = re.compile(
        "Parameters: ([0-9]+\\.[0-9]+):([0-9]+):([0-9]+):([0-9]+):([0-9]+):([0-9]+):\
([0-9]+):([0-9]+):([0-9]+):([0-9]+):([0-9]+\\.[0-9]+):([0-9]+):([0-9]+):([0-9]+):([0-9]+):([0-9]+):([0-9]+\\.[0-9]+):\
([0-9]+):([0-9]+):([0-9]+)\n"
    )
    re_memberscount = re.compile("MembersCount: ([0-9]+)\n")
    re_identities = re.compile("Identities:\n")
    re_joiners = re.compile("Joiners:\n")
    re_actives = re.compile("Actives:\n")
    re_leavers = re.compile("Leavers:\n")
    re_revoked = re.compile("Revoked:\n")
    re_excluded = re.compile("Excluded:\n")
    re_exclusion = re.compile(f"({PUBKEY_REGEX})\n")
    re_certifications = re.compile("Certifications:\n")
    re_transactions = re.compile("Transactions:\n")
    re_hash = re.compile(f"InnerHash: ({BLOCK_HASH_REGEX})\n")
    re_nonce = re.compile("Nonce: ([0-9]+)\n")

    fields_parsers = {
        **Document.fields_parsers,
        **{
            "Type": re_type,
            "Number": re_number,
            "PoWMin": re_powmin,
            "Time": re_time,
            "MedianTime": re_mediantime,
            "UD": re_universaldividend,
            "UnitBase": re_unitbase,
            "Issuer": re_issuer,
            "IssuersFrame": re_issuers_frame,
            "IssuersFrameVar": re_issuers_frame_var,
            "DifferentIssuersCount": re_different_issuers_count,
            "PreviousIssuer": re_previousissuer,
            "PreviousHash": re_previoushash,
            "Parameters": re_parameters,
            "MembersCount": re_memberscount,
            "Identities": re_identities,
            "Joiners": re_joiners,
            "Actives": re_actives,
            "Leavers": re_leavers,
            "Revoked": re_revoked,
            "Excluded": re_excluded,
            "Certifications": re_certifications,
            "Transactions": re_transactions,
            "InnerHash": re_hash,
            "Nonce": re_nonce,
        },
    }

    def __init__(
        self,
        number: int,
        powmin: int,
        time: int,
        mediantime: int,
        ud: Optional[int],
        unit_base: int,
        issuer: str,
        issuers_frame: int,
        issuers_frame_var: int,
        different_issuers_count: int,
        prev_hash: Optional[str],
        prev_issuer: Optional[str],
        parameters: Optional[Sequence[str]],
        members_count: int,
        identities: List[Identity],
        joiners: List[Membership],
        actives: List[Membership],
        leavers: List[Membership],
        revokations: List[Revocation],
        excluded: List[str],
        certifications: List[Certification],
        transactions: List[Transaction],
        inner_hash: str,
        nonce: int,
        signing_key: Optional[SigningKey] = None,
        version: int = VERSION,
        currency: str = G1_CURRENCY_CODENAME,
    ) -> None:
        """
        Constructor

        :param number: the number of the block
        :param powmin: the powmin value of this block
        :param time: the timestamp of this block
        :param mediantime: the timestamp of the median time of this block
        :param ud: the dividend amount, or None if no dividend present in this block
        :param unit_base: the unit_base of the dividend, or None if no dividend present in this block
        :param issuer: the pubkey of the issuer of the block
        :param issuers_frame:
        :param issuers_frame_var:
        :param different_issuers_count: the count of issuers
        :param prev_hash: the previous block hash
        :param prev_issuer: the previous block issuer
        :param parameters: the parameters of the currency. Should only be present in block 0.
        :param members_count: the number of members found in this block
        :param identities: the self certifications declared in this block
        :param joiners: the joiners memberships via "IN" documents
        :param actives: renewed memberships via "IN" documents
        :param leavers: the leavers memberships via "OUT" documents
        :param revokations: revokations
        :param excluded: members excluded because of missing certifications
        :param certifications: certifications documents
        :param transactions: transactions documents
        :param inner_hash: the block hash
        :param nonce: the nonce value of the block
        :param signing_key: SigningKey instance to sign the document (default=None)
        :param version: Document version (default=block.VERSION)
        :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
        """
        super().__init__(version, currency)

        documents_versions = max(  # pylint: disable=nested-min-max
            max([1] + [i.version for i in identities]),
            max([1] + [m.version for m in actives + leavers + joiners]),
            max([1] + [r.version for r in revokations]),
            max([1] + [c.version for c in certifications]),
            max([1] + [t.version for t in transactions]),
        )
        if self.version < documents_versions:
            raise MalformedDocumentError(
                f"Block version is too low: {self.version} < {documents_versions}"
            )
        self.number = number
        self.powmin = powmin
        self.time = time
        self.mediantime = mediantime
        self.ud = ud
        self.unit_base = unit_base
        self.issuer = issuer
        self.issuers_frame = issuers_frame
        self.issuers_frame_var = issuers_frame_var
        self.different_issuers_count = different_issuers_count
        self.prev_hash = prev_hash
        self.prev_issuer = prev_issuer
        self.parameters = parameters
        self.members_count = members_count
        self.identities = identities
        self.joiners = joiners
        self.actives = actives
        self.leavers = leavers
        self.revoked = revokations
        self.excluded = excluded
        self.certifications = certifications
        self.transactions = transactions
        self.inner_hash = inner_hash
        self.nonce = nonce

        if signing_key is not None:
            self.sign(signing_key)

    @property
    def block_id(self) -> BlockID:
        """
        Return Block UID

        :return:
        """
        return BlockID(self.number, self.proof_of_work())

    @classmethod
    def from_parsed_json(cls: Type[BlockType], parsed_json_block: dict) -> BlockType:
        """
        Return a Block instance from the python dict produced when parsing json

        :param parsed_json_block: Block as a Python dict

        :return:
        """
        b = parsed_json_block  # alias for readability
        version = b["version"]
        currency = b["currency"]
        arguments = {  # arguments used to create block
            "currency": b["currency"],
            "number": b["number"],
            "powmin": b["powMin"],
            "time": b["time"],
            "mediantime": b["medianTime"],
            "ud": b["dividend"],
            "unit_base": b["unitbase"],
            "issuer": b["issuer"],
            "issuers_frame": b["issuersFrame"],
            "issuers_frame_var": b["issuersFrameVar"],
            "different_issuers_count": b["issuersCount"],
            "prev_hash": b["previousHash"],
            "prev_issuer": b["previousIssuer"],
            "parameters": b["parameters"],
            "members_count": b["membersCount"],
            "identities": b["identities"],
            "joiners": b["joiners"],
            "actives": b["actives"],
            "leavers": b["leavers"],
            "revokations": b["revoked"],
            "excluded": b["excluded"],
            "certifications": b["certifications"],
            "transactions": b["transactions"],
            "inner_hash": b["inner_hash"],
            "nonce": b["nonce"],
            "version": b["version"],
        }
        # parameters: Optional[Sequence[str]]
        if arguments["parameters"]:
            arguments["parameters"] = arguments["parameters"].split(":")
        # identities: List[Identity]
        arguments["identities"] = [
            Identity.from_inline(f"{i}\n", version=version, currency=currency)
            for i in arguments["identities"]
        ]
        # joiners: List[Membership]
        arguments["joiners"] = [
            Membership.from_inline(
                f"{i}\n", version=version, currency=currency, membership_type="IN"
            )
            for i in arguments["joiners"]
        ]
        # actives: List[Membership]
        arguments["actives"] = [
            Membership.from_inline(
                f"{i}\n", version=version, currency=currency, membership_type="IN"
            )
            for i in arguments["actives"]
        ]
        # leavers: List[Membership]
        arguments["leavers"] = [
            Membership.from_inline(
                f"{i}\n", version=version, currency=currency, membership_type="OUT"
            )
            for i in arguments["leavers"]
        ]
        # revokations: List[Revocation]
        arguments["revokations"] = [
            Revocation.from_inline(f"{i}\n", version=version, currency=currency)
            for i in arguments["revokations"]
        ]
        # certifications: List[Certification]
        arguments["certifications"] = [
            Certification.from_inline(
                arguments["inner_hash"], f"{i}\n", version=version, currency=currency
            )
            for i in arguments["certifications"]
        ]
        # transactions: List[Transaction]
        arguments["transactions"] = [
            Transaction.from_bma_history(i, currency=currency)
            for i in arguments["transactions"]
        ]

        block = cls(**arguments)

        # return the block with signature
        block.signature = b["signature"]
        return block

    @classmethod
    def from_signed_raw(cls: Type[BlockType], signed_raw: str) -> BlockType:
        """
        Create Block instance from signed raw format string

        :param signed_raw: Signed raw format string

        :return:
        """
        lines = signed_raw.splitlines(True)
        n = 0

        version = int(Block.parse_field("Version", lines[n]))
        n += 1

        Block.parse_field("Type", lines[n])
        n += 1

        currency = Block.parse_field("Currency", lines[n])
        n += 1

        number = int(Block.parse_field("Number", lines[n]))
        n += 1

        powmin = int(Block.parse_field("PoWMin", lines[n]))
        n += 1

        time = int(Block.parse_field("Time", lines[n]))
        n += 1

        mediantime = int(Block.parse_field("MedianTime", lines[n]))
        n += 1

        ud_match = Block.re_universaldividend.match(lines[n])
        ud = None
        unit_base = 0
        if ud_match is not None:
            ud = int(Block.parse_field("UD", lines[n]))
            n += 1

        unit_base = int(Block.parse_field("UnitBase", lines[n]))
        n += 1

        issuer = Block.parse_field("Issuer", lines[n])
        n += 1

        issuers_frame = Block.parse_field("IssuersFrame", lines[n])
        n += 1
        issuers_frame_var = Block.parse_field("IssuersFrameVar", lines[n])
        n += 1
        different_issuers_count = Block.parse_field("DifferentIssuersCount", lines[n])
        n += 1

        prev_hash = None
        prev_issuer = None
        if number > 0:
            prev_hash = str(Block.parse_field("PreviousHash", lines[n]))
            n += 1

            prev_issuer = str(Block.parse_field("PreviousIssuer", lines[n]))
            n += 1

        parameters = None
        if number == 0:
            try:
                params_match = Block.re_parameters.match(lines[n])
                if params_match is None:
                    raise MalformedDocumentError("Parameters")
                parameters = params_match.groups()
                n += 1
            except AttributeError:
                raise MalformedDocumentError("Parameters") from AttributeError

        members_count = int(Block.parse_field("MembersCount", lines[n]))
        n += 1

        identities = []
        joiners = []
        actives = []
        leavers = []
        revoked = []
        excluded = []
        certifications = []
        transactions = []

        if Block.re_identities.match(lines[n]) is not None:
            n += 1
            while Block.re_joiners.match(lines[n]) is None:
                selfcert = Identity.from_inline(
                    lines[n], version=version, currency=currency
                )
                identities.append(selfcert)
                n += 1

        if Block.re_joiners.match(lines[n]):
            n += 1
            while Block.re_actives.match(lines[n]) is None:
                membership = Membership.from_inline(
                    lines[n], version=version, currency=currency, membership_type="IN"
                )
                joiners.append(membership)
                n += 1

        if Block.re_actives.match(lines[n]):
            n += 1
            while Block.re_leavers.match(lines[n]) is None:
                membership = Membership.from_inline(
                    lines[n], version=version, currency=currency, membership_type="IN"
                )
                actives.append(membership)
                n += 1

        if Block.re_leavers.match(lines[n]):
            n += 1
            while Block.re_revoked.match(lines[n]) is None:
                membership = Membership.from_inline(
                    lines[n], version=version, currency=currency, membership_type="OUT"
                )
                leavers.append(membership)
                n += 1

        if Block.re_revoked.match(lines[n]):
            n += 1
            while Block.re_excluded.match(lines[n]) is None:
                revokation = Revocation.from_inline(
                    lines[n], version=version, currency=currency
                )
                revoked.append(revokation)
                n += 1

        if Block.re_excluded.match(lines[n]):
            n += 1
            while Block.re_certifications.match(lines[n]) is None:
                exclusion_match = Block.re_exclusion.match(lines[n])
                if exclusion_match is not None:
                    exclusion = exclusion_match.group(1)
                    excluded.append(exclusion)
                n += 1

        if Block.re_certifications.match(lines[n]):
            n += 1
            while Block.re_transactions.match(lines[n]) is None:
                certification = Certification.from_inline(
                    prev_hash, lines[n], version=version, currency=currency
                )
                certifications.append(certification)
                n += 1

        if Block.re_transactions.match(lines[n]):
            n += 1
            while not Block.re_hash.match(lines[n]):
                tx_lines = ""
                header_data = Transaction.re_header.match(lines[n])
                if header_data is None:
                    raise MalformedDocumentError(f"Compact transaction ({lines[n]})")
                issuers_num = int(header_data.group(2))
                inputs_num = int(header_data.group(3))
                unlocks_num = int(header_data.group(4))
                outputs_num = int(header_data.group(5))
                has_comment = int(header_data.group(6))
                sup_lines = 2
                tx_max = (
                    n
                    + sup_lines
                    + issuers_num * 2
                    + inputs_num
                    + unlocks_num
                    + outputs_num
                    + has_comment
                )
                for index in range(n, tx_max):
                    tx_lines += lines[index]
                n += tx_max - n
                transaction = Transaction.from_compact(tx_lines, currency=currency)
                transactions.append(transaction)

        inner_hash = Block.parse_field("InnerHash", lines[n])
        n += 1

        nonce = int(Block.parse_field("Nonce", lines[n]))
        n += 1

        signature = Block.parse_field("Signature", lines[n])

        block = cls(
            number,
            powmin,
            time,
            mediantime,
            ud,
            unit_base,
            issuer,
            issuers_frame,
            issuers_frame_var,
            different_issuers_count,
            prev_hash,
            prev_issuer,
            parameters,
            members_count,
            identities,
            joiners,
            actives,
            leavers,
            revoked,
            excluded,
            certifications,
            transactions,
            inner_hash,
            nonce,
            version=version,
            currency=currency,
        )

        # return block with signature
        block.signature = signature
        return block

    def raw(self) -> str:
        """
        Return Block in raw format

        :return:
        """
        doc = f"Version: {self.version}\n\
Type: Block\n\
Currency: {self.currency}\n\
Number: {self.number}\n\
PoWMin: {self.powmin}\n\
Time: {self.time}\n\
MedianTime: {self.mediantime}\n"
        if self.ud:
            doc += f"UniversalDividend: {self.ud}\n"

        doc += f"UnitBase: {self.unit_base}\n"

        doc += f"Issuer: {self.issuer}\n"

        doc += f"IssuersFrame: {self.issuers_frame}\n\
IssuersFrameVar: {self.issuers_frame_var}\n\
DifferentIssuersCount: {self.different_issuers_count}\n"

        if self.number == 0 and self.parameters is not None:
            str_params = ":".join([str(p) for p in self.parameters])
            doc += f"Parameters: {str_params}\n"
        else:
            doc += f"PreviousHash: {self.prev_hash}\n\
PreviousIssuer: {self.prev_issuer}\n"

        doc += f"MembersCount: {self.members_count}\n"

        doc += "Identities:\n"
        for identity in self.identities:
            doc += f"{identity.inline()}\n"

        doc += "Joiners:\n"
        for joiner in self.joiners:
            doc += f"{joiner.inline()}\n"

        doc += "Actives:\n"
        for active in self.actives:
            doc += f"{active.inline()}\n"

        doc += "Leavers:\n"
        for leaver in self.leavers:
            doc += f"{leaver.inline()}\n"

        doc += "Revoked:\n"
        for revokation in self.revoked:
            doc += f"{revokation.inline()}\n"

        doc += "Excluded:\n"
        for exclude in self.excluded:
            doc += f"{exclude}\n"

        doc += "Certifications:\n"
        for cert in self.certifications:
            doc += f"{cert.inline()}\n"

        doc += "Transactions:\n"
        for transaction in self.transactions:
            doc += f"{transaction.compact()}"

        doc += f"InnerHash: {self.inner_hash}\n"

        doc += f"Nonce: {self.nonce}\n"

        return doc

    def proof_of_work(self) -> str:
        """
        Return Proof of Work hash for the Block

        :return:
        """
        doc_str = (
            f"InnerHash: {self.inner_hash}\nNonce: {self.nonce}\n{self.signature}\n"
        )
        return hashlib.sha256(doc_str.encode("ascii")).hexdigest().upper()

    def computed_inner_hash(self) -> str:
        """
        Return inner hash of the Block

        :return:
        """
        doc = self.raw()
        inner_doc = "\n".join(doc.split("\n")[:-3]) + "\n"
        return hashlib.sha256(inner_doc.encode("ascii")).hexdigest().upper()

    def sign(self, key: SigningKey) -> None:
        """
        Sign the current document with key

        :param key: Libnacl SigningKey instance

        :return:
        """
        string_to_sign = f"InnerHash: {self.inner_hash}\nNonce: {self.nonce}\n"
        signature = base64.b64encode(key.signature(bytes(string_to_sign, "ascii")))
        self.signature = signature.decode("ascii")

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Block):
            return NotImplemented
        return self.block_id == other.block_id

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, Block):
            return False
        return self.block_id < other.block_id

    def __gt__(self, other: object) -> bool:
        if not isinstance(other, Block):
            return False
        return self.block_id > other.block_id

    def __le__(self, other: object) -> bool:
        if not isinstance(other, Block):
            return False
        return self.block_id <= other.block_id

    def __ge__(self, other: object) -> bool:
        if not isinstance(other, Block):
            return False
        return self.block_id >= other.block_id

    def check_signature(self, pubkey: str):
        """
        Check if the signature is from pubkey

        :param pubkey: Base58 public key

        :return:
        """
        if self.signature is None:
            raise SignatureException("Signature is None, can not verify signature")

        content_to_verify = f"InnerHash: {self.inner_hash}\nNonce: {self.nonce}\n"
        verifying_key = VerifyingKey(pubkey)
        return verifying_key.check_signature(content_to_verify, self.signature)
