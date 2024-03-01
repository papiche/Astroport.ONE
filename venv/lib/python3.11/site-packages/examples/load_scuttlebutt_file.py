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


def load_scuttlebutt_file(signing_key_insance=None):
    if not signing_key_insance:
        if len(sys.argv) < 2:
            print("Usage: python load_scuttlebutt_file.py FILEPATH")
            return

        # capture filepath argument
        scuttlebutt_filepath = sys.argv[1]

    # create SigningKey instance from file
    signing_key_instance = SigningKey.from_ssb_file(scuttlebutt_filepath)

    # print pubkey
    print(f"Public key from scuttlebutt file: {signing_key_instance.pubkey}")


if __name__ == "__main__":
    load_scuttlebutt_file()
