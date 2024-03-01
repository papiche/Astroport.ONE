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

from duniterpy.api.client import Client
from duniterpy.helpers import network

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the secure BASIC_MERKLED_API (BMAS)
BMAS_ENDPOINT = "BMAS g1-test.duniter.org 443"


################################################


def request_available_nodes():
    # Create Client from endpoint string in Duniter format
    client = Client(BMAS_ENDPOINT)

    groups = network.get_available_nodes(client)
    for group in groups:
        block = group[0]["head"].block_id
        print(f"block {block} shared by {len(group)} nodes")

    print("\nAvailable endpoints:")

    for node in groups[0]:
        for endpoint in node["endpoints"]:
            print(endpoint)


if __name__ == "__main__":
    request_available_nodes()
