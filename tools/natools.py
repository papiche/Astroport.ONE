#!/usr/bin/env python3

"""
	CopyLeft 2020 Pascal Engélibert <tuxmain@zettascript.org>

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU Affero General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU Affero General Public License for more details.

	You should have received a copy of the GNU Affero General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""

__version__ = "1.3.1"

import os, sys, duniterpy.key, libnacl, base58, base64, getpass

def getargv(arg:str, default:str="", n:int=1, args:list=sys.argv) -> str:
	if arg in args and len(args) > args.index(arg)+n:
		return args[args.index(arg)+n]
	else:
		return default

def read_data(data_path, b=True):
	if data_path == "-":
		if b:
			return sys.stdin.buffer.read()
		else:
			return sys.stdin.read()
	else:
		return open(os.path.expanduser(data_path), "rb" if b else "r").read()

def write_data(data, result_path):
	if result_path == "-":
		os.fdopen(sys.stdout.fileno(), 'wb').write(data)
	else:
		open(os.path.expanduser(result_path), "wb").write(data)

def encrypt(data, pubkey):
	return duniterpy.key.PublicKey(pubkey).encrypt_seal(data)

def decrypt(data, privkey):
	return privkey.decrypt_seal(data)

def box_encrypt(data, privkey, pubkey, nonce=None, attach_nonce=False):
	signer = libnacl.sign.Signer(privkey.seed)
	sk = libnacl.public.SecretKey(libnacl.crypto_sign_ed25519_sk_to_curve25519(signer.sk))
	verifier = libnacl.sign.Verifier(base58.b58decode(pubkey).hex())
	pk = libnacl.public.PublicKey(libnacl.crypto_sign_ed25519_pk_to_curve25519(verifier.vk))
	box = libnacl.public.Box(sk.sk, pk.pk)
	data = box.encrypt(data, nonce) if nonce else box.encrypt(data)
	return data if attach_nonce else data[24:]

def box_decrypt(data, privkey, pubkey, nonce=None):
	signer = libnacl.sign.Signer(privkey.seed)
	sk = libnacl.public.SecretKey(libnacl.crypto_sign_ed25519_sk_to_curve25519(signer.sk))
	verifier = libnacl.sign.Verifier(base58.b58decode(pubkey).hex())
	pk = libnacl.public.PublicKey(libnacl.crypto_sign_ed25519_pk_to_curve25519(verifier.vk))
	box = libnacl.public.Box(sk.sk, pk.pk)
	return box.decrypt(data, nonce) if nonce else box.decrypt(data)

def sign(data, privkey):
	return privkey.sign(data)

def verify(data, pubkey):
	try:
		ret = libnacl.sign.Verifier(duniterpy.key.PublicKey(pubkey).hex_pk()).verify(data)
		sys.stderr.write("Signature OK!\n")
		return ret
	except ValueError:
		sys.stderr.write("Bad signature!\n")
		exit(1)

def get_privkey(privkey_path, privkey_format):
	if privkey_format == "pubsec":
		if privkey_path == "*":
			privkey_path = "privkey.pubsec"
		return duniterpy.key.SigningKey.from_pubsec_file(privkey_path)
	
	elif privkey_format == "cred":
		if privkey_path == "*":
			privkey_path = "-"
		if privkey_path == "-":
			return duniterpy.key.SigningKey.from_credentials(getpass.getpass("Salt: "), getpass.getpass("Password: "))
		else:
			return duniterpy.key.SigningKey.from_credentials_file(privkey_path)
	
	elif privkey_format == "seedh":
		if privkey_path == "*":
			privkey_path = "authfile.seedhex"
		return duniterpy.key.SigningKey.from_seedhex(read_data(privkey_path, False))
	
	elif privkey_format == "wif":
		if privkey_path == "*":
			privkey_path = "authfile.wif"
		return duniterpy.key.SigningKey.from_wif_or_ewif_file(privkey_path)
	
	elif privkey_format == "wifh":
		if privkey_path == "*":
			privkey_path = "authfile.wif"
		return duniterpy.key.SigningKey.from_wif_or_ewif_hex(privkey_path)
	
	elif privkey_format == "ssb":
		if privkey_path == "*":
			privkey_path = "secret"
		return duniterpy.key.SigningKey.from_ssb_file(privkey_path)
	
	elif privkey_format == "key":
		if privkey_path == "*":
			privkey_path = "authfile.key"
		return duniterpy.key.SigningKey.from_private_key(privkey_path)
	
	elif privkey_format == "ipfs-keystore":
		if privkey_path == "*":
			privkey_path = "key_self"
		return duniterpy.key.SigningKey(read_data(privkey_path)[4:36])
	
	print("Error: unknown privkey format")

def format_privkey(privkey, output_privkey_format):
	if output_privkey_format == "pubsec":
		return "Type: PubSec\nVersion: 1\npub: {}\nsec: {}".format(privkey.pubkey, base58.b58encode(privkey.sk).decode()).encode()
	
	elif output_privkey_format == "seedh":
		return privkey.hex_seed()
	
	elif output_privkey_format == "ipfs-keystore":
		return b"\x08\x01\x12@"+privkey.sk
	
	print("Error: unknown output privkey format")

def fill_pubkey(pubkey, length=32):
	while pubkey[0] == 0:
		pubkey = pubkey[1:]
	return b"\x00"*(length-len(pubkey)) + pubkey

def pubkey_checksum(pubkey, length=32, clength=3):
	return base58.b58encode(libnacl.crypto_hash_sha256(libnacl.crypto_hash_sha256(fill_pubkey(base58.b58decode(pubkey), length)))).decode()[:clength]

# returns (pubkey:bytes|None, deprecated_length:bool)
def check_pubkey(pubkey):
	if ":" in pubkey:
		parts = pubkey.split(":")
		if len(parts[1]) < 3 or len(parts[1]) > 32:
			return (None, False)
		for i in range(32, 0, -1):
			if pubkey_checksum(parts[0], i, len(parts[1])) == parts[1]:
				return (parts[0], i < 32)
		return (None, False)
	return (pubkey, False)

fmt = {
	"raw": lambda data: data,
	"16": lambda data: data.hex().encode(),
	"32": lambda data: base64.b32encode(data),
	"58": lambda data: base58.b58encode(data),
	"64": lambda data: base64.b64encode(data),
	"64u": lambda data: base64.urlsafe_b64encode(data),
	"85": lambda data: base64.b85encode(data),
}

defmt = {
	"raw": lambda data: data,
	"16": lambda data: bytes.fromhex(data),
	"32": lambda data: base64.b32decode(data),
	"58": lambda data: base58.b58decode(data),
	"64": lambda data: base64.b64decode(data),
	"85": lambda data: base64.b85decode(data),
}

def show_help():
	print("""Usage:
