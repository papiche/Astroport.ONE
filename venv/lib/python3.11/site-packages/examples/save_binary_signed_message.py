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

import libnacl.sign

from duniterpy.key import SigningKey

# CONFIG #######################################

SIGNED_MESSAGE_FILENAME = "/tmp/duniter_signed_message.bin"

################################################


def save_binary_signed_message():
    # prompt hidden user entry
    salt = getpass.getpass("Enter your passphrase (salt): ")

    # prompt hidden user entry
    password = getpass.getpass("Enter your password: ")

    # Create key object
    key = SigningKey.from_credentials(salt, password)

    # Display your public key
    print(f"Public key for your credentials: {key.pubkey}")

    message = input("Enter your message: ")

    # Sign the message, the signed string is the message itself plus the
    # signature
    signed_message = key.sign(bytes(message, "utf-8"))

    # To create a verifier pass in the verify key:
    veri = libnacl.sign.Verifier(key.hex_vk())
    # Verify the message!
    verified = veri.verify(signed_message)
    print(f"Message verified: {verified}")

    # save signed message in a file
    with open(SIGNED_MESSAGE_FILENAME, "wb") as file_handler:
        file_handler.write(signed_message)

    print(f"Signed message saved in file {SIGNED_MESSAGE_FILENAME}")


if __name__ == "__main__":
    save_binary_signed_message()
