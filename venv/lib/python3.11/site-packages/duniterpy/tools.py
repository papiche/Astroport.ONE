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

import uuid
from typing import Union

from libnacl.encode import hex_decode, hex_encode


def ensure_bytes(data: Union[str, bytes]) -> bytes:
    """
    Convert data in bytes if data is a string

    :param data: Data
    :rtype bytes:
    """
    if isinstance(data, str):
        return bytes(data, "utf-8")

    return data


def ensure_str(data: Union[str, bytes]) -> str:
    """
    Convert data in str if data are bytes

    :param data: Data
    :rtype str:
    """
    if isinstance(data, bytes):
        return str(data, "utf-8")

    return data


def xor_bytes(b1: bytes, b2: bytes) -> bytearray:
    """
    Apply XOR operation on two bytes arguments

    :param b1: First bytes argument
    :param b2: Second bytes argument
    :rtype bytearray:
    """
    result = bytearray()
    for i1, i2 in zip(b1, b2):
        result.append(i1 ^ i2)
    return result


def convert_seedhex_to_seed(seedhex: str) -> bytes:
    """
    Convert seedhex to seed

    :param seedhex: seed coded in hexadecimal base
    :rtype bytes:
    """
    return bytes(hex_decode(seedhex.encode("utf-8")))


def convert_seed_to_seedhex(seed: bytes) -> str:
    """
    Convert seed to seedhex

    :param seed: seed
    :rtype str:
    """
    return hex_encode(seed).decode("utf-8")


def get_ws2p_challenge() -> str:
    """
    Return two uuid v4 concatened as ws2p challenge

    :rtype str:
    """
    return str(uuid.uuid4()) + str(uuid.uuid4())
