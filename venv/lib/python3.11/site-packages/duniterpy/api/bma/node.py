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

from duniterpy.api.client import Client

logger = logging.getLogger("duniter/node")

MODULE = "node"

SUMMARY_SCHEMA = {
    "type": "object",
    "properties": {
        "duniter": {
            "type": "object",
            "properties": {
                "software": {"type": "string"},
                "version": {"type": "string"},
                "forkWindowSize": {"type": "number"},
                "storage": {
                    "type": "object",
                    "properties": {
                        "transaction": {"type": "boolean"},
                        "wotwizard": {"type": "boolean"},
                    },
                },
            },
            "required": ["software", "version", "forkWindowSize"],
        }
    },
    "required": ["duniter"],
}

SANDBOX_SCHEMA = {
    "type": "object",
    "properties": {"size": {"type": "number"}, "free": {"type": "number"}},
    "required": ["size", "free"],
}

SANDBOXES_SCHEMA = {
    "type": "object",
    "properties": {
        "identities": SANDBOX_SCHEMA,
        "memberships": SANDBOX_SCHEMA,
        "transactions": SANDBOX_SCHEMA,
    },
    "required": ["identities", "memberships", "transactions"],
}


def summary(client: Client) -> dict:
    """
    GET Duniter node version and infos

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/summary", schema=SUMMARY_SCHEMA)


def sandboxes(client: Client) -> dict:
    """
    GET Duniter node version and infos

    :param client: Client to connect to the api
    :return:
    """
    return client.get(f"{MODULE}/sandboxes", schema=SANDBOXES_SCHEMA)
