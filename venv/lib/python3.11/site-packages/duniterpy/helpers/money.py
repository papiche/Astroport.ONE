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

from typing import Any, Union

from duniterpy.grammars.output import CLTV, CSV, SIG, XHX, Condition


def output_available(
    condition: Condition, comparison: Any, value: Union[str, int]
) -> bool:
    """
    Check if output source is available
    Currently only handle unique condition without composition

    operator.lt(a, b) is equivalent to a < b
    operator.le(a, b) is equivalent to a <= b
    operator.gt(a, b) is equivalent to a > b
    operator.ge(a, b) is equivalent to a >= b
    """
    if isinstance(condition.left, SIG):
        return comparison(condition.left.pubkey, value)
    if isinstance(condition.left, CSV):
        return comparison(int(condition.left.time), value)
    if isinstance(condition.left, CLTV):
        return comparison(int(condition.left.timestamp), value)
    if isinstance(condition.left, XHX):
        return comparison(condition.left.sha_hash, value)

    return False
