<script lang="ts">
	import type { Card } from '$lib/types/commentary.type';

	import { createEventDispatcher } from 'svelte';
	import TranslationIcon from '$lib/icons/TranslationIcon.svelte';

	const dispatch = createEventDispatcher();

	export let citation: string;
	export let commentUrns: string[];
	export let text: string;
	export let translations: Card[] = [];

	let focusedTranslation: Card | undefined;

	function toggleTranslation(translation: Card) {
		return (_e: MouseEvent) => {
			if (focusedTranslation?.n === translation.n) {
				focusedTranslation = undefined;
			} else {
				focusedTranslation = translation;
			}
		};
	}
</script>

<div>
	{text}
	{#each translations as translation (translation.n)}
		<button class="secondary-content float-right" on:click={toggleTranslation(translation)}>
			<TranslationIcon />
		</button>
	{/each}
	{#if commentUrns.length > 0}
		<button
			class="bg-secondary hover:opacity-70 float-right w-8"
			on:click={() => dispatch('highlightComments', commentUrns)}
			data-citation={citation}>{citation}</button
		>
	{:else}
		<span class="float-right text-center w-8">{citation}</span>
	{/if}

	{#if focusedTranslation}
		<div
			class="border border-base-200 text-secondary-content shadow-inner px-4 max-h-48 overflow-y-scroll"
		>
			{@html focusedTranslation.xml_content}
		</div>
	{/if}
</div>
