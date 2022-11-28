export {b58,b16, saltPass2seed, seed2keyPair,idSecPass2rawAll, raw2b58, idSecPass2cleanKeys}
import {nacl} from "./vendors/nacl.js";

async function idSecPass2rawAll(idSec,pass) {
	const rawSeed = await saltPass2seed(idSec,pass);
	const keyPair = seed2keyPair(rawSeed);
	return {
		seed:rawSeed,
		publicKey:keyPair.publicKey,
		secretKey:keyPair.secretKey
	}
}
function raw2b58(raws){
	const res = {};
	for(let r in raws) res[r] = b58.encode(raws[r]);
	return res;
}
async function idSecPass2cleanKeys(idSec,pass){
	const raw = await idSecPass2rawAll(idSec,pass);
	return Object.assign(raw2b58(raw),{idSec,password:pass});
}
function seed2keyPair(seed){
	return nacl.sign.keyPair.fromSeed(seed);
}
import scrypt from "./vendors/scrypt.js";
async function saltPass2seed(idSec,pass) {
	const options = {
		logN: 12,
		r: 16,
		p: 1,
		//dkLen: 32,
		encoding: 'binary'
	};
	return await scrypt(pass.normalize('NFKC'), idSec.normalize('NFKC'), options);
}
//inspired by bs58 and base-x module
const ALPHABET = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
const b58 = basex(ALPHABET);
const b16 = basex('0123456789abcdef');
function basex (ALPHABET) {
	const ALPHABET_MAP = {};
	const BASE = ALPHABET.length;
	const LEADER = ALPHABET.charAt(0);
	// pre-compute lookup table
	for (let z = 0; z < ALPHABET.length; z++) {
		let x = ALPHABET.charAt(z);
		if (ALPHABET_MAP[x] !== undefined) throw new TypeError(x + ' is ambiguous');
		ALPHABET_MAP[x] = z;
	}
	function encode (source) {
		if (source.length === 0) return '';
		const digits = [0];
		for (let i = 0; i < source.length; ++i) {
			let carry = source[i];
			for (let j = 0; j < digits.length; ++j) {
				carry += digits[j] << 8;
				digits[j] = carry % BASE;
				carry = (carry / BASE) | 0;
			}
			while (carry > 0) { digits.push(carry % BASE); carry = (carry / BASE) | 0; }
		}
		let string = '';
		for (let k = 0; source[k] === 0 && k < source.length - 1; ++k) string += LEADER; // deal with leading zeros
		for (let q = digits.length - 1; q >= 0; --q) string += ALPHABET[digits[q]]; // convert digits to a string
		return string;
	}

	function decodeUnsafe (string) {
		if (typeof string !== 'string') throw new TypeError('Expected String');
		if (string.length === 0) return new Uint8Array(0);
		const bytes = [0];
		for (let i = 0; i < string.length; i++) {
			const value = ALPHABET_MAP[string[i]];
			if (value === undefined) return ;
			let carry = value;
			for (let j = 0; j < bytes.length; ++j) {
				carry += bytes[j] * BASE;
				bytes[j] = carry & 0xff;
				carry >>= 8;
			}
			while (carry > 0) { bytes.push(carry & 0xff); carry >>= 8; }
		}
		for (let k = 0; string[k] === LEADER && k < string.length - 1; ++k)  bytes.push(0); // deal with leading zeros
		return new Uint8Array(bytes.reverse());
	}
	function decode (string) {
		const buffer = decodeUnsafe(string);
		if (buffer) return buffer;
		throw new Error('Non-base' + BASE + ' character')
	}
	return { encode, decodeUnsafe, decode }
}
