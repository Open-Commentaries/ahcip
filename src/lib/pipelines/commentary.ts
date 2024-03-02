import fs from 'fs';
import { marked } from 'marked';
import YAML from 'yaml';

import extractProperties from '$lib/vendor/extractProperties';

export async function parseCommentaryMarkdown(f: string): Promise<{ comments: Array<any>, metadata: any }> {
    const raw = fs.readFileSync(f).toString('utf-8');
    const [_emptyString, rawMetadata, ...rawComments] = raw.split('---\n');
    const metadata = YAML.parse(rawMetadata);

    const comments = rawComments.map(rawComment => {
        const comment = { text: null, properties: {} }
        const text = extractProperties(rawComment, comment.properties);

        return {
            ...comment,
            text: marked(text),
        };
    })

    return { comments, metadata };
}

parseCommentaryMarkdown(__dirname + '/commentary.test.md')
