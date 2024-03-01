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

import re
from ipaddress import ip_address
from typing import Any, Dict, Optional, Tuple, Type, TypeVar

from duniterpy import constants as const

from ..documents import MalformedDocumentError


class ConnectionHandler:
    """Helper class used by other API classes to ease passing address connection information."""

    def __init__(
        self,
        http_scheme: str,
        ws_scheme: str,
        address: str,
        port: int,
        path: str,
        proxy: Optional[str] = None,
    ) -> None:
        """
        Init instance of connection handler

        :param http_scheme: Http scheme
        :param ws_scheme: Web socket scheme
        :param address: Domain name, IPv6, or IPv4 address
        :param port: Port number
        :param port: Url path
        :param proxy: Proxy (optional, default=None)
        """
        self.http_scheme = http_scheme
        self.ws_scheme = ws_scheme
        self.address = address
        self.port = port
        self.path = path
        self.proxy = proxy

    def __str__(self) -> str:
        return f"connection info: {self.address}:{self.port}"


# required to type hint cls in classmethod
EndpointType = TypeVar("EndpointType", bound="Endpoint")


class Endpoint:
    @classmethod
    def from_inline(cls: Type[EndpointType], inline: str) -> EndpointType:
        raise NotImplementedError("from_inline(..) is not implemented")

    def inline(self) -> str:
        raise NotImplementedError("inline() is not implemented")

    def conn_handler(self, proxy: Optional[str] = None) -> ConnectionHandler:
        raise NotImplementedError("conn_handler is not implemented")

    def __str__(self) -> str:
        raise NotImplementedError("__str__ is not implemented")

    def __eq__(self, other: Any) -> bool:
        return NotImplemented


# required to type hint cls in classmethod
UnknownEndpointType = TypeVar("UnknownEndpointType", bound="UnknownEndpoint")


class UnknownEndpoint(Endpoint):
    API = None

    def __init__(self, api: str, properties: list) -> None:
        self.api = api
        self.properties = properties

    @classmethod
    def from_inline(cls: Type[UnknownEndpointType], inline: str) -> UnknownEndpointType:
        """
        Return UnknownEndpoint instance from endpoint string

        :param inline: Endpoint string
        :return:
        """
        try:
            api = inline.split()[0]
            properties = inline.split()[1:]
            return cls(api, properties)
        except IndexError:
            raise MalformedDocumentError(inline) from IndexError

    def inline(self) -> str:
        """
        Return endpoint string

        :return:
        """
        doc = self.api
        for p in self.properties:
            doc += f" {p}"
        return doc

    def conn_handler(self, proxy: Optional[str] = None) -> ConnectionHandler:
        """
        Return connection handler

        :param proxy: Proxy address
        :return:
        """
        return ConnectionHandler("", "", "", 0, "")

    def __str__(self) -> str:
        properties = " ".join([f"{p}" for p in self.properties])
        return f"{self.api} {properties}"

    def __eq__(self, other: Any) -> bool:
        if not isinstance(other, UnknownEndpoint):
            return NotImplemented
        return self.api == other.api and self.properties == other.properties

    def __hash__(self) -> int:
        return hash((self.api, self.properties))


# required to type hint cls in classmethod
BMAEndpointType = TypeVar("BMAEndpointType", bound="BMAEndpoint")


