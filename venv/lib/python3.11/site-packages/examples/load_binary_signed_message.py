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

from duniterpy.key import VerifyingKey


def load_binary_signed_message(signed_message_path=None):
    if not signed_message_path:
        if len(sys.argv) < 2:
            print("Usage: python verify_signed_message.py SIGNED_MESSAGE_FILEPATH")
            return

        # capture signed message filepath argument
        signed_message_path = sys.argv[1]

    # ask public key of the signer
    pubkeyBase58 = input("Enter public key of the message issuer: ")

    # open signed message file
    with open(signed_message_path, "rb") as file_handler:
        signed_message = file_handler.read()

    # Verify the message!
    verifier = VerifyingKey(pubkeyBase58)
    try:
        message = verifier.get_verified_data(signed_message).decode("utf-8")
        print("Signature valid for this message:")
    except ValueError as error:
        message = str(error)

    print(message)


if __name__ == "__main__":
    load_binary_signed_message()
