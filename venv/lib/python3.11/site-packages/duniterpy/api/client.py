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

import copy
import json
import logging
from http.client import HTTPResponse
from typing import Any, Callable, Dict, Optional, Union
from urllib import parse, request

import jsonschema
from websocket import WebSocket

from duniterpy.api import endpoint

from .errors import DuniterError

logger = logging.getLogger("duniter")

# Response type constants
RESPONSE_JSON = "json"
RESPONSE_TEXT = "text"
RESPONSE_HTTP = "http"

# jsonschema validator
ERROR_SCHEMA = {
    "type": "object",
    "properties": {"ucode": {"type": "number"}, "message": {"type": "string"}},
    "required": ["ucode", "message"],
}


def parse_text(text: str, schema: dict) -> Any:
    """
    Validate and parse the BMA answer from websocket

    :param text: the bma answer
    :param schema: dict for jsonschema
    :return: the json data
    """
    try:
        data = json.loads(text)
        jsonschema.validate(data, schema)
    except (TypeError, json.decoder.JSONDecodeError) as e:
        raise jsonschema.ValidationError("Could not parse json") from e

    return data


def parse_error(text: str) -> dict:
    """
    Validate and parse the BMA answer from websocket

    :param text: the bma error
    :return: the json data
    """
    try:
        data = json.loads(text)
        jsonschema.validate(data, ERROR_SCHEMA)
    except (TypeError, json.decoder.JSONDecodeError) as e:
        raise jsonschema.ValidationError(f"Could not parse json : {str(e)}") from e

    return data


def parse_response(response: str, schema: dict) -> Any:
    """
    Validate and parse the BMA answer

    :param response: Response content
    :param schema: The expected response structure
    :return: the json data
    """
    try:
        data = json.loads(response)
        if schema is not None:
            jsonschema.validate(data, schema)
        return data
    except (TypeError, json.decoder.JSONDecodeError) as exception:
        raise jsonschema.ValidationError(
            f"Could not parse json : {str(exception)}"
        ) from exception


class WSConnectionException(Exception):
    pass


class WSConnection:
    """
    Abstraction layer on websocket library
    """

    def __init__(self, connection: WebSocket) -> None:
        """
        Init WSConnection instance

        :param connection: Connection instance of the websocket library
        """
        self.connection = connection

    def send_str(self, data: str):
        """
        Send a data string to the web socket connection

        :param data: Data string
        :return:
        """
        if self.connection is None:
            raise WSConnectionException("Connection property is empty")

        self.connection.send(data)

    def receive_str(self, timeout: Optional[float] = None) -> str:
        """
        Wait for a data string from the web socket connection

        :param timeout: Timeout in seconds
        :return:
        """
        if self.connection is None:
            raise WSConnectionException("Connection property is empty")
        if timeout is not None:
            self.connection.settimeout(timeout)
        return self.connection.recv()

    def receive_json(self, timeout: Optional[float] = None) -> Any:
        """
        Wait for json data from the web socket connection

        :param timeout: Timeout in seconds
        :return:
        """
        if self.connection is None:
            raise WSConnectionException("Connection property is empty")
        if timeout is not None:
            self.connection.settimeout(timeout)
        return json.loads(self.connection.recv())

    def close(self) -> None:
        """
        Close the web socket connection

        :return:
        """
        if self.connection is None:
            raise WSConnectionException("Connection property is empty")

        self.connection.close()


class API:
    """
    API is a class used as an abstraction layer over the http/websocket libraries.
    """

    def __init__(
        self,
        connection_handler: endpoint.ConnectionHandler,
        headers: Optional[dict] = None,
    ) -> None:
        """
        Asks a module in order to create the url used then by derivated classes.

        :param connection_handler: Connection handler
        :param headers: Headers dictionary (optional, default None)
        """
        self.connection_handler = connection_handler
        self.headers = {} if headers is None else headers

    def reverse_url(self, scheme: str, path: str) -> str:
        """
        Reverses the url using scheme and path given in parameter.

        :param scheme: Scheme of the url
        :param path: Path of the url
        :return:
        """
        # remove starting slash in path if present
        path = path.lstrip("/")

        address, port = self.connection_handler.address, self.connection_handler.port
        if self.connection_handler.path:
            url = f"{scheme}://{address}:{port}/{self.connection_handler.path}"
        else:
            url = f"{scheme}://{address}:{port}"

        if len(path.strip()) > 0:
            return f"{url}/{path}"

        return url

    def request_url(
        self,
        path: str,
        method: str = "GET",
        rtype: str = RESPONSE_JSON,
        schema: Optional[dict] = None,
        json_data: Optional[dict] = None,
        bma_errors: bool = False,
        **kwargs: Any,
    ) -> Any:
        """
        Requests wrapper in order to use API parameters.

        :param path: the request path
        :param method: Http method  'GET' or 'POST' (optional, default='GET')
        :param rtype: Response type (optional, default RESPONSE_JSON, can be RESPONSE_TEXT, RESPONSE_HTTP)
        :param schema: Json Schema to validate response (optional, default None)
        :param json_data: Json data as dict (optional, default None)
        :param bma_errors: Set it to True to handle Duniter Error Response (optional, default False)

        :return:
        """
        logging.debug(
            "Request: %s", self.reverse_url(self.connection_handler.http_scheme, path)
        )
        url = self.reverse_url(self.connection_handler.http_scheme, path)
        duniter_request = request.Request(url, method=method)

        if kwargs:
            # urlencoded http form content as bytes
            duniter_request.data = parse.urlencode(kwargs).encode("utf-8")
            logging.debug("%s : %s, data=%s", method, url, duniter_request.data)

        if json_data:
            # json content as bytes
            duniter_request.data = json.dumps(json_data).encode("utf-8")
            logging.debug("%s : %s, data=%s", method, url, duniter_request.data)

            # http header to send json body
            self.headers["Content-Type"] = "application/json"

        if self.headers:
            duniter_request.headers = self.headers

        if self.connection_handler.proxy:
            # proxy host
            duniter_request.set_proxy(
                self.connection_handler.proxy, self.connection_handler.http_scheme
            )

        with request.urlopen(
            duniter_request, timeout=15
        ) as response:  # type: HTTPResponse
            if response.status != 200:
                content = response.read().decode("utf-8")
                if bma_errors:
                    try:
                        error_data = parse_error(content)
                        raise DuniterError(error_data)
                    except (TypeError, jsonschema.ValidationError) as exception:
                        raise ValueError(
                            f"status code != 200 => {response.status} ({content})"
                        ) from exception

                raise ValueError(f"status code != 200 => {response.status} ({content})")

            # get response content
            return_response = copy.copy(response)
            content = response.read().decode("utf-8")

        # if schema supplied...
        if schema is not None:
            # validate response
            parse_response(content, schema)

        # return the chosen type
        result = return_response  # type: Any
        if rtype == RESPONSE_TEXT:
            result = content
        elif rtype == RESPONSE_JSON:
            result = json.loads(content)

        return result

    def connect_ws(self, path: str) -> WSConnection:
        """
        Connect to a websocket

        :param path: the url path
        :return:
        """
        url = self.reverse_url(self.connection_handler.ws_scheme, path)

        ws = WebSocket()
        if self.connection_handler.proxy:
            proxy_split = ":".split(self.connection_handler.proxy)
            if len(proxy_split) == 2:
                host = proxy_split[0]
                port = int(proxy_split[1])
            else:
                host = self.connection_handler.proxy
                port = 80
            ws.connect(url, http_proxy_host=host, http_proxy_port=port)
        else:
            ws.connect(url)

        return WSConnection(ws)


