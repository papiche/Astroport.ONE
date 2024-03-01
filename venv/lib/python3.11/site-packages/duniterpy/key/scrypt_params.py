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

from .constants import SCRYPT_PARAMS


class ScryptParams:
    """
    Class to simplify handling of scrypt parameters
    """

    def __init__(
        self,
        n: int = SCRYPT_PARAMS["N"],
        r: int = SCRYPT_PARAMS["r"],
        p: int = SCRYPT_PARAMS["p"],
        seed_length: int = SCRYPT_PARAMS["seed_length"],
    ) -> None:
        """
        Init a ScryptParams instance with crypto parameters

        :param n: scrypt param N, default see constant SCRYPT_PARAMS
        :param r: scrypt param r, default see constant SCRYPT_PARAMS
        :param p: scrypt param p, default see constant SCRYPT_PARAMS
        :param seed_length: scrypt param seed_length, default see constant SCRYPT_PARAMS
        """
        self.N = n
        self.r = r
        self.p = p
        self.seed_length = seed_length
