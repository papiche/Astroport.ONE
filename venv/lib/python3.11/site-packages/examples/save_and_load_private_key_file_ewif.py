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
import os

from duniterpy.key import SigningKey

if "XDG_CONFIG_HOME" in os.environ:
    home_path = os.environ["XDG_CONFIG_HOME"]
elif "HOME" in os.environ:
    home_path = os.environ["HOME"]
elif "APPDATA" in os.environ:
    home_path = os.environ["APPDATA"]
else:
    home_path = os.path.dirname(__file__)

# CONFIG #######################################

# WARNING : Hide this file in a safe and secure place
# If one day you forget your credentials,
# you'll have to use one of your private keys instead
PRIVATE_KEY_FILE_PATH = os.path.join(home_path, ".duniter_account_ewif_v1.duniterkey")

################################################


def save_and_load_private_key_file_ewif():
    # prompt hidden user entry
    salt = getpass.getpass("Enter your passphrase (salt): ")

    # prompt hidden user entry
    password = getpass.getpass("Enter your password: ")

    # prompt public key
    pubkey = input("Enter your public key: ")

    # init signer instance
    signer = SigningKey.from_credentials(salt, password)

    # check public key
    if signer.pubkey != pubkey:
        print("Bad credentials!")
        return

    # prompt hidden user entry
    ewif_password = getpass.getpass("Enter an encryption password: ")

    # save private key in a file (EWIF v1 format)
    signer.save_ewif_file(PRIVATE_KEY_FILE_PATH, ewif_password)

    # document saved
    print(
        f"Private key for public key {signer.pubkey} saved in {PRIVATE_KEY_FILE_PATH}"
    )

    try:
        # load private keys from file
        loaded_signer = SigningKey.from_ewif_file(PRIVATE_KEY_FILE_PATH, ewif_password)

        # check public key from file
        print(
            f"Public key {loaded_signer.pubkey} loaded from file {PRIVATE_KEY_FILE_PATH}"
        )

    except OSError as error:
        print(error)
        return


if __name__ == "__main__":
    save_and_load_private_key_file_ewif()
