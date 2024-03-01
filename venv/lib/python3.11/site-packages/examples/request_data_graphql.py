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

from graphql import build_client_schema, get_introspection_query, language, validate
from graphql.error import GraphQLSyntaxError

from duniterpy.api.client import Client

# CONFIG #######################################

# You can either use a complete defined endpoint : [NAME_OF_THE_API] [DOMAIN] [IPv4] [IPv6] [PORT]
# or the simple definition : [NAME_OF_THE_API] [DOMAIN] [PORT]
# Here we use the secure BASIC_MERKLED_API (BMAS) for standard http over ssl requests
GVA_ENDPOINT = "GVA S g1.librelois.fr 443 gva"


################################################


def request_data_graphql():
    client = Client(GVA_ENDPOINT)

    # get query to get schema from api
    query = get_introspection_query(False)
    # get schema from api
    response = client.query(query)
    # convert response dict to schema
    schema = build_client_schema(response["data"])

    # create currentUd query
    query = """{
        currentUd {
            amount
            }
        }
    """

    # check query syntax
    try:
        ast_document = language.parse(query)
    except GraphQLSyntaxError as exception:
        print(f"Query syntax error: {exception.message}")
        return

    # validate query against schema
    errors = validate(schema, ast_document)
    if errors:
        print(f"Schema errors: {errors}")
        return

    # send valid query to api
    response = client.query(query)
    if isinstance(response, str):
        print(response)
    else:
        print(json.dumps(response, indent=2))


if __name__ == "__main__":
    request_data_graphql()
