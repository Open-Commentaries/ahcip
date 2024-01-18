<script lang="ts">
	import type { Comment } from '$lib/types/commentary.type';

	export let comment: Comment;

	let isHighlighted = false;
</script>

<div
	class="border-2 collapse collapse-arrow rounded-sm mb-2"
	class:border-slate-800={isHighlighted}
>
	<input type="checkbox" />
	<div class="collapse-title">
		<h3 class="text-sm font-medium text-slate-900 cursor-pointer">
			<span class="text-sm font-light text-slate-600">
				{comment.title}
			</span>
		</h3>
		<h4 class="text-sm font-medium text-slate-900 cursor-pointer">
			<small class="mt-1 mx-w-2xl text-sm text-slate-600">
				<a href={'/bibliography/#{@comment.canonical_commentary.pid}'} class="hover:underline">
					{comment.authors.map((a) => a.name).join(', ')}
				</a>
			</small>
		</h4>
	</div>
	<div class="collapse-content float-right">
		<p class="max-w-2xl text-sm text-gray-800">{@html comment.body}</p>
	</div>
</div>
