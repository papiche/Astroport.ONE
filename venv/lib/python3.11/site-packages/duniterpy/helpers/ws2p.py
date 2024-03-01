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

import logging
from typing import Union

import jsonschema

from duniterpy.api import bma, ws2p
from duniterpy.api.client import Client, WSConnection
from duniterpy.api.endpoint import BMAEndpoint, SecuredBMAEndpoint, WS2PEndpoint
from duniterpy.constants import G1_CURRENCY_CODENAME
from duniterpy.documents.ws2p.messages import Ack, Connect, Ok
from duniterpy.key import SigningKey


def handshake(
    ws: WSConnection, signing_key: SigningKey, currency: str = G1_CURRENCY_CODENAME
):
    """
    Perform ws2p handshake on the web socket connection using the signing_key instance

    :param ws: Web socket connection instance
    :param signing_key: SigningKey instance
    :param currency: Currency codename (default=constants.CURRENCY_CODENAME_G1)
    :return:
    """
    # START HANDSHAKE #######################################################
    logging.debug("\nSTART HANDSHAKE...")

    connect_document = Connect(signing_key.pubkey, currency=currency)
    connect_message = connect_document.get_signed_json(signing_key)

    logging.debug("Send CONNECT message")
    ws.send_str(connect_message)

    loop = True
    remote_connect_document = None
    # Iterate on each message received...
    while loop:
        data = ws.receive_json()

        if "auth" in data and data["auth"] == "CONNECT":
            jsonschema.validate(data, ws2p.network.WS2P_CONNECT_MESSAGE_SCHEMA)

            logging.debug("Received a CONNECT message")

            remote_connect_document = Connect(
                data["pub"],
                challenge=data["challenge"],
                signature=data["sig"],
                currency=currency,
            )

            logging.debug("Received CONNECT message signature is valid")

            ack_message = Ack(
                signing_key.pubkey, remote_connect_document.challenge, currency=currency
            ).get_signed_json(signing_key)

            # Send ACK message
            logging.debug("Send ACK message...")
            ws.send_str(ack_message)

        if "auth" in data and data["auth"] == "ACK":
            jsonschema.validate(data, ws2p.network.WS2P_ACK_MESSAGE_SCHEMA)

            logging.debug("Received an ACK message")

            # Create ACK document from ACK response to verify signature
            Ack(
                data["pub"],
                connect_document.challenge,
                signature=data["sig"],
                currency=currency,
            )

            logging.debug("Received ACK message signature is valid")

            # If ACK response is ok, create OK message
            ok_message = Ok(
                signing_key.pubkey, connect_document.challenge, currency=currency
            ).get_signed_json(signing_key)

            # Send OK message
            logging.debug("Send OK message...")
            ws.send_str(ok_message)

        if (
            remote_connect_document is not None
            and "auth" in data
            and data["auth"] == "OK"
        ):
            jsonschema.validate(data, ws2p.network.WS2P_OK_MESSAGE_SCHEMA)

            logging.debug("Received an OK message")

            Ok(
                remote_connect_document.pubkey,
                connect_document.challenge,
                signature=data["sig"],
                currency=currency,
            )

            logging.debug("Received OK message signature is valid")

            # END HANDSHAKE #######################################################
            logging.debug("END OF HANDSHAKE\n")

            # exit loop
            break


def generate_ws2p_endpoint(
    bma_endpoint: Union[str, BMAEndpoint, SecuredBMAEndpoint]
) -> WS2PEndpoint:
    """
    Retrieve WS2P endpoints from BMA peering
    Take the first one found
    """
    bma_client = Client(bma_endpoint)
    peering = bma_client(bma.network.peering)

    for endpoint in peering["endpoints"]:
        if endpoint.startswith("WS2P"):
            return WS2PEndpoint.from_inline(endpoint)
    raise ValueError("No WS2P endpoint found")
