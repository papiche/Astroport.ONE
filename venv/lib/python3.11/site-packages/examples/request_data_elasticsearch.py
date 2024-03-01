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

# Duniter4j ES API documentation: https://git.duniter.org/clients/java/duniter4j/blob/master/src/site/markdown/ES_API.md
# Duniter4j project: https://git.duniter.org/clients/java/duniter4j/

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the secure BASIC_MERKLED_API (BMAS)
ES_CORE_ENDPOINT = "ES_CORE_API g1-test.data.e-is.pro 443"
ES_USER_ENDPOINT = "ES_USER_API g1-test.data.e-is.pro 443"


################################################


def request_data_elasticsearch():
    """
    Main code (synchronous requests)
    """
    # Create Client from endpoint string in Duniter format
    client = Client(ES_CORE_ENDPOINT)

    # Get the current node (direct REST GET request)
    print("\nGET g1-test/block/current/_source:")
    response = client.get("g1-test/block/current/_source")
    print(response)

    # Get the node number 2 with only selected fields (direct REST GET request)
    print("\nGET g1-test/block/2/_source:")
    response = client.get(
        "g1-test/block/2/_source", {"_source": "number,hash,dividend,membersCount"}
    )
    print(response)

    # Create Client from endpoint string in Duniter format
    client = Client(ES_USER_ENDPOINT)

    # prompt entry
    pubkey = input("\nEnter a public key to get the user profile: ")
    pubkey = pubkey.strip(" \n")

    # Get the profil of a public key (direct REST GET request)
    print(f"\nGET user/profile/{pubkey}/_source:")
    response = client.get(f"user/profile/{pubkey}/_source")
    print(response)


if __name__ == "__main__":
    request_data_elasticsearch()
