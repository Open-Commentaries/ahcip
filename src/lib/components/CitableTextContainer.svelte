<script lang="ts">
	import type { Card } from '$lib/types/commentary.type';

	import { createEventDispatcher } from 'svelte';
	import TranslationIcon from '$lib/icons/TranslationIcon.svelte';

	const dispatch = createEventDispatcher();

	export let citation: string;
	export let commentUrns: string[];
	export let text: string;
</script>

<div class="align-baseline">
	<button class="float-left mr-4" on:click={() => dispatch('scrollTranslationIntoView', citation)}>
		<TranslationIcon className="h-5 w-5 text-secondary-content hover:opacity-80" />
	</button>
	<div class="text-left indent-hanging">
		{text}
	</div>
	{#if commentUrns.length > 0}
		<button
			class="bg-secondary hover:opacity-70 float-right w-8"
			on:click={() => dispatch('highlightComments', commentUrns)}
			data-citation={citation}>{citation}</button
		>
	{:else}
		<span class="float-right text-center w-8">{citation}</span>
	{/if}
</div>

<style>
	.indent-hanging {
		text-indent: 2.3rem hanging;
	}
</style>
