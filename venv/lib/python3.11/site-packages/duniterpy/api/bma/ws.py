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

from duniterpy.api.bma.blockchain import BLOCK_SCHEMA
from duniterpy.api.bma.network import PEERING_SCHEMA
from duniterpy.api.client import Client, WSConnection

logger = logging.getLogger("duniter/ws")

MODULE = "ws"

WS_BLOCK_SCHEMA = BLOCK_SCHEMA
WS_PEER_SCHEMA = PEERING_SCHEMA


def block(client: Client) -> WSConnection:
    """
    Connect to block websocket

    :param client: Client to connect to the api
    :return:
    """
    return client.connect_ws(f"{MODULE}/block")


def peer(client: Client) -> WSConnection:
    """
    Connect to peer websocket

    :param client: Client to connect to the api
    :return:
    """
    return client.connect_ws(f"{MODULE}/peer")
