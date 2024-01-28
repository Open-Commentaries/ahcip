import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	preprocess: vitePreprocess(),

	kit: {
		adapter: adapter({
			pages: 'build',
			assets: 'build',
			fallback: undefined,
			precompress: false,
			strict: false
		}),
		paths: {
			base: process.argv.includes('dev') ? '' : process.env.BASE_PATH
		},
		prerender: {
			entries: [
				'*',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:1',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:2',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:3',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:4',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:5',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:6',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:7',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:8',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:9',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:10',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:11',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:12',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:13',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:14',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:15',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:16',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:17',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:18',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:19',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:20',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:21',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:22',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:23',
				'/passages/urn:cts:greekLit:tlg0012.tlg001.perseus-grc2:24',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:1',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:2',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:3',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:4',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:5',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:6',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:7',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:8',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:9',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:10',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:11',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:12',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:13',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:14',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:15',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:16',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:17',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:18',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:19',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:20',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:21',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:22',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:23',
				'/passages/urn:cts:greekLit:tlg0012.tlg002.perseus-grc2:24'
			],
			handleHttpError: 'warn'
		}
	}
};

export default config;
