<script>
	import { onMount } from 'svelte';

	/** @type {{ class?: string, interactive?: boolean }} */
	let { class: className = '', interactive = false } = $props();

	/** @type {SVGCircleElement | undefined} */
	let pupil = $state();

	onMount(() => {
		if (!interactive || !pupil) return;
		const svg = pupil.ownerSVGElement;
		if (!svg) return;
		if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return; // stay centered
		const eye = pupil; // non-null capture for the animation closure

		const CX = 11.0102;
		const CY = 11;
		const MAX = 1.3; // how far the pupil can drift, in viewBox units
		let tx = 0;
		let ty = 0;
		let x = 0;
		let y = 0;
		let lastMove = -1e9;
		let nextSaccade = 0;
		let raf = 0;

		// Look toward the pointer (a one-eyed gaze that follows you).
		const onMove = (/** @type {PointerEvent} */ e) => {
			const r = svg.getBoundingClientRect();
			const dx = e.clientX - (r.left + r.width / 2);
			const dy = e.clientY - (r.top + r.height / 2);
			const d = Math.hypot(dx, dy) || 1;
			const reach = Math.min(1, d / 240);
			tx = (dx / d) * MAX * reach;
			ty = (dy / d) * MAX * reach;
			lastMove = performance.now();
		};

		const tick = (/** @type {number} */ now) => {
			// Idle: dart around to random spots (saccades).
			if (now - lastMove > 1500 && now > nextSaccade) {
				const a = Math.random() * Math.PI * 2;
				const r = Math.random() * MAX;
				tx = Math.cos(a) * r;
				ty = Math.sin(a) * r;
				nextSaccade = now + 1100 + Math.random() * 1700;
			}
			x += (tx - x) * 0.18;
			y += (ty - y) * 0.18;
			eye.setAttribute('cx', (CX + x).toFixed(3));
			eye.setAttribute('cy', (CY + y).toFixed(3));
			raf = requestAnimationFrame(tick);
		};

		window.addEventListener('pointermove', onMove, { passive: true });
		raf = requestAnimationFrame(tick);

		return () => {
			window.removeEventListener('pointermove', onMove);
			cancelAnimationFrame(raf);
		};
	});
</script>

<svg class={className} viewBox="0 0 22 22" fill="none" aria-hidden="true">
	<!-- Hexagon ring (official mark geometry) -->
	<path
		fill="currentColor"
		fill-rule="evenodd"
		d="M19.6703 6V16L11.0102 21L2.35001 16V6L11.0102 1L19.6703 6ZM4.85001 7.44238V14.5566L11.0102 18.1123L17.1703 14.5566V7.44238L11.0102 3.88672L4.85001 7.44238Z"
	/>
	{#if interactive}
		<!-- Living "cyclops" eye: iris + moving pupil + glint, with a blink -->
		<g class="eye-group">
			<circle class="mark-eye" cx="11.0102" cy="11" r="3" fill="currentColor" />
			<circle bind:this={pupil} class="mark-pupil" cx="11.0102" cy="11" r="1.4" />
			<circle class="mark-glint" cx="10" cy="10" r="0.5" />
		</g>
	{:else}
		<circle class="mark-eye" cx="11.0102" cy="11" r="3" fill="currentColor" />
	{/if}
</svg>