class BMAEndpoint(Endpoint):
    API = "BASIC_MERKLED_API"
    re_inline = re.compile(
        f"^{API}(?: (?P<host>{const.HOST_REGEX}))?(?: (?P<ipv4>{const.IPV4_REGEX}))?(?: (?P<ipv6>{const.IPV6_REGEX}))?(?: (?P<port>{const.PORT_REGEX}))$"
    )

    def __init__(self, host: str, ipv4: str, ipv6: str, port: int) -> None:
        """
        Init BMAEndpoint instance

        :param host: Hostname
        :param ipv4: IP as IPv4 format
        :param ipv6: IP as IPv6 format
        :param port: Port number
        """
        self.host = host
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.port = port

    @classmethod
    def from_inline(cls: Type[BMAEndpointType], inline: str) -> BMAEndpointType:
        """
        Return BMAEndpoint instance from endpoint string

        :param inline: Endpoint string
        :return:
        """
        m = BMAEndpoint.re_inline.match(inline)
        if m is None:
            raise MalformedDocumentError(BMAEndpoint.API)
        host, ipv4 = fix_host_ipv4_mix_up(m["host"], m["ipv4"])
        ipv6 = m["ipv6"]
        port = int(m["port"])

        return cls(host, ipv4, ipv6, port)

    def inline(self) -> str:
        """
        Return endpoint string

        :return:
        """
        inlined = [
            str(info) for info in (self.host, self.ipv4, self.ipv6, self.port) if info
        ]
        return f'{self.API} {" ".join(inlined)}'

    def conn_handler(self, proxy: Optional[str] = None) -> ConnectionHandler:
        """
        Return connection handler instance for the endpoint

        :param proxy: Proxy url
        :return:
        """
        if self.host:
            conn_handler = ConnectionHandler(
                "http", "ws", self.host, self.port, "", proxy
            )
        elif self.ipv6:
            conn_handler = ConnectionHandler(
                "http", "ws", f"[{self.ipv6}]", self.port, "", proxy
            )
        else:
            conn_handler = ConnectionHandler(
                "http", "ws", self.ipv4, self.port, "", proxy
            )

        return conn_handler

    def __str__(self) -> str:
        return self.inline()

    def __eq__(self, other: Any) -> bool:
        if not isinstance(other, BMAEndpoint):
            return NotImplemented
        return (
            self.host == other.host
            and self.ipv4 == other.ipv4
            and self.ipv6 == other.ipv6
            and self.port == other.port
        )

    def __hash__(self) -> int:
        return hash((self.host, self.ipv4, self.ipv6, self.port))


# required to type hint cls in classmethod
SecuredBMAEndpointType = TypeVar("SecuredBMAEndpointType", bound="SecuredBMAEndpoint")


class SecuredBMAEndpoint(BMAEndpoint):
    API = "BMAS"
    re_inline = re.compile(
        f"^{API}(?: (?P<host>{const.HOST_REGEX}))?(?: (?P<ipv4>{const.IPV4_REGEX}))?(?: (?P<ipv6>{const.IPV6_REGEX}))? (?P<port>{const.PORT_REGEX})(?: (?P<path>{const.PATH_REGEX}))?$"
    )

    def __init__(self, host: str, ipv4: str, ipv6: str, port: int, path: str) -> None:
        """
        Init SecuredBMAEndpoint instance

        :param host: Hostname
        :param ipv4: IP as IPv4 format
        :param ipv6: IP as IPv6 format
        :param port: Port number
        :param path: Url path
        """
        super().__init__(host, ipv4, ipv6, port)
        self.path = path

    @classmethod
    def from_inline(
        cls: Type[SecuredBMAEndpointType], inline: str
    ) -> SecuredBMAEndpointType:
        """
        Return SecuredBMAEndpoint instance from endpoint string

        :param inline: Endpoint string
        :return:
        """
        m = SecuredBMAEndpoint.re_inline.match(inline)
        if m is None:
            raise MalformedDocumentError(SecuredBMAEndpoint.API)
        host, ipv4 = fix_host_ipv4_mix_up(m["host"], m["ipv4"])
        ipv6 = m["ipv6"]
        port = int(m["port"])
        path = m["path"]

        if not path:
            path = ""
        return cls(host, ipv4, ipv6, port, path)

    def inline(self) -> str:
        """
        Return endpoint string

        :return:
        """
        inlined = [
            str(info)
            for info in (self.host, self.ipv4, self.ipv6, self.port, self.path)
            if info
        ]
        return f'{self.API} {" ".join(inlined)}'

    def conn_handler(self, proxy: Optional[str] = None) -> ConnectionHandler:
        """
        Return connection handler instance for the endpoint

        :param proxy: Proxy url
        :return:
        """
        if self.host:
            conn_handler = ConnectionHandler(
                "https", "wss", self.host, self.port, self.path, proxy
            )
        elif self.ipv6:
            conn_handler = ConnectionHandler(
                "https", "wss", f"[{self.ipv6}]", self.port, self.path, proxy
            )
        else:
            conn_handler = ConnectionHandler(
                "https", "wss", self.ipv4, self.port, self.path, proxy
            )

        return conn_handler


