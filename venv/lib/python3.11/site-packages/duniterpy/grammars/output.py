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

from typing import Any, Optional, Type, TypeVar, Union

from pypeg2 import Enum, K, Keyword, attr, contiguous, maybe_some, re, whitespace

from ..constants import HASH_REGEX, PUBKEY_REGEX


class Pubkey(str):
    """
    Pubkey in transaction output condition
    """

    regex = re.compile(PUBKEY_REGEX)


class Hash(str):
    """
    Hash in transaction output condition
    """

    regex = re.compile(HASH_REGEX)


class Int(str):
    """
    Integer in transaction output condition
    """

    regex = re.compile(r"[0-9]+")


# required to type hint cls in classmethod
SIGType = TypeVar("SIGType", bound="SIG")


class SIG:
    """
    SIGnature function in transaction output condition
    """

    grammar = "SIG(", attr("pubkey", Pubkey), ")"

    def __init__(self, value: str = "") -> None:
        """
        Init SIG instance

        :param value: Content of the string
        """
        self.value = value
        self.pubkey = ""

    def __str__(self) -> str:
        return self.value

    def __eq__(self, other: Any) -> bool:
        """
        Check SIG instances equality
        """
        if not isinstance(other, SIG):
            return NotImplemented
        return self.value == other.value and self.pubkey == other.pubkey

    def __hash__(self) -> int:
        return hash((self.value, self.pubkey))

    @classmethod
    def token(cls: Type[SIGType], pubkey: str) -> SIGType:
        """
        Return SIG instance from pubkey

        :param pubkey: Public key of the signature issuer
        :return:
        """
        sig = cls()
        sig.pubkey = pubkey
        return sig

    def compose(
        self, parser: Any = None, grammar: Any = None, attr_of: Any = None
    ) -> str:
        """
        Return the SIG(pubkey) expression as string format

        :param parser: Parser instance
        :param grammar: Grammar
        :param attr_of: Attribute of...
        :return:
        """
        return f"SIG({self.pubkey})"


# required to type hint cls in classmethod
CSVType = TypeVar("CSVType", bound="CSV")


class CSV:
    """
    CSV function in transaction output condition
    """

    grammar = "CSV(", attr("time", Int), ")"

    def __init__(self, value: str = "") -> None:
        """
        Init CSV instance

        :param value: Content of the string
        """
        self.value = value
        self.time = ""

    def __str__(self) -> str:
        return self.value

    def __eq__(self, other: Any) -> bool:
        """
        Check CSV instances equality
        """
        if not isinstance(other, CSV):
            return NotImplemented
        return self.value == other.value and self.time == other.time

    def __hash__(self) -> int:
        return hash((self.value, self.time))

    @classmethod
    def token(cls: Type[CSVType], time: int) -> CSVType:
        """
        Return CSV instance from time

        :param time: Timestamp
        :return:
        """
        csv = cls()
        csv.time = str(time)
        return csv

    def compose(
        self, parser: Any = None, grammar: Any = None, attr_of: Optional[str] = None
    ) -> str:
        """
        Return the CSV(time) expression as string format

        :param parser: Parser instance
        :param grammar: Grammar
        :param attr_of: Attribute of...
        """
        return f"CSV({self.time})"


# required to type hint cls in classmethod
CLTVType = TypeVar("CLTVType", bound="CLTV")


class CLTV:
    """
    CLTV function in transaction output condition
    """

    grammar = "CLTV(", attr("timestamp", Int), ")"

    def __init__(self, value: str = "") -> None:
        """
        Init CLTV instance

        :param value: Content of the string
        """
        self.value = value
        self.timestamp = ""

    def __str__(self) -> str:
        return self.value

    def __eq__(self, other: Any) -> bool:
        """
        Check CLTV instances equality
        """
        if not isinstance(other, CLTV):
            return NotImplemented
        return self.value == other.value and self.timestamp == other.timestamp

    def __hash__(self) -> int:
        return hash((self.value, self.timestamp))

    @classmethod
    def token(cls: Type[CLTVType], timestamp: int) -> CLTVType:
        """
        Return CLTV instance from timestamp

        :param timestamp: Timestamp
        :return:
        """
        cltv = cls()
        cltv.timestamp = str(timestamp)
        return cltv

    def compose(
        self, parser: Any = None, grammar: Any = None, attr_of: Optional[str] = None
    ) -> str:
        """
        Return the CLTV(timestamp) expression as string format

        :param parser: Parser instance
        :param grammar: Grammar
        :param attr_of: Attribute of...
        """
        return f"CLTV({self.timestamp})"


