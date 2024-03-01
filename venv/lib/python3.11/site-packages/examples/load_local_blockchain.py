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

from duniterpy.helpers.blockchain import load


def load_local_blockchain():
    """
    this example lets you load a local copy of
    duniter blockchain into duniterpy objects
    by default, it looks in:
    $HOME/.config/duniter/duniter_default/g1/
    """
    # gets blockchain iterator
    bc = load()

    # gets block
    b = next(bc)

    # should return 0
    # you can access all properties of this block through it's duniterpy objects attributes
    print(f"first block number is: {b.number}")

    # should return 1
    print(f"second block number is: {next(bc).number}")

    # should return 2
    print(f"third block number is: {next(bc).number}")

    # (and so on)


if __name__ == "__main__":
    load_local_blockchain()
