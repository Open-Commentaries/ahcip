<script lang="ts">
	export let n: string;
	export let nextN: string;
	export let xmlContent: string;
</script>

<div class="card w-full" id={`translation:${n}-${nextN}`}>
	<div class="card-body">
		<h2 class="card-title text-sm">{n}-{nextN}</h2>
		{@html xmlContent}
	</div>
</div>
