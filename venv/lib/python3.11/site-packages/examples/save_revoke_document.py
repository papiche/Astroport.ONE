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
from typing import Optional

from duniterpy.api import bma
from duniterpy.api.client import Client
from duniterpy.documents import Identity, Revocation
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

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the secure BASIC_MERKLED_API (BMAS)
BMAS_ENDPOINT = "BMAS g1-test.duniter.org 443"

# WARNING : Hide this file in a safe and secure place
# If one day you forget your credentials,
# you'll have to use your private key instead
REVOCATION_DOCUMENT_FILE_PATH = os.path.join(
    home_path, "duniter_account_revocation_document.txt"
)

################################################


def get_identity_document(
    client: Client, current_block: dict, pubkey: str
) -> Optional[Identity]:
    """
    Get the identity document of the pubkey

    :param client: Client to connect to the api
    :param current_block: Current block data
    :param pubkey: UID/Public key

    :rtype: Identity
    """
    # Here we request for the path wot/lookup/pubkey
    lookup_response = client(bma.wot.lookup, pubkey)

    return Identity.from_bma_lookup_response(
        current_block["currency"], pubkey, lookup_response
    )


def get_signed_raw_revocation_document(
    identity: Identity, salt: str, password: str
) -> str:
    """
    Generate account revocation document for given identity

    :param identity: Self Certification of the identity
    :param salt: Salt
    :param password: Password

    :rtype: str
    """
    key = SigningKey.from_credentials(salt, password)
    revocation = Revocation(identity, key, currency=identity.currency)

    return revocation.signed_raw()


def save_revoke_document():
    """
    Main code
    """
    # Create Client from endpoint string in Duniter format
    client = Client(BMAS_ENDPOINT)

    # Get the node summary infos to test the connection
    response = client(bma.node.summary)
    print(response)

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

    # capture current block to get currency name
    current_block = client(bma.blockchain.current)

    # create our Identity document to sign the revocation document
    identity = get_identity_document(client, current_block, pubkey)
    if identity is None:
        print(f"Identity not found for pubkey {pubkey}")
        # Close client aiohttp session
        return

    # get the revoke document
    revocation_signed_raw_document = get_signed_raw_revocation_document(
        identity, salt, password
    )

    # save revoke document in a file
    with open(REVOCATION_DOCUMENT_FILE_PATH, "w", encoding="utf-8") as fp:
        fp.write(revocation_signed_raw_document)

    # document saved
    print(f"Revocation document saved in {REVOCATION_DOCUMENT_FILE_PATH}")


if __name__ == "__main__":
    save_revoke_document()
