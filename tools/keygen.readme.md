# keygen: Generate Cryptographic Keys from GPG, Credentials, or Other Formats

`keygen` is a versatile command-line tool for generating cryptographic keys for various applications, including Duniter, IPFS, Bitcoin, Monero, Nostr, SSH and PGP. It can derive ED25519 keys from GPG keys, Duniter username/password combinations, mnemonic phrases, or existing keys in different formats.

## Features

*   **Key Derivation:** Generate ED25519 keys from:
    *   GPG keys
    *   Duniter credentials (username/password)
    *   Mnemonic phrases (DUBP)
    *   Existing keys in various formats (EWIF, JWK, NaCl, PEM, PubSec, Seed, WIF, DEWIF)
*   **Output Formats:**  Supports a wide array of output text formats:
    *   `base58`: Base58 encoded keys.
    *   `base64`: Base64 encoded keys.
    *   `b58mh`: Base58 multihash encoded keys (for IPFS).
    *   `b64mh`: Base64 multihash encoded keys (for IPFS).
    *   `duniter`: Base58 encoding for Duniter wallets (and files).
    *   `ipfs`: Multihash encoded keys for IPFS.
    *   `jwk`: JSON Web Key format.
    *   `bitcoin`: Bitcoin private key and public address
    *   `monero`: Monero private keys and public address
    *   `nostr`: Nostr keys in npub and nsec format
    *   `ssh`: OpenSSH private and public keys
    *   `pgp`: PGP private and public keys in ASCII armored format
*   **File Formats:**  Supports several file formats:
    *   `ewif`: Encrypted WIF file (Duniter).
    *   `dewif`: Double Encrypted WIF file (Duniter).
    *   `jwk`: JSON Web Key file.
    *   `nacl`: NaCl private key file.
    *   `pb2`: Protocol Buffer version 2 for IPFS
    *   `pem`: PEM encoded PKCS#8 private key.
    *   `pubsec`: PubSec file (Duniter).
    *   `seed`: Seed file (hexadecimal representation).
    *   `wif`: WIF file (Duniter).
*   **GPG Integration:**  Fetches and unlocks GPG keys using `gnupg` and `pgpy` libraries. Supports password-protected GPG keys.
*   **Mnemonic Support:**  Derives keys from DUBP (Duniter Unified Backup Phrase) mnemonic phrases.
*   **File Input Detection:** Automatically detects the format of input files.
*   **Encryption:** Supports encrypting files using EWIF and DEWIF formats.
*   **Security:** Designed with security in mind, but be extremely cautious when handling secret keys, especially when debugging is enabled.
*   **Configuration File:** Reads configuration from `~/.config/keygen/keygen.conf` (or `$XDG_CONFIG_HOME/keygen/keygen.conf`).  This file can be used to specify scrypt parameters.
*   **Pinentry Support:** Uses `pynentry` to prompt for passwords or passphrases when needed.

## Usage

```bash
./keygen [options] [username] [password]
```

### Options

*   `-d, --debug`: Show debug information (WARNING: includes SECRET KEY).
*   `-f, --format FORMAT`: Output file format (ewif, jwk, nacl, pb2, pem, pubsec, seed, wif). Default: pem.
*   `-g, --gpg`: Use GPG key with UID matched by username.
*   `-i, --input FILE`: Read ED25519 key from FILE (autodetects format).
*   `-k, --keys`: Show public and secret keys.
*   `-m, --mnemonic`: Use username as a DUBP mnemonic passphrase.
*   `-o, --output FILE`: Write ED25519 key to FILE.
*   `-p, --prefix`: Prefix output text with key type.
*   `-q, --quiet`: Show only errors.
*   `-s, --secret`: Show only secret key.
*   `-t, --type TYPE`: Output text format (base58, base64, b58mh, b64mh, duniter, ipfs, jwk, bitcoin, ssh, monero, pgp, nostr). Default: base58.
*   `-v, --verbose`: Show more information.
*   `--version`: Show version and exit.
*   `username`: The username to use for key derivation.
*   `password`: The password to use for key derivation.

### Examples

