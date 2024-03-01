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
from typing import Type, TypeVar, Union

from ..constants import BLOCK_HASH_REGEX, BLOCK_NUMBER_REGEX, EMPTY_HASH
from .document import MalformedDocumentError

# required to type hint cls in classmethod
BlockIDType = TypeVar("BlockIDType", bound="BlockID")


class BlockID:
    """
    A simple block id
    """

    re_block_id = re.compile(f"({BLOCK_NUMBER_REGEX})-({BLOCK_HASH_REGEX})")
    re_hash = re.compile(f"({BLOCK_HASH_REGEX})")

    def __init__(self, number: int, sha_hash: str) -> None:
        assert type(number) is int
        assert BlockID.re_hash.match(sha_hash) is not None
        self.number = number
        self.sha_hash = sha_hash

    @classmethod
    def empty(cls: Type[BlockIDType]) -> BlockIDType:
        return cls(0, EMPTY_HASH)

    @classmethod
    def from_str(cls: Type[BlockIDType], blockid: str) -> BlockIDType:
        """
        :param blockid: The block id
        """
        data = BlockID.re_block_id.match(blockid)
        if data is None:
            raise MalformedDocumentError("BlockID")
        try:
            number = int(data.group(1))
        except AttributeError:
            raise MalformedDocumentError("BlockID") from AttributeError

        try:
            sha_hash = data.group(2)
        except AttributeError:
            raise MalformedDocumentError("BlockHash") from AttributeError

        return cls(number, sha_hash)

    def __str__(self) -> str:
        return f"{self.number}-{self.sha_hash}"

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, BlockID):
            return NotImplemented
        return self.number == other.number and self.sha_hash == other.sha_hash

    def __lt__(self, other: object) -> bool:
        if not isinstance(other, BlockID):
            return NotImplemented
        return self.number < other.number

    def __gt__(self, other: object) -> bool:
        if not isinstance(other, BlockID):
            return NotImplemented
        return self.number > other.number

    def __le__(self, other: object) -> bool:
        if not isinstance(other, BlockID):
            return NotImplemented
        return self.number <= other.number

    def __ge__(self, other: object) -> bool:
        if not isinstance(other, BlockID):
            return NotImplemented
        return self.number >= other.number

    def __hash__(self) -> int:
        return hash((self.number, self.sha_hash))

    def __bool__(self) -> bool:
        return self != BlockID.empty()


def get_block_id(value: Union[str, BlockID, None]) -> BlockID:
    """
    Convert value to BlockID instance

    :param value: Value to convert
    :return:
    """
    if isinstance(value, BlockID):
        result = value
    elif isinstance(value, str):
        result = BlockID.from_str(value)
    elif value is None:
        result = BlockID.empty()
    else:
        raise TypeError(f"Cannot convert {type(value)} to BlockID")

    return result
