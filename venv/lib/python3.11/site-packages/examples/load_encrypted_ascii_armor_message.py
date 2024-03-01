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

import getpass

from duniterpy.key import AsciiArmor, SigningKey

# CONFIG #######################################

ENCRYPTED_AA_MESSAGE_PATH = "/tmp/duniter_aa_encrypted_message.txt"

################################################


def load_encrypted_ascii_armor_message():
    # Ask public key of the recipient
    pubkeyBase58 = input("Enter public key of the message issuer: ")

    # prompt hidden user entry
    salt = getpass.getpass("Enter your passphrase (salt): ")

    # prompt hidden user entry
    password = getpass.getpass("Enter your password: ")

    # init SigningKey instance
    signing_key = SigningKey.from_credentials(salt, password)

    # Load ascii armor encrypted message from a file
    with open(ENCRYPTED_AA_MESSAGE_PATH, encoding="utf-8") as file_handler:
        ascii_armor_block = file_handler.read()

    print(f"Encrypted Ascii Armor Message loaded from file {ENCRYPTED_AA_MESSAGE_PATH}")
    print(AsciiArmor.parse(ascii_armor_block, signing_key, [pubkeyBase58]))


if __name__ == "__main__":
    load_encrypted_ascii_armor_message()
