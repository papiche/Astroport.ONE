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

from duniterpy.key import AsciiArmor

# CONFIG #######################################

CLEARTEXT_AA_MESSAGE_PATH = "/tmp/duniter_cleartext_aa_message.txt"

################################################


def load_cleartext_ascii_armor_message():
    # Ask public key of the issuer
    pubkeyBase58 = input("Enter public key of the message issuer: ")

    # Load cleartext ascii armor message from a file
    with open(CLEARTEXT_AA_MESSAGE_PATH, encoding="utf-8") as file_handler:
        ascii_armor_block = file_handler.read()

    print(f"Cleartext Ascii Armor Message loaded from file {CLEARTEXT_AA_MESSAGE_PATH}")

    result = AsciiArmor.parse(ascii_armor_block, None, [pubkeyBase58])
    print(
        "------------- MESSAGE ------------\n"
        + result["message"]["content"]
        + "----------------------------------"
    )
    print(result)


if __name__ == "__main__":
    load_cleartext_ascii_armor_message()
