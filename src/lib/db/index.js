// import type { Database } from "$lib/types/database.type";

import { parseUrn } from 'cts-urn';

// type TextContainer = {
//     id: string;
//     content: string;
//     tokens: string[];
// }

const DTS_API_BASE_URL = 'https://dts.perseids.org';

/**
 *
 * @param {string} passageUrn
 * @returns
 */
export default async function init(passageUrn) {
	const parsedUrn = parseUrn(passageUrn);
	const response = await fetch(
		`${DTS_API_BASE_URL}/documents?id=${parsedUrn.urn}:${parsedUrn.cts}:${parsedUrn.ctsNamespace}:${parsedUrn.work.textGroup}.${parsedUrn.work.work}.${parsedUrn.work.version}`
	);
	const passageXml = await response.text();

	console.log(passageXml);

	return {
		comments: [],
		notes: [],
		translations: [],
		textContainers: []
	};
}

function main() {
	init('urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:1');
}

main();
