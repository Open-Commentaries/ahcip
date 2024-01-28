<script lang="ts">
	import type { Comment, Line } from '$lib/types/commentary.type';

	import { base } from '$app/paths';

	import CollapsibleComment from '$lib/components/CollapsibleComment.svelte';

	export let data;

	$: metadata = data.metadata;
	$: comments = data.comments;
	$: lines = data.lines;
	$: urn = data.urn;
	$: versionUrn = urn.split(':').slice(0, -1).join(':');
	$: citation = urn.split(':').at(-1);

	function getCommentsForLine(line: Line) {
		return comments.filter((comment: Comment) => {
			const [_urn, _cts, _collection, _workComponent, citation] = comment.target_urn.split(':');
			const [start, _end] = citation.split('-');
			const [_startBook, startLine] = start.split('.');

			if (line.n === startLine) {
				return true;
			}

			return false;
		});
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
						<a
							href="/{base}/passages/{versionUrn}:{n}"
							class={n == parseInt(citation || '') ? 'active' : ''}
						>
							Scroll {n}
						</a>
					</li>
				{/each}
			</ul>
		</section>
		<section class="col-span-2">
			{#each lines as line}
				<p>{line.n} {line.text}</p>
			{/each}
		</section>
		<section class="overflow-y-scroll col-span-2 max-w-96 max-h-[64rem]">
			{#each comments as comment}
				<CollapsibleComment {comment} />
			{/each}
		</section>
	</div>
</article>
