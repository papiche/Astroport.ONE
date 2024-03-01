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

from duniterpy.api.client import RESPONSE_HTTP, Client

logger = logging.getLogger("duniter/wot")

MODULE = "wot"

CERTIFICATIONS_SCHEMA = {
    "type": "object",
    "properties": {
        "pubkey": {"type": "string"},
        "uid": {"type": "string"},
        "isMember": {"type": "boolean"},
        "certifications": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "pubkey": {"type": "string"},
                    "uid": {"type": "string"},
                    "cert_time": {
                        "type": "object",
                        "properties": {
                            "block": {"type": "number"},
                            "medianTime": {"type": "number"},
                        },
                        "required": ["block", "medianTime"],
                    },
                    "sigDate": {"type": "string"},
                    "written": {
                        "oneOf": [
                            {
                                "type": "object",
                                "properties": {
                                    "number": {"type": "number"},
                                    "hash": {"type": "string"},
                                },
                                "required": ["number", "hash"],
                            },
                            {"type": "null"},
                        ]
                    },
                    "isMember": {"type": "boolean"},
                    "wasMember": {"type": "boolean"},
                    "signature": {"type": "string"},
                },
                "required": [
                    "pubkey",
                    "uid",
                    "cert_time",
                    "sigDate",
                    "written",
                    "wasMember",
                    "isMember",
                    "signature",
                ],
            },
        },
    },
    "required": ["pubkey", "uid", "isMember", "certifications"],
}

MEMBERS_SCHEMA = {
    "type": "object",
    "properties": {
        "results": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"pubkey": {"type": "string"}},
                "required": ["pubkey"],
            },
        }
    },
    "required": ["results"],
}

REQUIREMENTS_SCHEMA = {
    "type": "object",
    "properties": {
        "identities": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "pubkey": {"type": "string"},
                    "uid": {"type": "string"},
                    "meta": {
                        "type": "object",
                        "properties": {"timestamp": {"type": "string"}},
                        "required": ["timestamp"],
                    },
                    "outdistanced": {"type": "boolean"},
                    "certifications": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "from": {"type": "string"},
                                "to": {"type": "string"},
                                "expiresIn": {"type": "number"},
                            },
                            "required": ["from", "to", "expiresIn"],
                        },
                    },
                    "membershipPendingExpiresIn": {"type": "number"},
                    "membershipExpiresIn": {"type": "number"},
                    "wasMember": {"type": "boolean"},
                    "isSentry": {"type": "boolean"},
                    "revoked": {"type": "boolean"},
                    "revokation_sig": {"type": ["string", "null"]},
                    "revoked_on": {"type": ["number", "null"]},
                },
                "required": [
                    "pubkey",
                    "uid",
                    "meta",
                    "outdistanced",
                    "certifications",
                    "membershipPendingExpiresIn",
                    "membershipExpiresIn",
                    "wasMember",
                    "isSentry",
                    "revoked",
                    "revoked_on",
                    "revocation_sig",
                ],
            },
        }
    },
    "required": ["identities"],
}

LOOKUP_SCHEMA = {
    "type": "object",
    "definitions": {
        "meta_data": {"type": "object", "properties": {"timestamp": {"type": "string"}}}
    },
    "properties": {
        "partial": {"type": "boolean"},
        "results": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "pubkey": {"type": "string"},
                    "uids": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "uid": {"type": "string"},
                                "meta": {"$ref": "#/definitions/meta_data"},
                                "self": {"type": "string"},
                                "revocation_sig": {"type": ["string", "null"]},
                                "revoked_on": {"type": ["number", "null"]},
                                "revoked": {"type": "boolean"},
                                "others": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "pubkey": {"type": "string"},
                                            "meta": {"$ref": "#/definitions/meta_data"},
                                            "signature": {"type": "string"},
                                        },
                                    },
                                },
                            },
                            "required": [
                                "uid",
                                "meta",
                                "self",
                                "revocation_sig",
                                "revoked",
                                "others",
                            ],
                        },
                    },
                    "signed": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "uid": {"type": "string"},
                                "pubkey": {"type": "string"},
                                "meta": {"$ref": "#/definitions/meta_data"},
                                "signature": {"type": "string"},
                                "revocation_sig": {"type": ["string", "null"]},
                                "revoked_on": {"type": ["number", "null"]},
                                "revoked": {"type": "boolean"},
                            },
                            "required": ["uid", "pubkey", "meta", "signature"],
                        },
                    },
                },
            },
        },
    },
    "required": ["partial", "results"],
}

