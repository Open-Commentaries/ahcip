/**

`extractProperties()` comes from the [remark](https://github.com/gnab/remark/blob/develop/src/remark/parser.js)
project's `parser.js` with the following license:

Copyright (c) 2011-2013 Ole Petter Bang <olepbang@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/**
 *
 * @param {string} source
 * @param {any} properties
 * @returns
 */

export default function extractProperties(source, properties) {
	var propertyFinder = /^\n*([-\w]+):([^$\n]*)|\n*(?:<!--\s*)([-\w]+):([^$\n]*?)(?:\s*-->)/i,
		match;

	while ((match = propertyFinder.exec(source)) !== null) {
		source = source.substr(0, match.index) + source.substr(match.index + match[0].length);

		if (match[1] !== undefined) {
			properties[match[1].trim()] = match[2].trim();
		} else {
			properties[match[3].trim()] = match[4].trim();
		}

		propertyFinder.lastIndex = match.index;
	}

	return source;
}