# required to type hint cls in classmethod
WS2PEndpointType = TypeVar("WS2PEndpointType", bound="WS2PEndpoint")


class WS2PEndpoint(Endpoint):
    API = "WS2P"
    re_inline = re.compile(
        f"^{API} (?P<ws2pid>{const.WS2PID_REGEX}) (?P<host>(?:{const.HOST_REGEX})|(?:{const.IPV4_REGEX})|(?:{const.IPV6_REGEX})) (?P<port>{const.PORT_REGEX})?(?: (?P<path>{const.PATH_REGEX}))?$"
    )

    def __init__(self, ws2pid: str, host: str, port: int, path: str) -> None:
        self.ws2pid = ws2pid
        self.host = host
        self.port = port
        self.path = path

    @classmethod
    def from_inline(cls: Type[WS2PEndpointType], inline: str) -> WS2PEndpointType:
        """
        Return WS2PEndpoint instance from endpoint string

        :param inline: Endpoint string
        :return:
        """
        m = WS2PEndpoint.re_inline.match(inline)
        if m is None:
            raise MalformedDocumentError(WS2PEndpoint.API)
        ws2pid = m["ws2pid"]
        host = m["host"]
        port = int(m["port"])
        path = m["path"]
        if not path:
            path = ""
        return cls(ws2pid, host, port, path)

    def inline(self) -> str:
        """
        Return endpoint string

        :return:
        """
        inlined = [
            str(info) for info in (self.ws2pid, self.host, self.port, self.path) if info
        ]
        return f'{self.API} {" ".join(inlined)}'

    def conn_handler(self, proxy: Optional[str] = None) -> ConnectionHandler:
        """
        Return connection handler instance for the endpoint

        :param proxy: Proxy url
        :return:
        """
        http_scheme = "http"
        websocket_scheme = "ws"
        if self.port == 443:
            http_scheme += "s"
            websocket_scheme += "s"
        return ConnectionHandler(
            http_scheme, websocket_scheme, self.host, self.port, self.path, proxy
        )

    def __str__(self) -> str:
        return self.inline()

    def __eq__(self, other: Any) -> bool:
        if not isinstance(other, WS2PEndpoint):
            return NotImplemented
        return (
            self.host == other.host
            and self.ws2pid == other.ws2pid
            and self.port == other.port
            and self.path == other.path
        )

    def __hash__(self) -> int:
        return hash((self.ws2pid, self.host, self.port, self.path))


# required to type hint cls in classmethod
ESCoreEndpointType = TypeVar("ESCoreEndpointType", bound="ESCoreEndpoint")


class ESCoreEndpoint(Endpoint):
    API = "ES_CORE_API"
    re_inline = re.compile(
        f"^{API} (?P<host>(?:{const.HOST_REGEX})|(?:{const.IPV4_REGEX})) (?P<port>{const.PORT_REGEX})$"
    )

    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port

    @classmethod
    def from_inline(cls: Type[ESCoreEndpointType], inline: str) -> ESCoreEndpointType:
        """
        Return ESCoreEndpoint instance from endpoint string

        :param inline: Endpoint string
        :return:
        """
        m = ESCoreEndpoint.re_inline.match(inline)
        if m is None:
            raise MalformedDocumentError(ESCoreEndpoint.API)
        host = m["host"]
        port = int(m["port"])
        return cls(host, port)

    def inline(self) -> str:
        """
        Return endpoint string

        :return:
        """
        inlined = [str(info) for info in (self.host, self.port) if info]
        return f'{self.API} {" ".join(inlined)}'

    def conn_handler(self, proxy: Optional[str] = None) -> ConnectionHandler:
        """
        Return connection handler instance for the endpoint

        :param proxy: Proxy url
        :return:
        """
        return ConnectionHandler("https", "wss", self.host, self.port, "", proxy)

    def __str__(self) -> str:
        return self.inline()

    def __eq__(self, other: Any) -> bool:
        if not isinstance(other, ESCoreEndpoint):
            return NotImplemented
        return self.host == other.host and self.port == other.port

    def __hash__(self) -> int:
        return hash((self.host, self.port))


