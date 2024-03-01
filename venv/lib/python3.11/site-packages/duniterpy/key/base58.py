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

from typing import Union

import base58

from ..tools import ensure_bytes, ensure_str


class Base58Encoder:
    @staticmethod
    def encode(data: Union[str, bytes]) -> str:
        """
        Return Base58 string from data

        :param data: Bytes or string data
        """
        return ensure_str(base58.b58encode(ensure_bytes(data)))

    @staticmethod
    def decode(data: str) -> bytes:
        """
        Decode Base58 string data and return bytes

        :param data: Base58 string
        """
        return base58.b58decode(data)
