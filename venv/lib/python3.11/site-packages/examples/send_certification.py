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
import urllib
from typing import Optional

from duniterpy.api import bma
from duniterpy.api.client import Client
from duniterpy.documents import BlockID, Certification, Identity
from duniterpy.key import SigningKey

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the secure BASIC_MERKLED_API (BMAS)
BMAS_ENDPOINT = "BMAS g1-test.duniter.org 443"

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


def get_certification_document(
    current_block: dict, identity: Identity, signing_key: SigningKey
) -> Certification:
    """
    Create and return a Certification document

    :param current_block: Current block data
    :param identity: Identity document instance
    :param signing_key: Signing key of the certifier

    :rtype: Certification
    """
    # construct Certification Document
    return Certification(
        pubkey_from=signing_key.pubkey,
        identity=identity,
        block_id=BlockID(current_block["number"], current_block["hash"]),
        signing_key=signing_key,
        currency=current_block["currency"],
    )


def send_certification():
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

    # create key from credentials
    key = SigningKey.from_credentials(salt, password)

    # prompt entry
    pubkey_to = input("Enter pubkey to certify: ")

    # capture current block to get version and currency and block_id
    current_block = client(bma.blockchain.current)

    # create our Identity document to sign the Certification document
    identity = get_identity_document(client, current_block, pubkey_to)
    if identity is None:
        print(f"Identity not found for pubkey {pubkey_to}")
        # Close client aiohttp session
        return

    # send the Certification document to the node
    certification = get_certification_document(current_block, identity, key)

    # Here we request for the path wot/certify
    try:
        client(bma.wot.certify, certification.signed_raw())
    except urllib.error.HTTPError as e:
        print(f"Error while publishing certification: {e}")


if __name__ == "__main__":
    send_certification()
