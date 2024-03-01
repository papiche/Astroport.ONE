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

import base64
import importlib.metadata
import re
from typing import Any, Dict, List, Optional

import libnacl

from .encryption_key import PublicKey
from .signing_key import SigningKey
from .verifying_key import VerifyingKey

# Headers constants
BEGIN_MESSAGE_HEADER = "-----BEGIN DUNITER MESSAGE-----"
END_MESSAGE_HEADER = "-----END DUNITER MESSAGE-----"
BEGIN_SIGNATURE_HEADER = "-----BEGIN DUNITER SIGNATURE-----"
END_SIGNATURE_HEADER = "-----END DUNITER SIGNATURE-----"
HEADER_PREFIX = "-----"
DASH_ESCAPE_PREFIX = "\x2D\x20"

# Version field value
libnacl_version = importlib.metadata.version("libnacl")
VERSION_FIELD_VALUE = f"Python Libnacl {libnacl_version}"

# Parser cursor status
ON_MESSAGE_FIELDS = 1
ON_MESSAGE_CONTENT = 2
ON_SIGNATURE_FIELDS = 3
ON_SIGNATURE_CONTENT = 4


# Custom exceptions
class MissingPublickeyAndSigningKeyException(Exception):
    """
    Raise when the message created is not encrypted and not signed...
    """


# Custom exceptions
class ParserMissingSigningKeyException(Exception):
    """
    Raise when the message is encrypted but no SigningKey instance is provided
    """


# Custom exceptions
class ParserMissingPublicKeysException(Exception):
    """
    Raise when there is at least one signature but no public keys are provided
    """


# Exception messages listed here
PARSER_MISSING_SIGNING_KEY_EXCEPTION = ParserMissingSigningKeyException(
    "The message is encrypted but no SigningKey instance is provided"
)
PARSER_MISSING_PUBLIC_KEYS_EXCEPTION = ParserMissingPublicKeysException(
    "At least one signature but no public keys are provided"
)

MISSING_PUBLIC_KEY_AND_SIGNING_KEY_EXCEPTION = MissingPublickeyAndSigningKeyException(
    "Ascii Armor Message needs a public key or a SigningKey but none are provided"
)


