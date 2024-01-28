import fs from 'fs';
import { error } from '@sveltejs/kit';

import type { Comment, Tag } from '$lib/types/commentary.type';

export const prerender = true;

export const load = ({ params: { urn = '' } }) => {
	const passageDir = fs.readdirSync('passages');
	const relevantFiles = passageDir.filter((f) => {
		return f.startsWith(`${urn}_`);
	});

	if (relevantFiles.length === 0) {
		return error(404);
	}

	const cardsFile = relevantFiles.find((f) => f.endsWith('_cards.json'));
	const commentsFile = relevantFiles.find((f) => f.endsWith('_comments.json'));
	const linesFile = relevantFiles.find((f) => f.endsWith('_lines.json'));
	const metadataFile = relevantFiles.find((f) => f.endsWith('_metadata.json'));
	const notesFile = relevantFiles.find((f) => f.endsWith('_notes.json'));
	const speechesFile = relevantFiles.find((f) => f.endsWith('_speeches.json'));

	return {
		cards: cardsFile ? getCards(cardsFile) : [],
		comments: commentsFile ? readFile(commentsFile).sort((a: Comment, b: Comment) => {
			const urnA = a.target_urn;
			const urnB = b.target_urn;

			const citationA = urnA.split(':').at(-1);
			const startA = citationA?.split('-')[0];
			const startLineA = startA?.split('.').at(-1) || '0';

			const citationB = urnB.split(':').at(-1);
			const startB = citationB?.split('-')[0];
			const startLineB = startB?.split('.').at(-1) || '0';

			return parseInt(startLineA) < parseInt(startLineB) ? -1 : 1
		}) : [],
		lines: linesFile ? readFile(linesFile) : [],
		metadata: metadataFile ? readFile(metadataFile) : [],
		notes: notesFile ? readFile(notesFile) : [],
		speeches: speechesFile ? readFile(speechesFile) : [],
		tags: commentsFile ? readFile(commentsFile).map((c: Comment) => c.tags.map((t: Tag) => t.name)) : [],
		urn
	};
};

function getCards(f: string) {
	const exists = fs.existsSync(`passages/${f}`);

	if (!exists) {
		return null;
	}

	return JSON.parse(fs.readFileSync(`passages/${f}`).toString('utf-8'));
}

function readFile(f: string) {
	return JSON.parse(fs.readFileSync(`passages/${f}`).toString('utf-8'));
}
