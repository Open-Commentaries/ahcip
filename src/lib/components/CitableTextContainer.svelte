<script lang="ts">
	import { createEventDispatcher } from 'svelte';

	const dispatch = createEventDispatcher();

	export let citation: string;
	export let commentUrns: string[];
	export let text: string;
</script>

<p>
	{text}
	{#if commentUrns.length > 0}
		<button
			class="bg-slate-300 hover:bg-slate-500 float-right w-8"
			on:click={() => dispatch('highlightComments', commentUrns)}
			data-citation={citation}>{citation}</button
		>
	{:else}
		<span class="float-right text-center w-8">{citation}</span>
	{/if}
</p>
