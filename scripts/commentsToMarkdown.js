import fs from 'fs';
import path from 'path';
import { Eta } from 'eta';

const COMMENTS_JSONL = './ahcip.jsonl';
const COMMENTS_DIR = './commentaries';

const eta = new Eta({ views: path.join('./templates') });

function commentsToMarkdown() {
	const grouped = fs
		.readFileSync(COMMENTS_JSONL)
		.toString('utf-8')
		.split('\n')
		.filter((l) => l.trim() !== '')
		.reduce((acc, raw) => {
			const comment = JSON.parse(raw);
			const [_urn, _cts, _collection, workComponent, _passageComponent] = comment.urn.split(':');
			const [textGroup, work, _version] = workComponent.split('.');
			const key = `${textGroup}.${work}`;

			return {
				...acc,
				[key]: (acc[key] || []).concat(comment)
			};
		}, {});

	Object.keys(grouped).forEach((key) => {
		const destFile = `${COMMENTS_DIR}/${key}.md`;

		let allAuthors = [];

		const comments = grouped[key]
			.map((comment) => {
				const [_urn, _cts, _collection, _workComponent, citation] = comment.urn.split(':');
				const authors = comment.users.map((user) => {
					const author = {
						...user,
						name: nameFromUsername(user.username)
					};

					if (typeof allAuthors.find((a) => a.username === user.username) === 'undefined') {
						allAuthors.push(author);
					}

					return author;
				});

				return {
					...comment,
					authors,
					citation,
					urn: comment.urn
				};
			})
			.sort((a, b) => a.citation - b.citation);

		const commentary = {
			urn: `urn:cts:greekLit:${key}.ahcip`,
			target_urn: `urn:cts:greekLit:${key}.perseus-grc2`,
			comments,
			allAuthors
		};
		const rendered = eta.render('./commentary.md.eta', commentary);

		fs.writeFileSync(`${destFile}`, rendered);
	});
}

function nameFromUsername(username) {
	switch (username) {
		case 'ahanhardt':
			return 'Angelia Hanhardt';
		case 'anikkanen':
			return 'Anita Nikkanen';
		case 'cldue':
			return 'Casey Dué Hackney';
		case 'cpache':
			return 'Corinne Pache';
		case 'delmer':
			return 'David Elmer';
		case 'dframe':
			return 'Douglas Frame';
		case 'gnagy':
			return 'Gregory Nagy';
		case 'lmuellner':
			return 'Leonard Muellner';
		case 'lslatkin':
			return 'Laura Slatkin';
		case 'mebbott':
			return 'Mary Ebbott';
		case 'olevaniouk':
			return 'Olga Levaniouk';
		case 'rmartin':
			return 'Richard Martin';
		case 'twalsh':
			return 'Thomas Walsh';
		case 'ypetropoulos':
			return 'Yiannis Petropoulos';
		case 'zrothstein-dowden':
			return 'Zachary Rothstein-Dowden';
		default:
			return username;
	}
}

commentsToMarkdown();
