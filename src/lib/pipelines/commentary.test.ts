import { expect, test } from 'vitest';
import { parseCommentaryMarkdown } from './commentary';

const COMMENTARY = __dirname + '/commentary.test.md';

test('parses the YAML metadata', async () => {
    const { comments, metadata } = await parseCommentaryMarkdown(COMMENTARY);

    expect(comments.length).toEqual(2);
    expect(comments[0].properties.authors.length).toBeGreaterThan(0)
    expect(metadata.authors.length).toEqual(2)
});
