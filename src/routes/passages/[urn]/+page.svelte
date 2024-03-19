<script lang="ts">
	import type { Card, Comment } from '$lib/types/commentary.type';

	import CollapsibleComment from '$lib/components/CollapsibleComment.svelte';
	import CitableTextContainer from '$lib/components/CitableTextContainer.svelte';
	import TranslationCard from '$lib/components/TranslationCard.svelte';
	import { base } from '$app/paths';

	export let data;

	$: metadata = data.metadata;
	$: cards = data.cards;
	$: comments = data.comments;
	$: lines = data.lines;
	$: urn = data.urn;
	$: versionUrn = urn.split(':').slice(0, -1).join(':');
	$: citation = urn.split(':').at(-1);

	function getCommentsForLine(n: string) {
		return comments.filter((comment: Comment) => {
			const [start, _end] = comment.citation.split('-');
			const [_startBook, startLine] = start.split('.');

			if (n === startLine) {
				return true;
			}

			return false;
		});
	}

	function highlightComments(e: CustomEvent) {
		const commentsToHighlight = e.detail;
		let foundComment: Comment | undefined;

		comments = comments.map((comment: Comment) => {
			if (commentsToHighlight.includes(comment.citable_urn)) {
				if (!foundComment) {
					foundComment = comment;
				}

				return {
					...comment,
					isHighlighted: true
				};
			}

			return {
				...comment,
				isHighlighted: false
			};
		});

		if (foundComment) {
			document.getElementById(foundComment.citable_urn)?.scrollIntoView({ behavior: 'smooth' });
		}
	}

	function scrollTranslationIntoView(e: CustomEvent) {
		const lineN = e.detail;

		const card = cards.find((card: Card) => {
			if (lineN === card.n) {
				return true;
			}

			const intN = parseInt(lineN);

			if (parseInt(card.n) <= intN && parseInt(card.next_n) - 1 >= intN) {
				return true;
			}

			return false;
		});

		const translationEl = document.getElementById(`translation:${card.n}-${card.next_n}`);

		if (translationEl) {
			translationEl.scrollIntoView({ behavior: 'smooth' });
		}
	}
</script>

<article class="mx-auto w-full">
	<div class="pb-8">
		<h1 class="text-2xl font-bold">{metadata.title}</h1>

		<p>{metadata.description}</p>
	</div>
	<div class="grid grid-cols-8 gap-x-8 gap-y-2">
		<section class="col-span-1">
			<ul class="menu bg-base-200 p-0">
				{#each [...Array.from({ length: 24 }, (_, i) => i + 1)] as n}
					<li class="text-sm">
						<a href="{base}/passages/{versionUrn}:{n}" class:active={n == parseInt(citation || '')}>
							Scroll {n}
						</a>
					</li>
				{/each}
			</ul>
		</section>
		<section class="col-span-3 overflow-y-scroll px-4 max-h-screen">
			{#each lines as line (line.n)}
				<CitableTextContainer
					citation={line.n}
					commentUrns={getCommentsForLine(line.n).map((c) => c.citable_urn)}
					text={line.text}
					on:highlightComments={highlightComments}
					on:scrollTranslationIntoView={scrollTranslationIntoView}
				/>
			{/each}
		</section>
		<section class="overflow-y-scroll col-span-2 max-h-screen">
			{#each comments as comment}
				<CollapsibleComment {comment} />
			{/each}
		</section>
		<section class="overflow-y-scroll col-span-2 max-h-screen">
			{#each cards as card (card.n)}
				<TranslationCard n={card.n} nextN={card.next_n} xmlContent={card.xml_content} />
			{/each}
		</section>
	</div>
</article>
