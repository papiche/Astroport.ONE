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
from http.client import HTTPResponse
from typing import Optional, Union

from duniterpy.api.client import RESPONSE_HTTP, Client

logger = logging.getLogger("duniter/blockchain")

MODULE = "blockchain"

BLOCK_SCHEMA = {
    "type": "object",
    "properties": {
        "version": {"type": "number"},
        "currency": {"type": "string"},
        "nonce": {"type": "number"},
        "number": {"type": "number"},
        "time": {"type": "number"},
        "medianTime": {"type": "number"},
        "dividend": {"type": ["number", "null"]},
        "monetaryMass": {"type": ["number", "null"]},
        "issuer": {"type": "string"},
        "previousHash": {"type": ["string", "null"]},
        "previousIssuer": {"type": ["string", "null"]},
        "membersCount": {"type": "number"},
        "hash": {"type": "string"},
        "inner_hash": {"type": "string"},
        "identities": {"type": "array", "items": {"type": "string"}},
        "joiners": {"type": "array", "items": {"type": "string"}},
        "leavers": {"type": "array", "items": {"type": "string"}},
        "revoked": {"type": "array", "items": {"type": "string"}},
        "excluded": {"type": "array", "items": {"type": "string"}},
        "certifications": {"type": "array", "items": {"type": "string"}},
        "transactions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "signatures": {"type": "array"},
                    "version": {"type": "number"},
                    "currency": {"type": "string"},
                    "issuers": {"type": "array", "items": {"type": "string"}},
                    "inputs": {"type": "array", "items": {"type": "string"}},
                    "unlocks": {"type": "array", "items": {"type": "string"}},
                    "outputs": {"type": "array", "item": {"type": "string"}},
                },
                "required": [
                    "signatures",
                    "version",
                    "currency",
                    "issuers",
                    "inputs",
                    "outputs",
                ],
            },
        },
        "signature": {"type": "string"},
    },
    "required": [
        "version",
        "currency",
        "nonce",
        "number",
        "time",
        "medianTime",
        "dividend",
        "monetaryMass",
        "issuer",
        "previousHash",
        "previousIssuer",
        "membersCount",
        "hash",
        "inner_hash",
        "identities",
        "joiners",
        "leavers",
        "excluded",
        "certifications",
        "transactions",
        "signature",
    ],
}

BLOCK_NUMBERS_SCHEMA = {
    "type": "object",
    "properties": {
        "result": {
            "type": "object",
            "properties": {"blocks": {"type": "array", "items": {"type": "number"}}},
            "required": ["blocks"],
        }
    },
    "required": ["result"],
}

PARAMETERS_SCHEMA = {
    "type": "object",
    "properties": {
        "currency": {"type": "string"},
        "c": {"type": "number"},
        "dt": {"type": "number"},
        "ud0": {"type": "number"},
        "sigPeriod": {"type": "number"},
        "sigStock": {"type": "number"},
        "sigWindow": {"type": "number"},
        "sigValidity": {"type": "number"},
        "sigQty": {"type": "number"},
        "sigReplay": {"type": "number"},
        "xpercent": {"type": "number"},
        "msValidity": {"type": "number"},
        "msPeriod": {"type": "number"},
        "stepMax": {"type": "number"},
        "medianTimeBlocks": {"type": "number"},
        "avgGenTime": {"type": "number"},
        "dtDiffEval": {"type": "number"},
        "percentRot": {"type": "number"},
        "udTime0": {"type": "number"},
        "udReevalTime0": {"type": "number"},
        "dtReeval": {"type": "number"},
    },
    "required": [
        "currency",
        "c",
        "dt",
        "ud0",
        "sigPeriod",
        "sigValidity",
        "sigQty",
        "xpercent",
        "sigStock",
        "sigWindow",
        "msValidity",
        "stepMax",
        "medianTimeBlocks",
        "avgGenTime",
        "dtDiffEval",
        "percentRot",
        "udTime0",
        "udReevalTime0",
        "dtReeval",
    ],
}

MEMBERSHIPS_SCHEMA = {
    "type": "object",
    "properties": {
        "pubkey": {"type": "string"},
        "uid": {"type": "string"},
        "sigDate": {"type": "string"},
        "memberships": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "version": {"type": "number"},
                    "currency": {"type": "string"},
                    "membership": {"type": "string"},
                    "blockNumber": {"type": "number"},
                    "written": {"type": ["number", "null"]},
                },
                "required": [
                    "version",
                    "currency",
                    "membership",
                    "blockNumber",
                    "blockHash",
                    "written",
                ],
            },
        },
    },
    "required": ["pubkey", "uid", "sigDate", "memberships"],
}

BLOCKS_SCHEMA = {"type": "array", "items": BLOCK_SCHEMA}

