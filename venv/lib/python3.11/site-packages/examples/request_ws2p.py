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

import json
import time
from typing import Any

import jsonschema
from jsonschema import ValidationError

from duniterpy.api.client import Client, WSConnection
from duniterpy.api.ws2p import requests
from duniterpy.constants import G1_TEST_CURRENCY_CODENAME
from duniterpy.helpers.ws2p import generate_ws2p_endpoint, handshake
from duniterpy.key import SigningKey
from duniterpy.tools import get_ws2p_challenge

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the WS2P API (WS2P [UUID] [DOMAIN] [PORT] [PATH])
BMAS_ENDPOINT = "BMAS g1-test.duniter.org 443"
CURRENCY = G1_TEST_CURRENCY_CODENAME


################################################


def send(ws: WSConnection, request: str, request_id: str, schema: dict) -> Any:
    """
    Send a WS2P request

    :rtype: Any
    :param ws: WSConnection instance
    :param request: Request string to send
    :param request_id: Unique request id
    :param schema: Validation schema
    """
    # Send request
    ws.send_str(request)

    # Wait response with request id
    response = ws.receive_json()
    while "resId" not in response or (
        "resId" in response and response["resId"] != request_id
    ):
        response = ws.receive_json()
        time.sleep(1)
    try:
        # Check response format
        jsonschema.validate(response, schema)
        # If valid display response
    except ValidationError:
        # If invalid response...
        try:
            # Check error response format
            jsonschema.validate(response, requests.ERROR_RESPONSE_SCHEMA)
            # If valid, display error response
        except ValidationError as exception:
            # If invalid, display exception on response validation
            print(exception)

    return response


def request_ws2p():
    """
    Main code
    """
    # dummy credentials
    salt = password = "test"

    # You can connect with member credentials in case there is not much slots available on the endpoint
    #
    # # Prompt hidden user entry
    # import getpass
    # salt = getpass.getpass("Enter your passphrase (salt): ")
    #
    # # Prompt hidden user entry
    # password = getpass.getpass("Enter your password: ")

    # Init signing_key instance
    signing_key = SigningKey.from_credentials(salt, password)

    # Create Client from endpoint string in Duniter format
    try:
        ws2p_endpoint = generate_ws2p_endpoint(BMAS_ENDPOINT)
    except ValueError as e:
        print(e)
        return
    client = Client(ws2p_endpoint)

    try:
        # Create a Web Socket connection
        ws = client.connect_ws()

        print("Successfully connected to the web socket endpoint")

        # HANDSHAKE #######################################################
        try:
            handshake(ws, signing_key, CURRENCY)
        except ValidationError as exception:
            print(exception.message)
            print("HANDSHAKE FAILED!")
            return

        # Send ws2p request
        print("Send getCurrent() request")
        request_id = get_ws2p_challenge()[:8]
        response = send(
            ws,
            requests.get_current(request_id),
            request_id,
            requests.BLOCK_RESPONSE_SCHEMA,
        )
        print("Response: " + json.dumps(response, indent=2))

        # Send ws2p request
        print("Send getBlock(30000) request")
        request_id = get_ws2p_challenge()[:8]
        response = send(
            ws,
            requests.get_block(request_id, 30000),
            request_id,
            requests.BLOCK_RESPONSE_SCHEMA,
        )
        print("Response: " + json.dumps(response, indent=2))

        # Send ws2p request
        print("Send getBlocks(30000, 2) request")
        request_id = get_ws2p_challenge()[:8]
        response = send(
            ws,
            requests.get_blocks(request_id, 30000, 2),
            request_id,
            requests.BLOCKS_RESPONSE_SCHEMA,
        )
        print("Response: " + json.dumps(response, indent=2))

        # Send ws2p request
        print("Send getRequirementsPending(3) request")
        request_id = get_ws2p_challenge()[:8]
        response = send(
            ws,
            requests.get_requirements_pending(request_id, 3),
            request_id,
            requests.REQUIREMENTS_RESPONSE_SCHEMA,
        )
        print("Response: " + json.dumps(response, indent=2))

    except jsonschema.ValidationError as e:
        print(f"{str(e.__class__.__name__)}:{str(e)}")


if __name__ == "__main__":
    request_ws2p()
