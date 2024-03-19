import fs from 'fs';
import { marked } from 'marked';
import YAML from 'yaml';

import extractProperties from '$lib/vendor/extractProperties';
import type { Author } from '$lib/types/commentary.type';

type RawCommentProperties = {
    authors: string;
    citation: string;
    tags: string;
};

export function parseCommentaryMarkdown(
    f: string
): { comments: Array<any>; metadata: any } {
    const raw = fs.readFileSync(f).toString('utf-8');
    const [_emptyString, rawMetadata, ...rawComments] = raw.split('---\n');
    const metadata = YAML.parse(rawMetadata);

    const comments = rawComments.map((rawComment) => {
        const comment = { text: null, properties: {} as RawCommentProperties };
        const text = extractProperties(rawComment, comment.properties);

        if (text === '') {
            return false;
        }

        return {
            ...comment,
            ...metadata,
            authors: comment.properties.authors
                ?.split(', ')
                .map((a) => metadata.authors.find((ma: Author) => ma.username === a)),
            citable_urn: `${metadata.urn}:${comment.properties.citation}`,
            citation: comment.properties.citation,
            tags: comment.properties.tags?.split(', '),
            text: marked(text)
        };
    }).filter(c => Boolean(c));

    return { comments, metadata };
}
