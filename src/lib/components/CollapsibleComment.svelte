<script lang="ts">
	import type { Comment } from '$lib/types/commentary.type';

	export let comment: Comment;

	$: isHighlighted = comment.isHighlighted;
</script>

<div
	class="border-2 collapse collapse-arrow rounded-sm mb-2"
	class:border-secondary={isHighlighted}
	id={comment.citable_urn}
>
	<input type="checkbox" />
	<div class="collapse-title">
		<h3 class="text-sm font-medium text-primary-content cursor-pointer">
			<span class="text-sm font-light text-slate-600">
				{comment.title}
			</span>
		</h3>
		<h4 class="text-sm font-medium text-primary-content cursor-pointer">
			<small class="mt-1 mx-w-2xl text-sm text-slate-600">
				{comment.authors.map((a) => a.name).join(', ')}
			</small>
		</h4>
	</div>
	<div class="collapse-content float-right">
		<p class="max-w-2xl text-sm text-gray-800">{@html comment.body}</p>
	</div>
</div>
