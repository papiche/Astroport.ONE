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

import sys

from duniterpy.key import SigningKey


def load_credentials_file(signing_key_instance=None):
    if not signing_key_instance:
        if len(sys.argv) < 2:
            print("Usage: python load_credentials_file.py FILEPATH")
            return

        # capture filepath argument
        credentials_filepath = sys.argv[1]

    # create SigningKey instance from file
    signing_key_instance = SigningKey.from_credentials_file(credentials_filepath)

    # print pubkey
    print(f"Public key from credentials file: {signing_key_instance.pubkey}")


if __name__ == "__main__":
    load_credentials_file()
