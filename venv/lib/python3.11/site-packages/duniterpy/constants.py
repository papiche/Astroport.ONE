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

UID_REGEX = "[A-Za-z0-9_-]{2,100}"
PUBKEY_REGEX = "(?![OIl])[1-9A-Za-z]{42,45}"
SIGNATURE_REGEX = "[A-Za-z0-9+/]+(?:=|==)?"
BLOCK_HASH_REGEX = "[0-9a-fA-F]{5,64}"
TRANSACTION_HASH_REGEX = "[0-9a-fA-F]{5,64}"
HASH_REGEX = "[A-F0-9]{64}"
BLOCK_NUMBER_REGEX = "[0-9]+"
BLOCK_ID_REGEX = f"{BLOCK_NUMBER_REGEX}-{BLOCK_HASH_REGEX}"
CONDITIONS_REGEX = (
    f"(&&|\\|\\|| |[()]|(SIG\\({PUBKEY_REGEX}\\)|(XHX\\({HASH_REGEX}\\))))*"
)
# https://stackoverflow.com/a/17871737
IPV4SEG = "(?:25[0-5]|(?:2[0-4]|1?\\d)?\\d)"
IPV4_REGEX = f"(?:{IPV4SEG}\\.){{3}}{IPV4SEG}"
IPV6SEG = "[0-9a-fA-F]{1,4}"
IPV6_REGEX = (
    f"(?:{IPV6SEG}:){{7}}{IPV6SEG}|(?:{IPV6SEG}:){{1,7}}:|(?:{IPV6SEG}:){{1,6}}:{IPV6SEG}|"
    f"(?:{IPV6SEG}:){{1,5}}(?::{IPV6SEG}){{1,2}}|(?:{IPV6SEG}:){{1,4}}(?::{IPV6SEG}){{1,3}}|"
    f"(?:{IPV6SEG}:){{1,3}}(?::{IPV6SEG}){{1,4}}|(?:{IPV6SEG}:){{1,2}}(?::{IPV6SEG}){{1,5}}|"
    f"{IPV6SEG}:(?:(?::{IPV6SEG}){{1,6}})|:(?:(?::{IPV6SEG}){{1,7}}|:)|"
    f"fe80:(?::{IPV6SEG}){{0,4}}%[0-9a-zA-Z]+|::(?:ffff(?::0{{1,4}})?:)?{IPV4_REGEX}|"
    f"(?:{IPV6SEG}:){{1,4}}:{IPV4_REGEX}"
)
# https://stackoverflow.com/a/26987741
HOST_REGEX = (
    "(((?!-))(xn--|_)?[a-z0-9-]{0,61}[a-z0-9]\\.)*"
    "(xn--)?([a-z0-9][a-z0-9\\-]{0,60}|[a-z0-9-]{1,30}\\.[a-z]{2,})"
)
# https://stackoverflow.com/a/12968117
PORT_REGEX = (
    "[1-9]\\d{0,3}|0|[1-5]\\d{4}|6[0-4]\\d{3}|65[0-4]\\d{2}|655[0-2]\\d|6553[0-5]"
)
PATH_REGEX = "[/\\w \\.-]*/?"
WS2PID_REGEX = "[0-9a-f]{8}"
WS2P_PRIVATE_PREFIX_REGEX = "O[CT][SAM]"
WS2P_PUBLIC_PREFIX_REGEX = "I[CT]"
WS2P_HEAD_REGEX = "HEAD:?(?:[0-9]+)?"
EMPTY_HASH = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
ENDPOINT_FLAGS_REGEX = "[S]"
G1_CURRENCY_CODENAME = "g1"
G1_TEST_CURRENCY_CODENAME = "g1-test"