python3 natools.py <command> [options]

Commands:
  encrypt      Encrypt data
  decrypt      Decrypt data
  box-encrypt  Encrypt data (NaCl box)
  box-decrypt  Decrypt data (NaCl box)
  sign         Sign data
  verify       Verify data
  pubkey       Display pubkey
  privkey      Display private key
  pk           Display b58 pubkey shorthand

Options:
  -c         Display pubkey checksum
  -f <fmt>   Private key format (default: cred)
   key cred pubsec seedh ssb wif wifh ipfs-keystore
  -F <fmt>   Output private key format (default: pubsec)
   pubsec seedh ipfs-keystore
  -i <path>  Input file path (default: -)
  -I <fmt>   Input format: raw 16 32 58 64 85 (default: raw)
  -k <path>  Privkey file path (* for auto) (default: *)
  -n <nonce> Nonce (b64, 24 bytes) (for NaCl box)
  -N         Attach nonce to output (for NaCl box encryption)
  --noinc    Do not include msg after signature
  -o <path>  Output file path (default: -)
  -O <fmt>   Output format: raw 16 32 58 64 64u 85 (default: raw)
  -p <str>   Pubkey (base58)
  
  --help     Show help
  --version  Show version
  --debug    Debug mode (display full errors)

Note: "-" means stdin or stdout.
""")

if __name__ == "__main__":
	
	if "--help" in sys.argv:
		show_help()
		exit()
	
	if "--version" in sys.argv:
		print(__version__)
		exit()
	
	privkey_format = getargv("-f", "cred")
	output_privkey_format = getargv("-F", "pubsec")
	data_path = getargv("-i", "-")
	privkey_path = getargv("-k", "*")
	pubkey = getargv("-p")
	result_path = getargv("-o", "-")
	output_format = getargv("-O", "raw")
	input_format = getargv("-I", "raw")
	
	if pubkey:
		pubkey, len_deprecated = check_pubkey(pubkey)
		if not pubkey:
			print("Invalid pubkey checksum! Please check spelling.")
			exit(1)
		if len(base58.b58decode(pubkey)) > 32:
			print("Invalid pubkey: too long!")
			exit(1)
		if len_deprecated:
			print("Warning: valid pubkey checksum, but deprecated format (truncating zeros)")
	
	try:
		if sys.argv[1] == "encrypt":
			if not pubkey:
				print("Please provide pubkey!")
				exit(1)
			write_data(fmt[output_format](encrypt(defmt[input_format](read_data(data_path)), pubkey)), result_path)
		
		elif sys.argv[1] == "decrypt":
			write_data(fmt[output_format](decrypt(defmt[input_format](read_data(data_path)), get_privkey(privkey_path, privkey_format))), result_path)
		
		elif sys.argv[1] == "box-encrypt":
			if not pubkey:
				print("Please provide pubkey!")
				exit(1)
			nonce = getargv("-n", None)
			if nonce:
				nonce = base64.b64decode(nonce)
			attach_nonce = "-N" in sys.argv
			write_data(fmt[output_format](box_encrypt(defmt[input_format](read_data(data_path)), get_privkey(privkey_path, privkey_format), pubkey, nonce, attach_nonce)), result_path)
		
		elif sys.argv[1] == "box-decrypt":
			if not pubkey:
				print("Please provide pubkey!")
				exit(1)
			nonce = getargv("-n", None)
			if nonce:
				nonce = base64.b64decode(nonce)
			write_data(fmt[output_format](box_decrypt(defmt[input_format](read_data(data_path)), get_privkey(privkey_path, privkey_format), pubkey, nonce)), result_path)
		
		elif sys.argv[1] == "sign":
			data = defmt[input_format](read_data(data_path))
			signed = sign(data, get_privkey(privkey_path, privkey_format))
			
			if "--noinc" in sys.argv:
				signed = signed[:len(signed)-len(data)]
			
			write_data(fmt[output_format](signed), result_path)
		
		elif sys.argv[1] == "verify":
			if not pubkey:
				print("Please provide pubkey!")
				exit(1)
			write_data(fmt[output_format](verify(defmt[input_format](read_data(data_path)), pubkey)), result_path)
		
		elif sys.argv[1] == "pubkey":
			if pubkey:
				if "-c" in sys.argv and output_format == "58":
					write_data("{}:{}".format(pubkey, pubkey_checksum(pubkey)).encode(), result_path)
				else:
					write_data(fmt[output_format](base58.b58decode(pubkey)), result_path)
			else:
				pubkey = get_privkey(privkey_path, privkey_format).pubkey
				if "-c" in sys.argv and output_format == "58":
					write_data("{}:{}".format(pubkey, pubkey_checksum(pubkey)).encode(), result_path)
				else:
					write_data(fmt[output_format](base58.b58decode(pubkey)), result_path)
		
		elif sys.argv[1] == "privkey":
			privkey = get_privkey(privkey_path, privkey_format)
			write_data(fmt[output_format](format_privkey(privkey, output_privkey_format)), result_path)
		
		elif sys.argv[1] == "pk":
			if not pubkey:
				pubkey = get_privkey(privkey_path, privkey_format).pubkey
			if "-c" in sys.argv:
				print("{}:{}".format(pubkey, pubkey_checksum(pubkey)))
			else:
				print(pubkey)
		
		else:
			show_help()
		
	except Exception as e:
		if "--debug" in sys.argv:
			0/0 # DEBUG MODE (raise error when handling error to display backtrace)
		sys.stderr.write("Error: {}\n".format(e))
		show_help()
		exit(1)
