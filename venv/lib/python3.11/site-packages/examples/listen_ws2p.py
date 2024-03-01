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

import jsonschema

from duniterpy.api.client import Client
from duniterpy.constants import G1_TEST_CURRENCY_CODENAME
from duniterpy.helpers.ws2p import generate_ws2p_endpoint, handshake
from duniterpy.key import SigningKey

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the WS2P API (WS2P [UUID] [DOMAIN] [PORT] [PATH])
BMAS_ENDPOINT = "BMAS g1-test.duniter.org 443"
CURRENCY = G1_TEST_CURRENCY_CODENAME


################################################


def listen_ws2p():
    """
    Main code
    """
    # Arbitrary credentials to create the node key pair to sign ws2p documents
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
            # Resolve handshake
            print("Handshake…")
            handshake(ws, signing_key, CURRENCY)
        except jsonschema.ValidationError as exception:
            print(exception.message)
            print("HANDSHAKE FAILED!")
            return

        print("Handshake ok")

        try:
            loop = True
            # Iterate on each message received...
            while loop:
                print("Waiting message, press CTRL-C to stop…")
                # Wait and capture next message
                data = ws.receive_json()
                print("Message received:")
                print(json.dumps(data, indent=2))
        except KeyboardInterrupt:
            # close the websocket connection
            ws.close()
            print("Connection closed.")

    except jsonschema.ValidationError as e:
        print(f"{str(e.__class__.__name__)}:{str(e)}")


if __name__ == "__main__":
    listen_ws2p()