# required to type hint cls in classmethod
ESUserEndpointType = TypeVar("ESUserEndpointType", bound="ESUserEndpoint")


class ESUserEndpoint(Endpoint):
    API = "ES_USER_API"
    re_inline = re.compile(
        f"^{API} (?P<host>(?:{const.HOST_REGEX})|(?:{const.IPV4_REGEX})) (?P<port>{const.PORT_REGEX})$"
    )

    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port

    @classmethod
    def from_inline(cls: Type[ESUserEndpointType], inline: str) -> ESUserEndpointType:
        """
        Return ESUserEndpoint instance from endpoint string

        :param inline: Endpoint string
        :return:
        """
        m = ESUserEndpoint.re_inline.match(inline)
        if m is None:
            raise MalformedDocumentError(ESUserEndpoint.API)
        host = m["host"]
        port = int(m["port"])
        return cls(host, port)

    def inline(self) -> str:
        """
        Return endpoint string

        :return:
        """
        inlined = [str(info) for info in (self.host, self.port) if info]
        return f'{self.API} {" ".join(inlined)}'

    def conn_handler(self, proxy: Optional[str] = None) -> ConnectionHandler:
        """
        Return connection handler instance for the endpoint

        :param proxy: Proxy url
        :return:
        """
        return ConnectionHandler("https", "wss", self.host, self.port, "", proxy)

    def __str__(self) -> str:
        return self.inline()

    def __eq__(self, other: Any) -> bool:
        if not isinstance(other, ESUserEndpoint):
            return NotImplemented
        return self.host == other.host and self.port == other.port

    def __hash__(self) -> int:
        return hash((self.host, self.port))


# required to type hint cls in classmethod
ESSubscribtionEndpointType = TypeVar(
    "ESSubscribtionEndpointType", bound="ESSubscribtionEndpoint"
)


class ESSubscribtionEndpoint(Endpoint):
    API = "ES_SUBSCRIPTION_API"
    re_inline = re.compile(
        f"^{API} (?P<host>(?:{const.HOST_REGEX})|(?:{const.IPV4_REGEX})) (?P<port>{const.PORT_REGEX})$"
    )

    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port

    @classmethod
    def from_inline(
        cls: Type[ESSubscribtionEndpointType], inline: str
    ) -> ESSubscribtionEndpointType:
        """
        Return ESSubscribtionEndpoint instance from endpoint string

        :param inline: Endpoint string
        :return:
        """
        m = ESSubscribtionEndpoint.re_inline.match(inline)
        if m is None:
            raise MalformedDocumentError(ESSubscribtionEndpoint.API)
        host = m["host"]
        port = int(m["port"])
        return cls(host, port)

    def inline(self) -> str:
        """
        Return endpoint string

        :return:
        """
        inlined = [str(info) for info in (self.host, self.port) if info]
        return f'{self.API} {" ".join(inlined)}'

    def conn_handler(self, proxy: Optional[str] = None) -> ConnectionHandler:
        """
        Return connection handler instance for the endpoint

        :param proxy: Proxy url
        :return:
        """
        return ConnectionHandler("https", "wss", self.host, self.port, "", proxy)

    def __str__(self) -> str:
        return self.inline()

    def __eq__(self, other: Any) -> bool:
        if not isinstance(other, ESSubscribtionEndpoint):
            return NotImplemented
        return self.host == other.host and self.port == other.port

    def __hash__(self) -> int:
        return hash((ESSubscribtionEndpoint.API, self.host, self.port))


# required to type hint cls in classmethod
GVAEndpointType = TypeVar("GVAEndpointType", bound="GVAEndpoint")


