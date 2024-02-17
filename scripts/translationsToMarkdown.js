import fs from 'fs';
import path from 'path';
import { Eta } from 'eta';

import URNS from '../bibliography/urns.js';

const PASSAGES_DIR = './passages';
const TRANSLATIONS_DIR = './translations';

const eta = new Eta({ views: path.join('./templates') });

function translationsToMarkdown() {
	fs.readdirSync(PASSAGES_DIR)
		.filter((passage) => passage.endsWith('_cards.json'))
		.forEach((f) => {
			const [urn, _cards_s] = f.split('_');
			const [_urn, _cts, _collection, workComponent, passageComponent] = urn.split(':');
			const [textGroup, work, _version] = workComponent.split('.');
			const startPassage = passageComponent?.split('-')[0];
			const withoutSubsection = startPassage?.split('@')[0];
			const startBook = withoutSubsection?.split('.')[0];
			const key = `${textGroup}:${work}${startBook ? ':' + startBook : ''}`;

			const translationCards = JSON.parse(
				fs.readFileSync(`${PASSAGES_DIR}/${f}`).toString('utf-8')
			);

			const filename = `${TRANSLATIONS_DIR}/${key}.md`;

			try {
				fs.unlinkSync(filename);
			} catch (_e) {}

			translationCards.forEach((card) => {
				const cardUrn = `urn:cts:greekLit:${workComponent}`;
				const info = URNS[cardUrn];

				console.log(cardUrn);

				const rendered = eta.render('./translation.md.eta', {
					authors: info.authors,
					text: card.xml_content,
					title: info.title,
					urn: `${cardUrn}:${startBook}`
				});

				fs.appendFileSync(filename, rendered);
				fs.appendFileSync(filename, '\n\n');
			});
		});
}

function main() {
	fs.mkdirSync(TRANSLATIONS_DIR, { recursive: true });

	translationsToMarkdown();
}

main();