# required to type hint cls in classmethod
XHXType = TypeVar("XHXType", bound="XHX")


class XHX:
    """
    XHX function in transaction output condition
    """

    grammar = "XHX(", attr("sha_hash", Hash), ")"

    def __init__(self, value: str = "") -> None:
        """
        Init XHX instance

        :param value: Content of the string
        """
        self.value = value
        self.sha_hash = ""

    def __str__(self) -> str:
        return self.value

    def __eq__(self, other: Any) -> bool:
        """
        Check XHX instances equality
        """
        if not isinstance(other, XHX):
            return NotImplemented
        return self.value == other.value and self.sha_hash == other.sha_hash

    def __hash__(self) -> int:
        return hash((self.value, self.sha_hash))

    @classmethod
    def token(cls: Type[XHXType], sha_hash: str) -> XHXType:
        """
        Return XHX instance from sha_hash

        :param sha_hash: SHA256 hash
        :return:
        """
        xhx = cls()
        xhx.sha_hash = sha_hash
        return xhx

    def compose(
        self, parser: Any = None, grammar: Any = None, attr_of: Optional[str] = None
    ) -> str:
        """
        Return the XHX(sha_hash) expression as string format

        :param parser: Parser instance
        :param grammar: Grammar
        :param attr_of: Attribute of...
        """
        return f"XHX({self.sha_hash})"


# required to type hint cls in classmethod
OperatorType = TypeVar("OperatorType", bound="Operator")


class Operator(Keyword):
    """
    Operator in transaction output condition
    """

    grammar = Enum(K("&&"), K("||"), K("AND"), K("OR"))
    regex = re.compile(r"[&&|\|\||\w]+")

    @classmethod
    def token(cls: Type[OperatorType], keyword: str) -> OperatorType:
        """
        Return Operator instance from keyword

        :param keyword: Operator keyword in expression
        :return:
        """
        op = cls(keyword)
        return op

    def compose(
        self, parser: Any = None, grammar: Any = None, attr_of: Optional[str] = None
    ) -> str:
        """
        Return the Operator keyword as string format

        :param parser: Parser instance
        :param grammar: Grammar
        :param attr_of: Attribute of...
        """
        return f"{self.name}"


# required to type hint cls in classmethod
ConditionType = TypeVar("ConditionType", bound="Condition")


class Condition:
    """
    Condition expression in transaction output

    """

    grammar = None

    def __init__(self, value: str = "") -> None:
        """
        Init Condition instance

        :param value: Content of the condition as string
        """
        self.value = value
        self.left = ""  # type: Union[str, Condition]
        self.right = ""  # type: Union[str, Condition]
        self.op = ""  # type: Union[str, Condition]

    def __eq__(self, other: Any) -> bool:
        """
        Check Condition instances equality
        """
        if not isinstance(other, Condition):
            return NotImplemented
        return (
            self.value == other.value
            and self.left == other.left
            and self.right == other.right
            and self.op == other.op
        )

    def __hash__(self) -> int:
        return hash((self.value, self.left, self.right, self.op))

    def __str__(self) -> str:
        return self.value

    @classmethod
    def token(
        cls: Type[ConditionType],
        left: Any,
        op: Optional[Any] = None,
        right: Optional[Any] = None,
    ) -> ConditionType:
        """
        Return Condition instance from arguments and Operator

        :param left: Left argument
        :param op: Operator
        :param right: Right argument
        :return:
        """
        condition = cls()
        condition.left = left
        if op:
            condition.op = op
        if right:
            condition.right = right
        return condition

    def compose(
        self, parser: Any, grammar: Any = None, attr_of: Optional[str] = None
    ) -> str:
        """
        Return the Condition as string format

        :param parser: Parser instance
        :param grammar: Grammar
        :param attr_of: Attribute of...
        """
        left = parser.compose(self.left, grammar=grammar, attr_of=attr_of)
        if type(self.left) is Condition:
            left = f"({left})"
        if getattr(self, "op", None):
            right = parser.compose(self.right, grammar=grammar, attr_of=attr_of)
            if type(self.right) is Condition:
                right = f"({right})"
            op = parser.compose(self.op, grammar=grammar, attr_of=attr_of)
            result = f"{left} {op} {right}"
        else:
            result = left
        return result


Condition.grammar = contiguous(
    attr("left", [SIG, XHX, CSV, CLTV, ("(", Condition, ")")]),
    maybe_some(
        whitespace,
        attr("op", Operator),
        whitespace,
        attr("right", [SIG, XHX, CSV, CLTV, ("(", Condition, ")")]),
    ),
)
