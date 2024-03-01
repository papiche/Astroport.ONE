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

from duniterpy.api import bma
from duniterpy.api.client import Client

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the secure BASIC_MERKLED_API (BMAS)
BMAS_ENDPOINT = "BMAS g1-test.duniter.org 443"


################################################


def request_web_socket_block():
    """
    Main code
    """
    # Create Client from endpoint string in Duniter format
    client = Client(BMAS_ENDPOINT)

    try:
        # Create Web Socket connection on block path (method)
        ws = client(bma.ws.block)  # Type: WSConnection

        print("Connected successfully to web socket block path")

        loop = True
        # Iterate on each message received...
        while loop:
            print("Waiting message…")
            # Wait and capture next message
            data = ws.receive_json()
            jsonschema.validate(data, bma.ws.WS_BLOCK_SCHEMA)
            print("Message received:")
            print(json.dumps(data, indent=2))

    except jsonschema.ValidationError as e:
        print(f"{str(e.__class__.__name__)}:{str(e)}")


if __name__ == "__main__":
    request_web_socket_block()