HARDSHIP_SCHEMA = {
    "type": "object",
    "properties": {"block": {"type": "number"}, "level": {"type": "number"}},
    "required": ["block", "level"],
}

DIFFICULTIES_SCHEMA = {
    "type": "object",
    "properties": {
        "block": {"type": "number"},
        "levels": {
            "type": "array",
            "prefixItems": [
                {
                    "type": "object",
                    "properties": {
                        "uid": {"type": "string"},
                        "level": {"type": "number"},
                    },
                    "required": ["uid", "level"],
                }
            ],
        },
    },
    "required": ["block", "levels"],
}

BRANCHES_SCHEMA = {"type": "object", "properties": {"blocks": BLOCKS_SCHEMA}}


def parameters(client: Client) -> dict:
    """
    GET the blockchain parameters used by this node

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/parameters", schema=PARAMETERS_SCHEMA)


def memberships(client: Client, search: str) -> dict:
    """
    GET list of Membership documents for UID/Public key

    :param client: Client to connect to the api
    :param search: UID/Public key
    :return:
    """
    return client.get(f"{MODULE}/memberships/{search}", schema=MEMBERSHIPS_SCHEMA)


def membership(client: Client, membership_signed_raw: str) -> HTTPResponse:
    """
    POST a Membership document

    :param client: Client to connect to the api
    :param membership_signed_raw: Membership signed raw document
    :return:
    """
    return client.post(
        f"{MODULE}/membership",
        {"membership": membership_signed_raw},
        rtype=RESPONSE_HTTP,
    )


def current(client: Client) -> dict:
    """
    GET the last accepted block

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/current", schema=BLOCK_SCHEMA)


def block(
    client: Client,
    number: int = 0,
    block_raw: Optional[str] = None,
    signature: Optional[str] = None,
) -> Union[dict, HTTPResponse]:
    """
    GET/POST a block from/to the blockchain

    :param client: Client to connect to the api
    :param number: Block number to get
    :param block_raw: Block document to post
    :param signature: Signature of the block document issuer
    :return:
    """
    # POST block
    if block_raw is not None and signature is not None:
        return client.post(
            f"{MODULE}/block",
            {"block": block_raw, "signature": signature},
            rtype=RESPONSE_HTTP,
        )
    # GET block
    return client.get(f"{MODULE}/block/{number}", schema=BLOCK_SCHEMA)


def blocks(client: Client, count: int, start: int) -> list:
    """
    GET list of blocks from the blockchain

    :param client: Client to connect to the api
    :param count: Number of blocks
    :param start: First block number
    :return:
    """
    assert type(count) is int
    assert type(start) is int

    return client.get(f"{MODULE}/blocks/{count}/{start}", schema=BLOCKS_SCHEMA)


def hardship(client: Client, pubkey: str) -> dict:
    """
    GET hardship level for given member's public key for writing next block

    :param client: Client to connect to the api
    :param pubkey:  Public key of the member
    :return:
    """
    return client.get(f"{MODULE}/hardship/{pubkey}", schema=HARDSHIP_SCHEMA)


def difficulties(client: Client) -> dict:
    """
    GET difficulties levels for members into current window for writing next block

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/difficulties", schema=DIFFICULTIES_SCHEMA)


def branches(client: Client) -> list:
    """
    GET current branches of the node (top block of each branch)

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/branches", schema=BRANCHES_SCHEMA)


def newcomers(client: Client) -> dict:
    """
    GET the block numbers containing newcomers

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/with/newcomers", schema=BLOCK_NUMBERS_SCHEMA)


def certifications(client: Client) -> dict:
    """
    GET the block numbers containing certifications

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/with/certs", schema=BLOCK_NUMBERS_SCHEMA)


def joiners(client: Client) -> dict:
    """
    GET the block numbers containing joiners

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/with/joiners", schema=BLOCK_NUMBERS_SCHEMA)


def actives(client: Client) -> dict:
    """
    GET the block numbers containing actives

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/with/actives", schema=BLOCK_NUMBERS_SCHEMA)


def leavers(client: Client) -> dict:
    """
    GET the block numbers containing leavers

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/with/leavers", schema=BLOCK_NUMBERS_SCHEMA)


def revoked(client: Client) -> dict:
    """
    GET the block numbers containing revoked members.

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/with/revoked", schema=BLOCK_NUMBERS_SCHEMA)


def excluded(client: Client) -> dict:
    """
    GET the block numbers containing excluded

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/with/excluded", schema=BLOCK_NUMBERS_SCHEMA)


def ud(client: Client) -> dict:
    """
    GET the block numbers containing universal dividend

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/with/ud", schema=BLOCK_NUMBERS_SCHEMA)


def tx(client: Client) -> dict:
    """
    GET the block numbers containing transactions

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/with/tx", schema=BLOCK_NUMBERS_SCHEMA)
