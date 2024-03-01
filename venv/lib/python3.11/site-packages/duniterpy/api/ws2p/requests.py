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
import re

from duniterpy.api.bma.blockchain import BLOCK_SCHEMA, BLOCKS_SCHEMA

ERROR_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "resId": {"type": "string", "pattern": "^[0-9,a-z,A-Z]{8}$"},
        "err": {"type": "string"},
    },
    "required": ["resId", "err"],
}

BLOCK_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "resId": {"type": "string", "pattern": "^[0-9,a-z,A-Z]{8}$"},
        "body": BLOCK_SCHEMA,
    },
    "required": ["resId", "body"],
}

BLOCKS_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "resId": {"type": "string", "pattern": "^[0-9,a-z,A-Z]{8}$"},
        "body": BLOCKS_SCHEMA,
    },
    "required": ["resId", "body"],
}

REQUIREMENTS_SCHEMA = {
    "type": "object",
    "properties": {
        "identities": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "certifications": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "from": {"type": "string"},
                                "to": {"type": "string"},
                                "expiresIn": {"type": "number"},
                                "timestamp": {"type": "number"},
                            },
                            "required": ["from", "to", "expiresIn", "timestamp"],
                        },
                    },
                    "expired": {"type": "boolean"},
                    "isSentry": {"type": "boolean"},
                    "membershipExpiresIn": {"type": "number"},
                    "membershipPendingExpiresIn": {"type": "number"},
                    "meta": {
                        "type": "object",
                        "properties": {"timestamp": {"type": "string"}},
                        "required": ["timestamp"],
                    },
                    "outdistanced": {"type": "boolean"},
                    "pendingCerts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "block": {"type": "number"},
                                "block_hash": {"type": "string"},
                                "block_number": {"type": "number"},
                                "blockstamp": {"type": "string"},
                                "expired": {"type": "number", "const": 0},
                                "expires_on": {"type": "number"},
                                "from": {"type": "string"},
                                "linked": {"type": "boolean", "const": False},
                                "sig": {"type": "string"},
                                "target": {"type": "string"},
                                "to": {"type": "string"},
                                "written": {"type": "boolean", "const": False},
                                "written_block": {
                                    "type": ["string", "null"],
                                    "const": None,
                                },
                                "written_hash": {
                                    "type": ["string", "null"],
                                    "const": None,
                                },
                            },
                        },
                    },
                    "pendingMemberships": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "block": {"type": "string"},
                                "blockHash": {"type": "string"},
                                "blockNumber": {"type": "number"},
                                "blockstamp": {"type": "string"},
                                "certts": {"type": "string"},
                                "expired": {"type": ["number", "null"], "const": None},
                                "expires_on": {"type": "number"},
                                "fpr": {"type": "string"},
                                "idtyHash": {"type": "string"},
                                "issuer": {"type": "string"},
                                "membership": {"type": "string", "enum": ["IN", "OUT"]},
                                "number": {"type": "number"},
                                "sig": {"type": "string"},
                                "signature": {"type": "string"},
                                "type": {"type": "string"},
                                "userid": {"type": "string"},
                                "linked": {"type": "boolean", "const": False},
                                "written_number": {
                                    "type": ["number", "null"],
                                    "const": None,
                                },
                            },
                        },
                    },
                    "pubkey": {"type": "string"},
                    "revokation_sig": {"type": ["string", "null"]},
                    "revoked": {"type": "boolean"},
                    "sig": {"type": "string"},
                    "uid": {"type": "string"},
                    "wasMember": {"type": "boolean"},
                },
                "required": [
                    "certifications",
                    "expired",
                    "isSentry",
                    "membershipExpiresIn",
                    "membershipPendingExpiresIn",
                    "meta",
                    "outdistanced",
                    "pendingCerts",
                    "pendingMemberships",
                    "pubkey",
                    "revocation_sig",
                    "revoked",
                    "sig",
                    "uid",
                    "wasMember",
                ],
            },
        }
    },
    "required": ["identities"],
}

REQUIREMENTS_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "resId": {"type": "string", "pattern": "^[0-9,a-z,A-Z]{8}$"},
        "body": REQUIREMENTS_SCHEMA,
    },
    "required": ["resId", "body"],
}


class WS2PException(Exception):
    pass


def get_current(request_id: str) -> str:
    """
    Return ws2p getCurrent() request as json string

    :return:
    """
    if not re.fullmatch("^[0-9a-zA-Z]{8}$", request_id):
        raise WS2PException("Invalid ws2p request unique id")
    return json.dumps({"reqId": request_id, "body": {"name": "CURRENT", "params": {}}})


def get_block(request_id: str, block_number: int) -> str:
    """
    Return ws2p getBlock() request as json string

    :return:
    """
    if not re.fullmatch("^[0-9a-zA-Z]{8}$", request_id):
        raise WS2PException("Invalid ws2p request unique id")
    return json.dumps(
        {
            "reqId": request_id,
            "body": {"name": "BLOCK_BY_NUMBER", "params": {"number": block_number}},
        }
    )


def get_blocks(request_id: str, from_number: int, count: int) -> str:
    """
    Return ws2p getBlocks(fromNumber, count) request as json string

    :return:
    """
    if not re.fullmatch("^[0-9a-zA-Z]{8}$", request_id):
        raise WS2PException("Invalid ws2p request unique id")
    return json.dumps(
        {
            "reqId": request_id,
            "body": {
                "name": "BLOCKS_CHUNK",
                "params": {"fromNumber": from_number, "count": count},
            },
        }
    )


def get_requirements_pending(request_id: str, min_cert: int) -> str:
    """
    Return ws2p getRequirementsPending(minCert) request as json string

    :return:
    """
    if not re.fullmatch("^[0-9a-zA-Z]{8}$", request_id):
        raise WS2PException("Invalid ws2p request unique id")
    return json.dumps(
        {
            "reqId": request_id,
            "body": {
                "name": "WOT_REQUIREMENTS_OF_PENDING",
                "params": {"minCert": min_cert},
            },
        }
    )
