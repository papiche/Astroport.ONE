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

from duniterpy.api import bma
from duniterpy.api.client import Client
from duniterpy.documents import BlockID, Identity
from duniterpy.key import SigningKey

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the secure BASIC_MERKLED_API (BMAS)
BMAS_ENDPOINT = "BMAS g1-test.duniter.org 443"


################################################


def get_identity_document(
    current_block: dict,
    uid: str,
    key: SigningKey,
) -> Identity:
    """
    Get an Identity document

    :param current_block: Current block data
    :param uid: Unique IDentifier
    :param key: cryptographic key to sign documents

    :rtype: Identity
    """

    # get current BlockID
    block_id = BlockID(current_block["number"], current_block["hash"])

    # create identity document
    identity = Identity(
        pubkey=key.pubkey,
        uid=uid,
        block_id=block_id,
        signing_key=key,
        currency=current_block["currency"],
    )

    return identity


def send_identity():
    """
    Main code
    """
    # Create Client from endpoint string in Duniter format
    client = Client(BMAS_ENDPOINT)

    # Get the node summary infos to test the connection
    response = client(bma.node.summary)
    print(response)

    # capture current block to get version and currency and block_id
    current_block = client(bma.blockchain.current)

    # prompt entry
    uid = input("Enter your Unique IDentifier (pseudonym): ")

    # prompt hidden user entry
    salt = getpass.getpass("Enter your passphrase (salt): ")

    # prompt hidden user entry
    password = getpass.getpass("Enter your password: ")

    # create keys from credentials
    key = SigningKey.from_credentials(salt, password)

    # create our signed identity document
    identity = get_identity_document(current_block, uid, key)

    # send the identity signed raw document to the node
    try:
        client(bma.wot.add, identity.signed_raw())
    except urllib.error.HTTPError as e:
        print(f"Error while publishing identity: {e}")


if __name__ == "__main__":
    send_identity()
