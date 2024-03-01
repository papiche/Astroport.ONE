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
import sys

from duniterpy.key import SigningKey


def load_binary_encrypted_message(signed_message_path=None):
    if not signed_message_path:
        if len(sys.argv) < 2:
            print("Usage: python decrypt_message.py ENCRYPTED_MESSAGE_FILEPATH")
            return

        # capture encrypted message filepath argument
        signed_message_path = sys.argv[1]

    # prompt hidden user entry
    salt = getpass.getpass("Enter your passphrase (salt): ")

    # prompt hidden user entry
    password = getpass.getpass("Enter your password: ")

    # Create key object
    signing_key_instance = SigningKey.from_credentials(salt, password)

    # open encrypted message file
    with open(signed_message_path, "rb") as file_handler:
        encrypted_message = file_handler.read()

    # Decrypt the message!
    try:
        message = signing_key_instance.decrypt_seal(encrypted_message).decode("utf-8")
        print("Decrypted message:")
    except ValueError as error:
        message = str(error)

    print(message)


if __name__ == "__main__":
    load_binary_encrypted_message()
