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
from typing import List, Union

from duniterpy.api import bma
from duniterpy.api.client import Client
from duniterpy.documents import BlockID, Transaction
from duniterpy.documents.transaction import (
    InputSource,
    OutputSource,
    SIGParameter,
    Unlock,
)
from duniterpy.key import SigningKey

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the secure BASIC_MERKLED_API (BMAS)
BMAS_ENDPOINT = "BMAS g1-test.duniter.org 443"

################################################


def get_transaction_document(
    current_block: dict,
    source: dict,
    from_pubkey: str,
    to_pubkey: str,
    signing_keys: Union[SigningKey, List[SigningKey]],
) -> Transaction:
    """
    Return a Transaction document

    :param current_block: Current block infos
    :param source: Source to send
    :param from_pubkey: Public key of the issuer
    :param to_pubkey: Public key of the receiver
    :param signing_key: Signing key of the issuer

    :return: Transaction
    """
    # list of inputs (sources)
    inputs = [
        InputSource(
            amount=source["amount"],
            base=source["base"],
            source=source["type"],
            origin_id=source["identifier"],
            index=source["noffset"],
        )
    ]

    # list of issuers of the inputs
    issuers = [from_pubkey]

    # list of unlocks of the inputs
    unlocks = [
        Unlock(
            # inputs[index]
            index=0,
            # unlock inputs[index] if signatures[0] is from public key of issuers[0]
            parameters=[SIGParameter(0)],
        )
    ]

    # lists of outputs
    outputs = [
        OutputSource(
            amount=source["amount"],
            base=source["base"],
            condition=f"SIG({to_pubkey})",
        )
    ]

    transaction = Transaction(
        block_id=BlockID(current_block["number"], current_block["hash"]),
        locktime=0,
        issuers=issuers,
        inputs=inputs,
        unlocks=unlocks,
        outputs=outputs,
        comment="",
        signing_keys=signing_keys,
        currency=current_block["currency"],
    )

    return transaction


def send_transaction():
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

    # create keys from credentials
    key = SigningKey.from_credentials(salt, password)
    pubkey_from = key.pubkey

    # prompt entry
    pubkey_to = input("Enter recipient pubkey: ")

    # capture current block to get version and currency and block_id
    current_block = client(bma.blockchain.current)

    # capture sources of account
    response = client(bma.tx.sources, pubkey_from)

    if len(response["sources"]) == 0:
        print(f"no sources found for account {pubkey_to}")
        return

    # get the first source
    source = response["sources"][0]

    # create the transaction document
    transaction = get_transaction_document(
        current_block, source, pubkey_from, pubkey_to, key
    )

    # send the Transaction document to the node
    try:
        client(bma.tx.process, transaction.signed_raw())
    except urllib.error.HTTPError as e:
        print(f"Error while publishing transaction: {e}")


if __name__ == "__main__":
    send_transaction()