IDENTITY_OF_SCHEMA = {
    "type": "object",
    "properties": {
        "pubkey": {"type": "string"},
        "uid": {"type": "string"},
        "sigDate": {"type": "string"},
    },
}


def add(client: Client, identity_signed_raw: str) -> HTTPResponse:
    """
    POST identity raw document

    :param client: Client to connect to the api
    :param identity_signed_raw: Identity raw document
    :return:
    """
    return client.post(
        f"{MODULE}/add", {"identity": identity_signed_raw}, rtype=RESPONSE_HTTP
    )


def certify(client: Client, certification_signed_raw: str) -> HTTPResponse:
    """
    POST certification raw document

    :param client: Client to connect to the api
    :param certification_signed_raw: Certification raw document
    :return:
    """
    return client.post(
        f"{MODULE}/certify", {"cert": certification_signed_raw}, rtype=RESPONSE_HTTP
    )


def revoke(client: Client, revocation_signed_raw: str) -> HTTPResponse:
    """
    POST revocation document

    :param client: Client to connect to the api
    :param revocation_signed_raw: Certification raw document
    :return:
    """
    return client.post(
        f"{MODULE}/revoke",
        {"revocation": revocation_signed_raw},
        rtype=RESPONSE_HTTP,
    )


def lookup(client: Client, search: str) -> dict:
    """
    GET UID/Public key data

    :param client: Client to connect to the api
    :param search: UID or public key
    :return:
    """
    return client.get(f"{MODULE}/lookup/{search}", schema=LOOKUP_SCHEMA)


def certifiers_of(client: Client, search: str, pubkey: bool = False) -> dict:
    """
    GET UID/Public key certifiers

    :param client: Client to connect to the api
    :param search: UID or public key
    :param pubkey: Query argument for passing a public key for quicker response
    :return:
    """
    pubkey_query = "?pubkey" if pubkey else ""
    return client.get(
        f"{MODULE}/certifiers-of/{search}{pubkey_query}", schema=CERTIFICATIONS_SCHEMA
    )


def certified_by(client: Client, search: str, pubkey: bool = False) -> dict:
    """
    GET identities certified by UID/Public key

    :param client: Client to connect to the api
    :param search: UID or public key
    :param pubkey: Query argument for passing a public key for quicker response
    :return:
    """
    pubkey_query = "?pubkey" if pubkey else ""
    return client.get(
        f"{MODULE}/certified-by/{search}{pubkey_query}", schema=CERTIFICATIONS_SCHEMA
    )


def members(client: Client) -> dict:
    """
    GET list of all current members of the Web of Trust

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/members", schema=MEMBERS_SCHEMA)


def requirements(client: Client, search: str, pubkey: bool = False) -> dict:
    """
    GET list of requirements for a given UID/Public key

    :param client: Client to connect to the api
    :param search: UID or public key
    :param pubkey: Query argument for passing a public key for quicker response
    :return:
    """
    pubkey_query = "?pubkey" if pubkey else ""
    return client.get(
        f"{MODULE}/requirements/{search}{pubkey_query}", schema=REQUIREMENTS_SCHEMA
    )


def requirements_of_pending(client: Client, minsig: int) -> dict:
    """
    GET list of requirements of all pending identities with a minimum of minsig certifications

    :param client: Client to connect to the api
    :param minsig: Minimum number of certifications
    :return:
    """
    return client.get(
        f"{MODULE}/requirements-of-pending/{minsig}", schema=REQUIREMENTS_SCHEMA
    )


def identity_of(client: Client, search: str) -> dict:
    """
    GET Identity data written in the blockchain

    :param client: Client to connect to the api
    :param search: UID or public key
    :return:
    """
    return client.get(f"{MODULE}/identity-of/{search}", schema=IDENTITY_OF_SCHEMA)
