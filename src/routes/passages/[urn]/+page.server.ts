import fs from 'fs';
import YAML from 'yaml';
import { error } from '@sveltejs/kit';

import { parseCommentaryMarkdown } from '$lib/pipelines/commentary.js';

import type { Card, Comment, Line } from '$lib/types/commentary.type';

export const prerender = true;

const COMMENTARIES_DIR = fs.readdirSync('commentaries');
const PASSAGE_DIR = fs.readdirSync('passages');

export const load = async ({ params: { urn = '' } }) => {
	const [_urn_s, _cts, collection, workComponent, passageComponent] = urn.split(':');
	const [textGroup, work, _version] = workComponent.split('.');
	const startPassage = passageComponent.split('-')[0];
	const withoutSubsection = startPassage.split('@')[0];
	const startBook = withoutSubsection.split('.')[0];

	// get all matching passages, regardless of version
	const regexp = new RegExp(`urn:cts:${collection}:${textGroup}.${work}.\*:${startBook}`);

	const relevantFiles = PASSAGE_DIR.filter((f) => {
		return regexp.test(f);
	});

	if (relevantFiles.length === 0) {
		return error(404);
	}

	if (!passageComponent) {
		return error(404);
	}

	const commentaryRegexp = new RegExp(`${textGroup}.${work}\*\.md$`)

	const comments = COMMENTARIES_DIR.filter(f => {
		return commentaryRegexp.test(f);
	}).flatMap(f => {
		const commentaryFile = `commentaries/${f}`;
		const { comments, metadata } = parseCommentaryMarkdown(commentaryFile);

		return comments;
	}).filter((c: Comment) => {
		const cStartBook = c.citation.split('.')[0];

		return cStartBook === startBook;
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
		comments: comments.flat(),
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
