<script>
	import { browser } from '$app/environment';
	import Topbar from '$lib/Topbar.svelte';
	import { prefs } from '$lib/prefs.svelte.js';
	import { fetchPrivacyMarkdown, renderMarkdown } from '$lib/markdown.js';

	/** @type {'loading' | 'ready' | 'error'} */
	let status = $state('loading');
	let html = $state('');
	let errorMessage = $state('');

	const docTitle = $derived(
		prefs.language === 'ko' ? '개인정보처리방침 | Cyclope' : 'Privacy Policy | Cyclope'
	);
	const docLang = $derived(prefs.language === 'ko' ? 'ko' : 'en');

	// Re-fetch from the GitHub repo whenever the language changes. Effects run
	// on the client only, so the external request never fires during prerender.
	$effect(() => {
		const language = prefs.language;
		let cancelled = false;

		status = 'loading';
		fetchPrivacyMarkdown(language)
			.then((markdown) => {
				if (cancelled) return;
				html = renderMarkdown(markdown);
				status = 'ready';
			})
			.catch((/** @type {Error} */ error) => {
				if (cancelled) return;
				errorMessage = error.message;
				status = 'error';
			});

		return () => {
			cancelled = true;
		};
	});

	$effect(() => {
		if (browser) document.documentElement.lang = docLang;
	});
</script>

<svelte:head>
	<title>{docTitle}</title>
	<meta name="robots" content="index, follow" />
</svelte:head>

<Topbar />

<main class="privacy-main">
	<article class="privacy-document" aria-live="polite">
		{#if status === 'loading'}
			<p class="status">Loading…</p>
		{:else if status === 'error'}
			<p class="error">{errorMessage}</p>
		{:else}
			<!-- eslint-disable-next-line svelte/no-at-html-tags -->
			{@html html}
		{/if}
	</article>
</main>
