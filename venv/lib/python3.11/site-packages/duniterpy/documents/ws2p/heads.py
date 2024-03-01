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
from dataclasses import dataclass

from ...constants import (
    BLOCK_ID_REGEX,
    PUBKEY_REGEX,
    SIGNATURE_REGEX,
    WS2P_HEAD_REGEX,
    WS2P_PRIVATE_PREFIX_REGEX,
    WS2P_PUBLIC_PREFIX_REGEX,
    WS2PID_REGEX,
)
from ...key import VerifyingKey
from ..block_id import BlockID
from ..document import MalformedDocumentError


@dataclass
class API:
    private: str
    public: str

    re_inline = re.compile(
        f"WS2P({WS2P_PRIVATE_PREFIX_REGEX})?({WS2P_PUBLIC_PREFIX_REGEX})?"
    )

    @classmethod
    def from_inline(cls, inline: str):
        data = API.re_inline.match(inline)
        if data is None:
            raise MalformedDocumentError("WS2P API Document")
        private = "" if data.group(1) is None else data.group(1)
        public = "" if data.group(2) is None else data.group(2)
        return cls(private, public)  # type: ignore[call-arg]

    def __str__(self) -> str:
        return f"WS2P{self.private}{self.public}"


@dataclass
class Head:
    version: int

    re_inline = re.compile(WS2P_HEAD_REGEX)

    @classmethod
    def from_inline(cls, inline: str, signature: str):
        try:
            data = Head.re_inline.match(inline)
            if data is None:
                raise MalformedDocumentError("Head")
            head = data.group(0).split(":")
            version = int(head[1]) if len(head) == 2 else 0
            return cls(version)  # type: ignore[call-arg]
        except AttributeError:
            raise MalformedDocumentError("Head") from AttributeError

    def __str__(self) -> str:
        return "HEAD" if self.version == 0 else f"HEAD:{str(self.version)}"


@dataclass
class HeadV0(Head):
    signature: str
    api: API
    head: Head
    pubkey: str
    block_id: BlockID

    re_inline = re.compile(
        f"^(WS2P(?:{WS2P_PRIVATE_PREFIX_REGEX})?(?:{WS2P_PUBLIC_PREFIX_REGEX})?):\
({WS2P_HEAD_REGEX}):({PUBKEY_REGEX}):({BLOCK_ID_REGEX})(?::)?(.*)"
    )

    re_signature = re.compile(SIGNATURE_REGEX)

    @classmethod
    def from_inline(cls, inline: str, signature: str):
        try:
            data = HeadV0.re_inline.match(inline)
            if data is None:
                raise MalformedDocumentError("HeadV0")
            api = API.from_inline(data.group(1))
            head = Head.from_inline(data.group(2), "")
            pubkey = data.group(3)
            block_id = BlockID.from_str(data.group(4))
            offload = data.group(5)
            return cls(head.version, signature, api, head, pubkey, block_id), offload  # type: ignore[call-arg]
        except AttributeError:
            raise MalformedDocumentError("HeadV0") from AttributeError

    def inline(self) -> str:
        return f"{str(self.api)}:{str(self.head)}:{self.pubkey}:{str(self.block_id)}"

    def check_signature(self, pubkey: str) -> bool:
        """
        Check if Head signature is from head pubkey

        :param pubkey: Pubkey to check signature upon
        :return:
        """
        verifying_key = VerifyingKey(pubkey)

        return verifying_key.check_signature(self.inline(), self.signature)


@dataclass
class HeadV1(HeadV0):
    ws2pid: str
    software: str
    software_version: str
    pow_prefix: int

    re_inline = re.compile(
        "({ws2pid}):({software}):({software_version}):({pow_prefix})(?::)?(.*)".format(
            ws2pid=WS2PID_REGEX,
            software="[A-Za-z-_]+",
            software_version="[0-9]+[.][0-9]+[.][0-9]+[-\\w]*",
            pow_prefix="[0-9]+",
        )
    )

    @classmethod
    def from_inline(cls, inline: str, signature: str):
        try:
            v0, offload = HeadV0.from_inline(inline, signature)
            data = HeadV1.re_inline.match(offload)
            if data is None:
                raise MalformedDocumentError("HeadV1")
            ws2pid = data.group(1)
            software = data.group(2)
            software_version = data.group(3)
            pow_prefix = int(data.group(4))
            offload = data.group(5)
            return (
                cls(  # type: ignore[call-arg]
                    v0.version,
                    v0.signature,
                    v0.api,
                    v0.head,
                    v0.pubkey,
                    v0.block_id,
                    ws2pid,
                    software,
                    software_version,
                    pow_prefix,
                ),
                offload,
            )
        except AttributeError:
            raise MalformedDocumentError("HeadV1") from AttributeError

    def inline(self) -> str:
        return f"{super().inline()}:{self.ws2pid}:{self.software}:{self.software_version}:{self.pow_prefix}"


@dataclass
class HeadV2(HeadV1):
    free_member_room: int
    free_mirror_room: int

    re_inline = re.compile(
        "({free_member_room}):({free_mirror_room})(?::)?(.*)".format(
            free_member_room="[0-9]+", free_mirror_room="[0-9]+"
        )
    )

    @classmethod
    def from_inline(cls, inline: str, signature: str):
        try:
            v1, offload = HeadV1.from_inline(inline, signature)
            data = HeadV2.re_inline.match(offload)
            if data is None:
                raise MalformedDocumentError("HeadV2")
            free_member_room = int(data.group(1))
            free_mirror_room = int(data.group(2))
            return (
                cls(  # type: ignore[call-arg]
                    v1.version,
                    v1.signature,
                    v1.api,
                    v1.head,
                    v1.pubkey,
                    v1.block_id,
                    v1.ws2pid,
                    v1.software,
                    v1.software_version,
                    v1.pow_prefix,
                    free_member_room,
                    free_mirror_room,
                ),
                "",
            )
        except AttributeError:
            raise MalformedDocumentError("HeadV2") from AttributeError

    def inline(self) -> str:
        return f"{super().inline()}:{self.free_member_room}:{self.free_mirror_room}"