class Client:
    """
    Main class to create an API client
    """

    def __init__(
        self,
        _endpoint: Union[str, endpoint.Endpoint],
        proxy: Optional[str] = None,
    ) -> None:
        """
        Init Client instance

        :param _endpoint: Endpoint string in duniter format
        :param proxy: Proxy address as hostname:port (optional, default None)
        """
        if isinstance(_endpoint, str):
            # Endpoint Protocol detection
            self.endpoint = endpoint.endpoint(_endpoint)
        else:
            self.endpoint = _endpoint

        if isinstance(self.endpoint, endpoint.UnknownEndpoint):
            raise NotImplementedError(f"{self.endpoint.api} endpoint in not supported")

        self.proxy = proxy

    def get(
        self,
        url_path: str,
        params: Optional[dict] = None,
        rtype: str = RESPONSE_JSON,
        schema: Optional[dict] = None,
    ) -> Any:
        """
        GET request on endpoint host + url_path

        :param url_path: Url encoded path following the endpoint
        :param params: Url query string parameters dictionary (optional, default None)
        :param rtype: Response type (optional, default RESPONSE_JSON, can be RESPONSE_TEXT, RESPONSE_HTTP)
        :param schema: Json Schema to validate response (optional, default None)
        :return:
        """
        if params is None:
            params = {}

        client = API(self.endpoint.conn_handler(self.proxy))

        # get response
        return client.request_url(
            url_path, "GET", rtype, schema, bma_errors=True, **params
        )

    def post(
        self,
        url_path: str,
        params: Optional[dict] = None,
        rtype: str = RESPONSE_JSON,
        schema: Optional[dict] = None,
    ) -> Any:
        """
        POST request on endpoint host + url_path

        :param url_path: Url encoded path following the endpoint
        :param params: Url query string parameters dictionary (optional, default None)
        :param rtype: Response type (optional, default RESPONSE_JSON, can be RESPONSE_TEXT, RESPONSE_HTTP)
        :param schema: Json Schema to validate response (optional, default None)
        :return:
        """
        if params is None:
            params = {}

        client = API(self.endpoint.conn_handler(self.proxy))

        # get response
        return client.request_url(
            url_path, "POST", rtype, schema, bma_errors=True, **params
        )

    def query(
        self,
        query: str,
        variables: Optional[dict] = None,
        schema: Optional[dict] = None,
    ) -> Any:
        """
        GraphQL query or mutation request on endpoint

        :param query: GraphQL query string
        :param variables: Variables for the query (optional, default None)
        :param schema: Json Schema to validate response (optional, default None)
        :return:
        """
        payload = {"query": query}  # type: Dict[str, Union[str, dict]]

        if variables is not None:
            payload["variables"] = variables

        client = API(self.endpoint.conn_handler(self.proxy))

        # get json response
        response = client.request_url(
            "", "POST", rtype=RESPONSE_JSON, schema=schema, json_data=payload
        )

        # if schema supplied...
        if schema is not None:
            # validate response
            parse_response(response, schema)

        return response

    def connect_ws(self, path: str = "") -> WSConnection:
        """
        Connect to a websocket in order to use API parameters

        :param path: the url path
        :return:
        """
        client = API(self.endpoint.conn_handler(self.proxy))
        return client.connect_ws(path)

    def __call__(self, _function: Callable, *args: Any, **kwargs: Any) -> Any:
        """
        Call the _function given with the args given
        So we can call many packages wrapping the REST API

        :param _function: The function to call
        :param args: The parameters
        :param kwargs: The key/value parameters
        :return:
        """
        return _function(self, *args, **kwargs)
