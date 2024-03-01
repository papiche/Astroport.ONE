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

from pathlib import Path

import mnemonic

from duniterpy.key import SigningKey

################################################


def create_mnemonic_wallet():
    # list supported language for mnemonic passphrase
    print("List of supported languages for passphrase:\n")
    wordlist_path = Path(mnemonic.__path__[0]).joinpath("wordlist")
    language_filenames = list(wordlist_path.iterdir())
    for index, language_filename in enumerate(language_filenames):
        print(f"{index}) {Path(language_filename).stem}")

    # prompt language index
    language_index = int(input("\nChoose language index for the mnemonic passphrase: "))

    # get language name from filename
    language = Path(language_filenames[language_index]).stem

    # generate mnemonic wallet with 128bits strength (12 words)
    passphrase = mnemonic.Mnemonic(language).generate(strength=128)

    # Create key object
    key = SigningKey.from_dubp_mnemonic(mnemonic=passphrase)

    # Display wallet passphrase and public key
    print(f"\nPassphrase: {passphrase}")
    print(f"Public key: {key.pubkey}")


if __name__ == "__main__":
    create_mnemonic_wallet()