1.  **Generate a Duniter wallet from a username and password:**

    ```bash
    ./keygen -t duniter my_username my_password
    ```

    This will output the public and secret keys in Base58 format, suitable for use with Duniter.

2.  **Generate an IPFS key from a username and password, and save it to a file:**

    ```bash
    ./keygen -t ipfs -o ipfs_key my_username my_password
    ```

    This will save the PeerID (public key) and PrivKEY (private key) to the `ipfs_key` file, suitable for use with IPFS.

3.  **Generate a Duniter wallet from a username and password, and save it to a DEWIF file:**

    ```bash
    ./keygen -t duniter -f dewif -o my_wallet my_username
    ```

    The script will prompt for a passphrase to encrypt the wallet.

4.  **Generate an ED25519 key from a GPG key:**

    ```bash
    ./keygen -g -t base58 my_gpg_username
    ```

    This will use the GPG key associated with the username "my\_gpg\_username" to derive the ED25519 key. The script will prompt for the GPG key passphrase if required.

5.  **Generate an ED25519 key from a mnemonic phrase:**

    ```bash
    ./keygen -m -t base58 "word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12"
    ```

    This will use the 12-word mnemonic phrase to derive the ED25519 key.

6.  **Read an ED25519 key from a file and output it in JWK format:**

    ```bash
    ./keygen -i existing_key.pem -t jwk
    ```

7. **Generating SSH keys from a mnemonic:**

    ```bash
    ./keygen -m -t ssh -o ~/.ssh/id_ed25519 "your mnemonic phrase"
    ```
    This generates a SSH ED25519 key from the mnemonic phrase and saves the private key to ~/.ssh/id_ed25519 and the public key to ~/.ssh/id_ed25519.pub

8.  **Generate an SSH key pair:**

    ```bash
    ./keygen -t ssh -o my_ssh_key my_username my_password
    ```

    This generates an SSH key pair and saves the private key to `my_ssh_key` and the public key to `my_ssh_key.pub`.  This is suitable for using with SSH.

9. **Generating PGP keys from credentials:**

    ```bash
    ./keygen -t pgp -o my_pgp_keys my_username my_password
    ```
    This generates PGP keys and saves the private key to my_pgp_keys_private.asc and the public key to my_pgp_keys_public.asc

10. **Generating Bitcoin keys from credentials:**

    ```bash
    ./keygen -t bitcoin my_username my_password
    ```
    This generates Bitcoin private key (WIF) and public address

11. **Generating Monero keys from credentials:**

    ```bash
    ./keygen -t monero my_username my_password
    ```
    This generates Monero private spend key, private view key, and public address

12. **Generating Nostr keys from credentials:**

    ```bash
    ./keygen -t nostr my_username my_password
    ```
    This generates Nostr public key (npub) and private key (nsec)

### Configuration

The `keygen.conf` file in the `~/.config/keygen` directory (or `$XDG_CONFIG_HOME/keygen/`) allows you to configure the scrypt parameters used for key derivation.  The file should be in the following format:

```ini
[scrypt]
n = 4096
r = 16
p = 1
sl = 32
```

These parameters control the computational cost of the scrypt key derivation function.  Adjusting these values can impact the security and performance of key generation.  Refer to the Duniter documentation for recommended values.

### Security Considerations

*   **Secret Keys:** Handle secret keys with extreme care. Avoid printing them to the console, especially when debugging is enabled.
*   **File Permissions:** Ensure that key files are stored with appropriate permissions (e.g., `chmod 600 my_key_file`).
*   **Passphrases:** Choose strong, unique passphrases to protect your keys.
*   **GPG Keys:**  Protect your GPG keys with a strong passphrase.
*   **Debugging:**  Avoid using the `--debug` option in production environments, as it exposes secret keys.
*   **Backup:**  Back up your key files and passphrases securely.
*   **Seed entropy:** ensure you give sufficient entropy to the seed (ie. the username and password) by using strong username and password

### Exit Codes
*   `0`: Success.
*   `1`: Warning.
*   `2`: Error.

### Disclaimer

This tool is provided as-is, without any warranty. Use it at your own risk.  The developers are not responsible for any loss or damage resulting from the use of this tool.
