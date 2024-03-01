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

from itertools import groupby
from typing import Any, Dict, List

from duniterpy.api import bma
from duniterpy.api.client import Client
from duniterpy.documents.peer import MalformedDocumentError, Peer
from duniterpy.documents.ws2p.heads import HeadV2


def get_available_nodes(client: Client) -> List[List[Dict[str, Any]]]:
    """
    Get available nodes grouped and sorted by descending block_id

    Each entry is a list of nodes (HeadV2 instance, inline endpoint list) sharing the same block_id:

        [
            [{"head": HeadV2, "endpoints": [str, ...]}, ...],
            [{"head": HeadV2, "endpoints": [str, ...]}, ...],
            ...
        ]

    You can just select the first endpoint of the first node of the first group to quickly get an available node.

        groups = get_available_nodes(client)
        first_node_first_endpoint = groups[0][0]["endpoints"][0]

    If node is down, you can select another node.

    Warning: only nodes with BMAS, BASIC_MERKLED_API, and GVA endpoint are selected
              and only those endpoints are available in the endpoint list

    :param client: Client instance
    :return:
    """
    # capture heads and peers
    heads_response = client(bma.network.ws2p_heads)
    peers_response = client(bma.network.peers)

    # get heads instances from WS2P messages
    heads = []
    for entry in heads_response["heads"]:
        head, _ = HeadV2.from_inline(entry["messageV2"], entry["sigV2"])
        heads.append(head)

    # sort by block_id by descending order
    heads = sorted(heads, key=lambda x: x.block_id, reverse=True)

    # group heads by block_id
    groups = []
    for _, group in groupby(heads, key=lambda x: x.block_id):
        nodes = []
        for head in list(group):
            # if head signature not valid...
            if head.check_signature(head.pubkey) is False:
                # skip this node
                continue

            bma_peers = [
                bma_peer
                for bma_peer in peers_response["peers"]
                if bma_peer["pubkey"] == head.pubkey
            ]

            # if no peer found...
            if len(bma_peers) == 0:
                # skip this node
                continue

            bma_peer = bma_peers[0]

            try:
                peer = Peer.from_bma(bma_peer)
            # if bad peer... (mostly bad formatted endpoints)
            except MalformedDocumentError:
                # skip this node
                continue

            # set signature in Document
            peer.signature = bma_peer["signature"]
            #  if peer signature not valid
            if peer.check_signature(head.pubkey) is False:
                # skip this node
                continue

            # filter endpoints to get only BMAS, BASIC_MERKLED_API or GVA
            endpoints = [
                endpoint
                for endpoint in bma_peers[0]["endpoints"]
                if endpoint.startswith("BMAS")
                or endpoint.startswith("BASIC_MERKLED_API")
                or endpoint.startswith("GVA")
            ]
            if len(endpoints) == 0:
                # skip this node
                continue

            # add node to group nodes
            nodes.append({"head": head, "endpoints": endpoints})

        # if nodes in group...
        if len(nodes) > 0:
            # add group to groups
            groups.append(nodes)

    return groups
