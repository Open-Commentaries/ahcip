<script lang="ts">
	import type { Card } from '$lib/types/commentary.type';

	import { createEventDispatcher } from 'svelte';
	import TranslationIcon from '$lib/icons/TranslationIcon.svelte';

	const dispatch = createEventDispatcher();

	export let citation: string;
	export let commentUrns: string[];
	export let text: string;
</script>

<div class="align-baseline flex justify-between w-full">
	<p class="max-w-prose w-3/4 indent-hanging">
		{text}
	</p>
	{#if commentUrns.length > 0}
		<a
			href={`#${citation}`}
			role="button"
			class="bg-secondary hover:opacity-70 w-6 text-center"
			on:click={() => dispatch('highlightComments', commentUrns)}
			data-citation={citation}>{citation}</a
		>
	{:else}
		<span class="text-center w-6">{citation}</span>
	{/if}
	<a
		href={`#${citation}-translation`}
		role="button"
		class="mr-4"
		on:click={() => dispatch('scrollTranslationIntoView', citation)}
		title="Scroll translation into view"
	>
		<TranslationIcon className="h-5 w-5 text-secondary-content hover:opacity-80" />
	</a>
</div>

<style>
	.indent-hanging {
		text-indent: 2.3rem hanging;
	}
</style>
