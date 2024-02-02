<script lang="ts">
	import type { Card, Comment } from '$lib/types/commentary.type';

	import CollapsibleComment from '$lib/components/CollapsibleComment.svelte';
	import CitableTextContainer from '$lib/components/CitableTextContainer.svelte';
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
			const [_urn, _cts, _collection, _workComponent, citation] = comment.target_urn.split(':');
			const [start, _end] = citation.split('-');
			const [_startBook, startLine] = start.split('.');

			if (n === startLine) {
				return true;
			}

			return false;
		});
	}

	function getTranslationsForLine(n: string) {
		return cards.filter((card: Card) => {
			if (n === card.n) {
				return true;
			}

			const intN = parseInt(n);

			if (intN >= parseInt(card.n) && intN <= parseInt(card.next_n)) {
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
</script>

<article class="mx-auto">
	<div class="grid grid-cols-5 gap-x-8 gap-y-2">
		<div class="col-span-5">
			<h1 class="text-2xl font-bold">{metadata.title}</h1>

			<p>{metadata.description}</p>
		</div>
		<section class="col-span-1">
			<ul class="menu bg-base-200 p-0 max-w-48">
				{#each [...Array.from({ length: 24 }, (_, i) => i + 1)] as n}
					<li class="text-sm">
						<a href="{base}/passages/{versionUrn}:{n}" class:active={n == parseInt(citation || '')}>
							Scroll {n}
						</a>
					</li>
				{/each}
			</ul>
		</section>
		<section class="col-span-2">
			{#each lines as line}
				<CitableTextContainer
					citation={line.n}
					commentUrns={getCommentsForLine(line.n).map((c) => c.citable_urn)}
					on:highlightComments={highlightComments}
					text={line.text}
					translations={getTranslationsForLine(line.n)}
				/>
			{/each}
		</section>
		<section class="overflow-y-scroll col-span-2 max-w-96 max-h-[64rem]">
			{#each comments as comment (comment.citable_urn)}
				<CollapsibleComment {comment} />
			{/each}
		</section>
	</div>
</article>
