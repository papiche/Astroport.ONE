import * as dKey from "./crypto.js";

addEventsListeners([
		document.getElementById("idSec"),
		document.getElementById("pass"),
	], "keyup change",
	async function () {
		const idSec = document.getElementById("idSec").value;
		const pass = document.getElementById("pass").value;
		const keys = await dKey.idSecPass2cleanKeys(idSec, pass);
		document.getElementById("seed").value = keys.seed;
		document.getElementById("secretkey").value = keys.secretKey;
		document.getElementById("pubkey").value = keys.publicKey;

	});
addEventsListeners([
		document.getElementById("seed"),
	], "keyup change",
	async function () {
		let rawSeed;
		const seed = document.getElementById("seed").value;
		console.log(seed.length);
		if (seed.length === 64) rawSeed = dKey.b16.decode(seed);
		else rawSeed = dKey.b58.decode(seed);
		const keys = await dKey.seed2keyPair(rawSeed);
		document.getElementById("secretkey").value = dKey.b58.encode(keys.secretKey);
		document.getElementById("pubkey").value = dKey.b58.encode(keys.publicKey);
	});
addEventsListeners([
		document.getElementById("compute"),
	], "click",
	async function () {
		const filename = document.getElementById("filename").value;
		const secretkey = document.getElementById("secretkey").value;
		const pubkey = document.getElementById("pubkey").value;
		exportAsFile(filename, `pub: ${pubkey}\nsec: ${secretkey}`);
	});

function exportAsFile(fileName, data) {
	const a = document.createElement('a');
	a.setAttribute('download', fileName + '.dunikey.yml');
	a.setAttribute('href', 'data:text/yaml;charset=utf-8,' + encodeURIComponent(data));
	clickOn(a);
}
function clickOn(element) {
	const event = new MouseEvent('click', {'view': window, 'bubbles': true, 'cancelable': true});
	element.dispatchEvent(event);
}
function addEventsListeners(triggerNodes, events, functions) {
	if (!triggerNodes.length) triggerNodes = [triggerNodes];
	if (typeof events !== "object") events = events.split(" ");
	if (typeof functions !== "object") functions = [functions];
	for (let n of triggerNodes) events.forEach(e => functions.forEach(f => n.addEventListener(e, f)));
}
