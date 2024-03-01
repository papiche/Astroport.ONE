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

import asyncio

from duniterpy.api import bma
from duniterpy.api.client import Client

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT] [PATH]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT] [PATH]
# Here we use the secure BASIC_MERKLED_API (BMAS)
BMAS_ENDPOINT = "BMAS g1-test.duniter.org 443"


################################################


async def print_response(request):
    print(await request)


async def coroutine(function, *args, **kwargs):
    return function(*args, **kwargs)


async def request_data_async():
    """
    Main code (asynchronous requests)
    You can send one millions request with aiohttp:
    https://pawelmhm.github.io/asyncio/python/aiohttp/2016/04/22/asyncio-aiohttp.html
    But don't do that on one server, it's DDOS!
    """
    # Create Client from endpoint string in Duniter format
    client = Client(BMAS_ENDPOINT)
    tasks = []

    # Get the node summary infos by dedicated method (with json schema validation)
    print("\nCall bma.node.summary:")
    task = asyncio.ensure_future(coroutine(client, bma.node.summary))
    tasks.append(task)

    # Get the money parameters located in the first block
    print("\nCall bma.blockchain.parameters:")
    task = asyncio.ensure_future(coroutine(client, bma.blockchain.parameters))
    tasks.append(task)

    responses = await asyncio.gather(*tasks)
    # you now have all response bodies in this variable
    print("\nResponses:")
    print(responses)


# Latest duniter-python-api is asynchronous and you have to use asyncio, an asyncio loop and a "as" on the data.
# ( https://docs.python.org/3/library/asyncio.html )
if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(request_data_async())
