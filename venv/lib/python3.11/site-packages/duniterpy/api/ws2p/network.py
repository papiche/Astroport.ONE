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

logger = logging.getLogger("duniter/network")


WS2P_CONNECT_MESSAGE_SCHEMA = {
    "type": "object",
    "properties": {
        "auth": {"type": "string", "pattern": "^CONNECT$"},
        "challenge": {"type": "string"},
        "currency": {"type": "string"},
        "pub": {"type": "string"},
        "sig": {"type": "string"},
    },
    "required": ["auth", "challenge", "currency", "pub", "sig"],
}

WS2P_ACK_MESSAGE_SCHEMA = {
    "type": "object",
    "properties": {
        "auth": {"type": "string", "pattern": "^ACK$"},
        "pub": {"type": "string"},
        "sig": {"type": "string"},
    },
    "required": ["auth", "pub", "sig"],
}

WS2P_OK_MESSAGE_SCHEMA = {
    "type": "object",
    "properties": {
        "auth": {"type": "string", "pattern": "^OK$"},
        "sig": {"type": "string"},
    },
    "required": ["auth", "sig"],
}