class GVAEndpoint(Endpoint):
    API = "GVA"
    endpoint_format = f"^GVA(?: (?P<flags>{const.ENDPOINT_FLAGS_REGEX}))?(?: (?P<host>{const.HOST_REGEX}))?(?: (?P<ipv4>{const.IPV4_REGEX}))?(?: (?P<ipv6>{const.IPV6_REGEX}))? (?P<port>{const.PORT_REGEX})(?: (?P<path>{const.PATH_REGEX}))?$"
    re_inline = re.compile(endpoint_format)

    def __init__(
        self,
        flags: str,
        host: str,
        ipv4: str,
        ipv6: str,
        port: int,
        path: str,
    ) -> None:
        """
        Init GVAEndpoint instance

        :param flags: Flags of endpoint
        :param host: Hostname
        :param ipv4: IP as IPv4 format
        :param ipv6: IP as IPv6 format
        :param port: Port number
        :param path: Url path
        """
        self.flags = flags
        self.host = host
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.port = port
        self.path = path

    @classmethod
    def from_inline(cls: Type[GVAEndpointType], inline: str) -> GVAEndpointType:
        """
        Return GVAEndpoint instance from endpoint string

        :param inline: Endpoint string
        :return:
        """
        m = cls.re_inline.match(inline)
        if m is None:
            raise MalformedDocumentError(cls.API)
        flags = m["flags"]
        host, ipv4 = fix_host_ipv4_mix_up(m["host"], m["ipv4"])
        ipv6 = m["ipv6"]
        port = int(m["port"])
        path = m["path"]

        if not flags:
            flags = ""
        if not path:
            path = ""
        return cls(flags, host, ipv4, ipv6, port, path)

    def inline(self) -> str:
        """
        Return endpoint string

        :return:
        """
        inlined = [
            str(info)
            for info in (
                self.flags,
                self.host,
                self.ipv4,
                self.ipv6,
                self.port,
                self.path,
            )
            if info
        ]
        return f'{self.API} {" ".join(inlined)}'

    def conn_handler(self, proxy: Optional[str] = None) -> ConnectionHandler:
        """
        Return connection handler instance for the endpoint

        :param proxy: Proxy url
        :return:
        """
        scheme_http = "https" if "S" in self.flags else "http"
        scheme_ws = "wss" if "S" in self.flags else "ws"

        if self.host:
            conn_handler = ConnectionHandler(
                scheme_http, scheme_ws, self.host, self.port, self.path, proxy
            )
        elif self.ipv6:
            conn_handler = ConnectionHandler(
                scheme_http,
                scheme_ws,
                f"[{self.ipv6}]",
                self.port,
                self.path,
                proxy,
            )
        else:
            conn_handler = ConnectionHandler(
                scheme_http, scheme_ws, self.ipv4, self.port, self.path, proxy
            )

        return conn_handler

    def __str__(self) -> str:
        return self.inline()

    def __eq__(self, other: Any) -> bool:
        if not isinstance(other, self.__class__):
            return NotImplemented
        return (
            self.flags == other.flags
            and self.host == other.host
            and self.ipv4 == other.ipv4
            and self.ipv6 == other.ipv6
            and self.port == other.port
            and self.path == other.path
        )

    def __hash__(self) -> int:
        return hash((self.flags, self.host, self.ipv4, self.ipv6, self.port, self.path))


MANAGED_API = {
    BMAEndpoint.API: BMAEndpoint,
    SecuredBMAEndpoint.API: SecuredBMAEndpoint,
    WS2PEndpoint.API: WS2PEndpoint,
    ESCoreEndpoint.API: ESCoreEndpoint,
    ESUserEndpoint.API: ESUserEndpoint,
    ESSubscribtionEndpoint.API: ESSubscribtionEndpoint,
    GVAEndpoint.API: GVAEndpoint,
}  # type: Dict[str, Any]


def endpoint(value: Any) -> Any:
    """
    Convert an endpoint string to the corresponding Endpoint instance type

    :param value: Endpoint string or subclass
    :return:
    """
    result = UnknownEndpoint.from_inline(value)
    # if Endpoint instance...
    if issubclass(type(value), Endpoint):
        result = value
        # if str...
    elif isinstance(value, str):
        # find Endpoint instance
        for api, cls in MANAGED_API.items():
            if value.startswith(f"{api} "):
                result = cls.from_inline(value)
    else:
        raise TypeError(f"Cannot convert {value} to endpoint")

    return result


def fix_host_ipv4_mix_up(host: str, ipv4: str) -> Tuple[str, str]:
    mixed_up = False
    try:
        mixed_up = ip_address(host).version == 4 and not ipv4
    except ValueError:
        pass
    return ("", host) if mixed_up else (host, ipv4)
