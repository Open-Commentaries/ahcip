import fs from 'fs';
import path from 'path';
import snakeCase from 'lodash.snakecase';
import { Eta } from 'eta';

const COMMENTS_JSONL = './ahcip.jsonl';
const COMMENTS_DIR = './comments';

const eta = new Eta({ views: path.join('./templates') });

function commentsToMarkdown() {
	const grouped = fs
		.readFileSync(COMMENTS_JSONL)
		.toString('utf-8')
		.split('\n')
		.filter((l) => l.trim() !== '')
		.reduce((acc, raw) => {
			const comment = JSON.parse(raw);
			const [_urn, _cts, _collection, workComponent, passageComponent] = comment.urn.split(':');
			const [textGroup, work, _version] = workComponent.split('.');
			const startPassage = passageComponent.split('-')[0];
			const withoutSubsection = startPassage.split('@')[0];
			const startBook = withoutSubsection.split('.')[0];
			const key = `${textGroup}:${work}:${startBook}`;

			return {
				...acc,
				[key]: (acc[key] || []).concat(comment)
			};
		}, {});

	Object.keys(grouped).forEach((key) => {
		const passageDir = `${COMMENTS_DIR}/${key}`;

		try {
			fs.mkdirSync(passageDir, true);
		} catch (e) {
			if (e.code !== 'EEXIST') {
				throw e;
			}
		}

		grouped[key].forEach((comment) => {
			const authors = comment.users.map((user) => {
				return {
					...user,
					name: nameFromUsername(user.username)
				};
			});

			const rendered = eta.render('./comment.md.eta', {
				...comment,
				authors
			});

			const title = snakeCase(comment.citable_urn);
			const dest = `${passageDir}/${title}.md`;

			if (fs.existsSync(dest)) {
				console.warn('File already exists!', comment.title, authors);
			}

			fs.writeFileSync(dest, rendered);
		});
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
