<script lang="ts">
	import type { Comment } from '$lib/types/commentary.type';

	import CollapsibleComment from '$lib/components/CollapsibleComment.svelte';
	import { base } from '$app/paths';

	export let data;

	$: metadata = data.metadata;
	$: comments = data.comments;
	$: lines = data.lines;
	$: urn = data.urn;
	$: versionUrn = urn.split(':').slice(0, -1).join(':');
	$: citation = urn.split(':').at(-1);

	function getCommentsForLineNumber(n: string) {
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

	function highlightComments(e: MouseEvent) {
		// @ts-expect-error
		const n = e.target?.dataset?.n;
		const commentsToHighlight = getCommentsForLineNumber(n).map((c) => c.citable_urn);
		let foundComment: Comment | undefined;

		comments = comments.map((comment) => {
			if (commentsToHighlight.includes(comment.citable_urn)) {
				foundComment = comment;

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
			<ul class="menu bg-base-200 p-0 max-w-48 [&_li>*]:rounded-none">
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
				<p>
					{line.text}
					{#if getCommentsForLineNumber(line.n).length > 0}
						<button
							class="bg-slate-300 hover:bg-slate-500 float-right w-8"
							on:click={highlightComments}
							data-n={line.n}>{line.n}</button
						>
					{:else}
						<span class="float-right text-center w-8">{line.n}</span>
					{/if}
				</p>
			{/each}
		</section>
		<section class="overflow-y-scroll col-span-2 max-w-96 max-h-[64rem]">
			{#each comments as comment (comment.citable_urn)}
				<CollapsibleComment {comment} />
			{/each}
		</section>
	</div>
</article>