class AsciiArmor:
    """
    Class to handle writing and parsing of ascii armor messages
    """

    @staticmethod
    def create(
        message: str,
        pubkey: Optional[str] = None,
        signing_keys: Optional[List[SigningKey]] = None,
        message_comment: Optional[str] = None,
        signatures_comment: Optional[str] = None,
    ) -> str:
        """
        Encrypt a message in ascii armor format, optionally signing it

        :param message: Utf-8 message
        :param pubkey: Public key of recipient for encryption
        :param signing_keys: Optional list of SigningKey instances
        :param message_comment: Optional message comment field
        :param signatures_comment: Optional signatures comment field
        :return:
        """
        # if no public key and no signing key...
        if not pubkey and not signing_keys:
            # We can not create an Ascii Armor Message
            raise MISSING_PUBLIC_KEY_AND_SIGNING_KEY_EXCEPTION

        # keep only one newline at the end of the message
        message = message.rstrip("\n\r") + "\n"

        # create block with headers
        ascii_armor_block = f"{BEGIN_MESSAGE_HEADER}\n"

        # if encrypted message...
        if pubkey:
            # add encrypted message fields
            version_field = AsciiArmor._get_version_field()
            ascii_armor_block += f"{version_field}\n"

        # add message comment if specified
        if message_comment:
            comment_field = AsciiArmor._get_comment_field(message_comment)
            ascii_armor_block += f"{comment_field}\n"

        # blank line separator
        ascii_armor_block += "\n"

        if pubkey:
            # add encrypted message
            pubkey_instance = PublicKey(pubkey)
            base64_encrypted_message = base64.b64encode(
                pubkey_instance.encrypt_seal(message)
            )  # type: bytes
            ascii_armor_block += f'{base64_encrypted_message.decode("utf-8")}\n'
        else:
            # remove trailing spaces
            message = AsciiArmor._remove_trailing_spaces(message)

            # add dash escaped message to ascii armor content
            ascii_armor_block += AsciiArmor._dash_escape_text(message)

        # if no signature...
        if signing_keys is None:
            # add message tail
            ascii_armor_block += END_MESSAGE_HEADER
        else:
            # add signature blocks and close block on last signature
            count = 1
            for signing_key in signing_keys:
                ascii_armor_block += AsciiArmor._get_signature_block(
                    message, signing_key, count == len(signing_keys), signatures_comment
                )
                count += 1

        return ascii_armor_block

    @staticmethod
    def _remove_trailing_spaces(text: str) -> str:
        """
        Remove trailing spaces and tabs

        :param text: Text to clean up
        :return:
        """
        clean_text = ""

        for line in text.splitlines(True):
            # remove trailing spaces (0x20) and tabs (0x09)
            clean_text += line.rstrip("\x09\x20")

        return clean_text

    @staticmethod
    def _dash_escape_text(text: str) -> str:
        """
        Add dash '-' (0x2D) and space ' ' (0x20) as prefix on each line

        :param text: Text to dash-escape
        :return:
        """
        dash_escaped_text = ""

        for line in text.splitlines(True):
            # add dash '-' (0x2D) and space ' ' (0x20) as prefix
            dash_escaped_text += DASH_ESCAPE_PREFIX + line

        return dash_escaped_text

    @staticmethod
    def _parse_dash_escaped_line(dash_escaped_line: str) -> str:
        """
        Parse a dash-escaped text line

        :param dash_escaped_line: Dash escaped text line
        :return:
        """
        text = ""
        regex_dash_escape_prefix = re.compile("^" + DASH_ESCAPE_PREFIX)
        # if prefixed by a dash escape prefix...
        if regex_dash_escape_prefix.match(dash_escaped_line):
            # remove dash '-' (0x2D) and space ' ' (0x20) prefix
            text += dash_escaped_line[2:]

        return text

    @staticmethod
    def _get_version_field() -> str:
        """
        Return the Version field

        :return:
        """
        return f"Version: {VERSION_FIELD_VALUE}"

    @staticmethod
    def _get_comment_field(comment: str) -> str:
        """
        Return a comment field

        :param comment: Comment text
        :return:
        """
        return f"Comment: {comment}"

    @staticmethod
    def _get_signature_block(
        message: str,
        signing_key: SigningKey,
        close_block: bool = True,
        comment: Optional[str] = None,
    ) -> str:
        """
        Return a signature block

        :param message: Message (not encrypted!) to sign
        :param signing_key: The libnacl SigningKey instance of the keypair
        :param close_block: Optional flag to close the signature block with the signature tail header
        :param comment: Optional comment field content
        :return:
        """
        base64_signature = base64.b64encode(signing_key.signature(message))

        version_field = AsciiArmor._get_version_field()
        block = f"{BEGIN_SIGNATURE_HEADER}\n{version_field}\n"

        # add message comment if specified
        if comment:
            comment_field = AsciiArmor._get_comment_field(comment)
            block += f"{comment_field}\n"

        # blank line separator
        block += f'\n{base64_signature.decode("utf-8")}\n'

        if close_block:
            block += END_SIGNATURE_HEADER

        return block

    @staticmethod
    def parse(
        ascii_armor_message: str,
        signing_key: Optional[SigningKey] = None,
        sender_pubkeys: Optional[List[str]] = None,
    ) -> dict:
        """
        Return a dict with parsed content (decrypted message, signature validation) ::

            {
               'message':
                   {
                       'fields': {},
                       'content': str,
                    },
               'signatures': [
                   {'pubkey': str, 'valid': bool, fields: {}}
               ]
           }

        :param ascii_armor_message: The Ascii Armor Message Block including BEGIN and END headers
        :param signing_key: Optional Libnacl SigningKey instance to decrypt message
        :param sender_pubkeys: Optional sender's public keys list to verify signatures
        :exception libnacl.CryptError: Raise an exception if keypair fail to decrypt the message
        :exception MissingSigningKeyException: Raise an exception if no keypair given for encrypted message

        :return:
        """
        # regex patterns
        regex_begin_message = re.compile(BEGIN_MESSAGE_HEADER)
        regex_end_message = re.compile(END_MESSAGE_HEADER)
        regex_begin_signature = re.compile(BEGIN_SIGNATURE_HEADER)
        regex_end_signature = re.compile(END_SIGNATURE_HEADER)
        regex_fields = re.compile("^(Version|Comment): (.+)$")

        # trim message to get rid of empty lines
        ascii_armor_message = ascii_armor_message.strip(" \t\n\r")

        # init vars
        parsed_result = {
            "message": {"fields": {}, "content": ""},
            "signatures": [],
        }  # type: Dict[str, Any]
        cursor_status = 0
        message = ""
        signatures_index = 0

        # parse each line...
        for line in ascii_armor_message.splitlines(True):
            # if begin message header detected...
            if regex_begin_message.match(line):
                cursor_status = ON_MESSAGE_FIELDS
                continue

            # if we are on the fields lines...
            if cursor_status == ON_MESSAGE_FIELDS:
                # parse field
                m = regex_fields.match(line.strip())
                if m:
                    # capture field
                    msg_field_name = m.groups()[0]
                    msg_field_value = m.groups()[1]
                    parsed_result["message"]["fields"][msg_field_name] = msg_field_value
                    continue

                # if blank line...
                if line.strip("\n\t\r ") == "":
                    cursor_status = ON_MESSAGE_CONTENT
                    continue

            # if we are on the message content lines...
            if cursor_status == ON_MESSAGE_CONTENT:
                # if a header is detected, end of message content...
                if line.startswith(HEADER_PREFIX):
                    # if field Version is present, the message is encrypted...
                    if "Version" in parsed_result["message"]["fields"]:
                        # If keypair instance to decrypt not given...
                        if signing_key is None:
                            # SigningKey keypair is mandatory to decrypt the message...
                            raise PARSER_MISSING_SIGNING_KEY_EXCEPTION

                        # decrypt message with secret key from keypair
                        message = AsciiArmor._decrypt(message, signing_key)

                    # save message content in result
                    parsed_result["message"]["content"] = message

                    # if message end header...
                    if regex_end_message.match(line):
                        # stop parsing
                        break

                    # if signature begin header...
                    if regex_begin_signature.match(line):
                        # add signature dict in list
                        parsed_result["signatures"].append({"fields": {}})
                        cursor_status = ON_SIGNATURE_FIELDS
                        continue
                else:
                    # if field Version is present, the message is encrypted...
                    if "Version" in parsed_result["message"]["fields"]:
                        # concatenate encrypted line to message content
                        message += line
                    else:
                        # concatenate cleartext striped dash escaped line to message content
                        message += AsciiArmor._parse_dash_escaped_line(line)

            # if we are on a signature fields zone...
            if cursor_status == ON_SIGNATURE_FIELDS:
                # parse field
                m = regex_fields.match(line.strip())
                if m:
                    # capture field
                    sig_field_name = m.groups()[0]
                    sig_field_value = m.groups()[1]
                    parsed_result["signatures"][signatures_index]["fields"][
                        sig_field_name
                    ] = sig_field_value
                    continue

                # if blank line...
                if line.strip("\n\t\r ") == "":
                    cursor_status = ON_SIGNATURE_CONTENT
                    continue

            # if we are on the signature content...
            if cursor_status == ON_SIGNATURE_CONTENT:
                # if no public keys provided...
                if sender_pubkeys is None:
                    # raise exception
                    raise PARSER_MISSING_PUBLIC_KEYS_EXCEPTION

                # if end signature header detected...
                if regex_end_signature.match(line):
                    # end of parsing
                    break

                # if begin signature header detected...
                if regex_begin_signature.match(line):
                    signatures_index += 1
                    cursor_status = ON_SIGNATURE_FIELDS
                    continue

                for pubkey in sender_pubkeys:
                    verifier = VerifyingKey(pubkey)
                    signature = base64.b64decode(line)
                    parsed_result["signatures"][signatures_index]["pubkey"] = pubkey
                    try:
                        libnacl.crypto_sign_verify_detached(
                            signature, message, verifier.vk
                        )
                        parsed_result["signatures"][signatures_index]["valid"] = True
                    except ValueError:
                        parsed_result["signatures"][signatures_index]["valid"] = False

        return parsed_result

    @staticmethod
    def _decrypt(ascii_armor_message: str, signing_key: SigningKey) -> str:
        """
        Decrypt a message from ascii armor format

        :param ascii_armor_message: Utf-8 message
        :param signing_key: SigningKey instance created from credentials
        :return:
        """
        data = signing_key.decrypt_seal(base64.b64decode(ascii_armor_message))

        return data.decode("utf-8")
