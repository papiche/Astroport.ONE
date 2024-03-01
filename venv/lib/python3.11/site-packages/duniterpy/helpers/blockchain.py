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
import pathlib

from ..documents import Block

CHUNK_SIZE = 250
DEFAULT_PATH = ".config/duniter/duniter_default/g1/"


class JsonBlockchain:
    def __init__(self, folder):
        self.folder = folder  # folder where chunks are stored
        # number of files starting with "chunk_"
        self.chunks = len(list(folder.glob("chunk_*")))
        # number from 0 to 249 equal to current_block // current_chunk
        self.current_block_in_chunk = 0
        self.current_chunk = 0  # current chunk number
        self.chunk = []  # parsed json for current chunk (length = 250)
        self.parsechunk()  # parse first chunk

    def parsechunk(self):
        """parse a json chunk file"""
        with open(
            self.folder.joinpath(
                f"chunk_{str(self.current_chunk)}-{str(CHUNK_SIZE)}.json"
            ),
            encoding="utf-8",
        ) as f:
            s = f.read()
            p = json.loads(s)
            self.chunk = p["blocks"]

    def __iter__(self):
        return self

    def __next__(self):
        """
        if current block is outside current chunk, parse next one,
        otherwise, return current block parsed json
        """
        if self.current_block_in_chunk == CHUNK_SIZE:  # block outside chunk
            self.current_block_in_chunk = 0  # reset to next chunk start
            self.current_chunk += 1  # increment current chunk number
            if self.current_chunk >= self.chunks:  # outside range
                raise StopIteration()
            self.parsechunk()  # parse this chunk
        # increment current block number for next iteration
        self.current_block_in_chunk += 1
        return self.chunk[
            self.current_block_in_chunk - 1
        ]  # return block (before incrementation)

    def current_block(self):
        """returns current block as a duniterpy block document"""
        json_block = self.chunk[self.current_block_in_chunk]
        return Block.from_parsed_json(json_block)

    def get_block_number(self, number):
        """get one precise block (do not use for iteration)"""
        self.current_chunk = number // CHUNK_SIZE
        self.current_block_in_chunk = number % CHUNK_SIZE
        self.parsechunk()
        return self.current_block()


def Blockchain(json_blockchain):
    """convert json to duniterpy block document"""
    jbc = json_blockchain
    for jb in jbc:
        yield Block.from_parsed_json(jb)


def load_json(path=DEFAULT_PATH):
    """returns a JsonBlockchain object"""
    path = pathlib.Path("~").joinpath(path).expanduser()  # expand path
    jbc = JsonBlockchain(path)  # gets an iterator over json blockchain
    return jbc


def load(path=DEFAULT_PATH):
    """returns an iterator allowing to browse all the blockchain
    in practice, it will load chunk by chunk and only keep one in memory at a time"""
    jbc = load_json(path)
    bc = Blockchain(jbc)  # convert it to an iterator over blocks
    return bc  # returns
