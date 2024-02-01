import fs from 'fs';
import YAML from 'yaml';
import { error } from '@sveltejs/kit';

import type { Card, Comment, Line } from '$lib/types/commentary.type';

export const prerender = true;

export const load = ({ params: { urn = '' } }) => {
	const passageDir = fs.readdirSync('passages');
	const relevantFiles = passageDir.filter((f) => {
		return f.startsWith(`${urn}_`);
	});

	if (relevantFiles.length === 0) {
		return error(404);
	}

	const [_urn, _cts, _collection, workComponent, passageComponent] = urn.split(':');

	if (!passageComponent) {
		return error(404);
	}

	const [textGroup, work, _version] = workComponent.split('.');
	const startPassage = passageComponent.split('-')[0];
	const withoutSubsection = startPassage.split('@')[0];
	const startBook = withoutSubsection.split('.')[0];
	const commentsDir = `comments/${textGroup}:${work}:${startBook}`;

	const commentFiles = fs.readdirSync(commentsDir);
	const comments = commentFiles
		.map((file) => {
			const raw = fs.readFileSync(`${commentsDir}/${file}`).toString('utf-8');
			const [_, yaml, body] = raw.split('+++');
			const attrs = YAML.parse(yaml);

			return {
				...attrs,
				body
			};
		})
		.sort((a: Comment, b: Comment) => {
			const urnA = a.target_urn;
			const urnB = b.target_urn;

			const citationA = urnA.split(':').at(-1);
			const startA = citationA?.split('-')[0];
			const startLineA = startA?.split('.').at(-1);

			const citationB = urnB.split(':').at(-1);
			const startB = citationB?.split('-')[0];
			const startLineB = startB?.split('.').at(-1);

			if (startLineA && startLineB) {
				return parseInt(startLineA) < parseInt(startLineB) ? -1 : 1;
			}

			if (!startLineA) return -1;

			if (!startLineB) return 1;

			return 0;
		});

	const cardsFile = relevantFiles.find((f) => f.endsWith('_cards.json'));
	const linesFile = relevantFiles.find((f) => f.endsWith('_lines.json'));
	const metadataFile = relevantFiles.find((f) => f.endsWith('_metadata.json'));
	const notesFile = relevantFiles.find((f) => f.endsWith('_notes.json'));
	const speechesFile = relevantFiles.find((f) => f.endsWith('_speeches.json'));

	return {
		cards: cardsFile ? getCards(cardsFile).sort((cardA: Card, cardB: Card) => {
			return parseInt(cardA.n) < parseInt(cardB.n) ? -1 : 1;
		}) : [],
		comments,
		lines: linesFile ? readFile(linesFile).sort((lineA: Line, lineB: Line) => {
			return parseInt(lineA.n) < parseInt(lineB.n) ? -1 : 1;
		}) : [],
		metadata: metadataFile ? readFile(metadataFile) : [],
		notes: notesFile ? readFile(notesFile) : [],
		speeches: speechesFile ? readFile(speechesFile) : [],
		tags: comments.length > 0 ? comments.map((c: Comment) => c.tags).flat() : [],
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
