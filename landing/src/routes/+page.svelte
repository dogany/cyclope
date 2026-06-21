<script>
	import { base } from '$app/paths';
	import { browser } from '$app/environment';
	import Topbar from '$lib/Topbar.svelte';
	import { prefs } from '$lib/prefs.svelte.js';
	import { copyFor } from '$lib/i18n.js';
	import { fetchLatestRelease, RELEASES_URL } from '$lib/releases.js';
	import HeroParticles from '$lib/HeroParticles.svelte';
	import CyclopeMark from '$lib/CyclopeMark.svelte';
	import { reveal } from '$lib/reveal.js';

	/** Move the hero spotlight glow toward the pointer. */
	function spotlight(/** @type {PointerEvent & { currentTarget: HTMLElement }} */ event) {
		const rect = event.currentTarget.getBoundingClientRect();
		event.currentTarget.style.setProperty('--gx', `${event.clientX - rect.left}px`);
		event.currentTarget.style.setProperty('--gy', `${event.clientY - rect.top}px`);
	}

	const t = $derived(copyFor(prefs.language));

	let release = $state(
		/** @type {{ version: string, dmgUrl: string | null, sizeMb: number | null, htmlUrl: string } | null} */ (
			null
		)
	);

	// Until the latest release resolves (or if it fails), fall back to the
	// releases page, which always works — even with JS disabled.
	const downloadHref = $derived(release?.dmgUrl ?? RELEASES_URL);

	// App version + size, shown as the second line on the download button.
	const downloadSub = $derived(
		release?.version ? `v${release.version}${release.sizeMb ? ` · ${release.sizeMb} MB` : ''}` : ''
	);

	const showcases = [
		{
			img: '00-menu-1800.jpg',
			titleKey: 'showcaseMenuTitle',
			copyKey: 'showcaseMenuCopy',
			altKey: 'showcaseMenuAlt',
			points: ['showcaseMenuPointOne', 'showcaseMenuPointTwo']
		},
		{
			img: '01-snap-windows-1800.jpg',
			titleKey: 'showcaseWindowTitle',
			copyKey: 'showcaseWindowCopy',
			altKey: 'showcaseWindowAlt',
			points: ['showcaseWindowPointOne', 'showcaseWindowPointTwo']
		},
		{
			img: '03-command-modal-1800.jpg',
			titleKey: 'showcaseModalTitle',
			copyKey: 'showcaseModalCopy',
			altKey: 'showcaseModalAlt',
			points: ['showcaseModalPointOne', 'showcaseModalPointTwo']
		},
		{
			img: '02-keep-mac-awake-1800.jpg',
			titleKey: 'showcaseSleepTitle',
			copyKey: 'showcaseSleepCopy',
			altKey: 'showcaseSleepAlt',
			points: ['showcaseSleepPointOne', 'showcaseSleepPointTwo']
		}
	];

	// Keep the document language in sync with the chosen UI language.
	$effect(() => {
		if (browser) document.documentElement.lang = t.lang;
	});

	// Resolve the newest .dmg from GitHub Releases (client-only).
	$effect(() => {
		let cancelled = false;
		fetchLatestRelease()
			.then((latest) => {
				if (!cancelled) release = latest;
			})
			.catch(() => {
				// Keep the releases-page fallback on any error.
			});
		return () => {
			cancelled = true;
		};
	});
</script>

<svelte:head>
	<title>{t.title}</title>
	<meta name="description" content={t.description} />
</svelte:head>

{#snippet check()}
	<svg viewBox="0 0 24 24" aria-hidden="true">
		<path
			d="M20 6L9 17l-5-5"
			fill="none"
			stroke="currentColor"
			stroke-width="2.5"
			stroke-linecap="round"
			stroke-linejoin="round"
		></path>
	</svg>
{/snippet}

<Topbar />

<main id="top">
	<section class="hero" aria-label="Cyclope overview" onpointermove={spotlight}>
		<HeroParticles />
		<div class="hero-content">
			<h1>Cyclope</h1>
			<p class="hero-tagline">{t.heroTagline}</p>
			<CyclopeMark class="hero-mark" interactive />
			<div class="hero-actions">
				<a class="button download-button" href={downloadHref}>
					<svg viewBox="0 0 24 24" aria-hidden="true">
						<path
							d="M12 3v12m0 0l-4-4m4 4l4-4M5 21h14"
							fill="none"
							stroke="currentColor"
							stroke-width="2"
							stroke-linecap="round"
							stroke-linejoin="round"
						></path>
					</svg>
					<span class="download-button-text">
						<span class="download-button-label">{t.downloadMac}</span>
						{#if downloadSub}<span class="download-button-sub">{downloadSub}</span>{/if}
					</span>
				</a>
			</div>
			<p class="download-meta">{t.downloadNote}</p>
		</div>
	</section>

	<section class="section" id="features">
		<div class="section-inner">
			<p class="section-eyebrow">{t.sectionEyebrow}</p>
			<h2>{@html t.sectionTitle}</h2>
			<p class="section-lede">{t.sectionLede}</p>

			<div class="feature-strip" aria-label="Cyclope highlights">
				<div class="feature-pill" use:reveal>
					<span class="feature-icon" aria-hidden="true">
						<svg viewBox="0 0 24 24" fill="none">
							<rect x="3" y="5" width="18" height="14" rx="3" fill="var(--text)" opacity="0.16"
							></rect>
							<rect x="3" y="5" width="9" height="14" rx="2" fill="currentColor"></rect>
						</svg>
					</span>
					<strong>{t.featureWindowTitle}</strong>
					<span>{t.featureWindowCopy}</span>
				</div>
				<div class="feature-pill" use:reveal>
					<span class="feature-icon" aria-hidden="true">
						<svg viewBox="0 0 24 24" fill="none">
							<path
								d="M19.5 14.6A7.5 7.5 0 0 1 9.4 4.5a7.5 7.5 0 1 0 10.1 10.1Z"
								stroke="currentColor"
								stroke-width="2"
								stroke-linecap="round"
								stroke-linejoin="round"
							></path>
						</svg>
					</span>
					<strong>{t.featureSleepTitle}</strong>
					<span>{t.featureSleepCopy}</span>
				</div>
				<div class="feature-pill" use:reveal>
					<span class="feature-icon" aria-hidden="true">
						<svg viewBox="0 0 24 24" fill="none">
							<path
								d="M8 5v14m0 0-3-3m3 3 3-3M16 19V5m0 0-3 3m3-3 3 3"
								stroke="currentColor"
								stroke-width="2"
								stroke-linecap="round"
								stroke-linejoin="round"
							></path>
						</svg>
					</span>
					<strong>{t.featureScrollTitle}</strong>
					<span>{t.featureScrollCopy}</span>
				</div>
			</div>

			{#each showcases as showcase (showcase.img)}
				<div class="showcase" use:reveal>
					<div class="showcase-copy">
						<h3>{t[showcase.titleKey]}</h3>
						<p>{t[showcase.copyKey]}</p>
						<ul class="check-list">
							{#each showcase.points as point (point)}
								<li>
									{@render check()}
									<span>{t[point]}</span>
								</li>
							{/each}
						</ul>
					</div>
					<figure class="screenshot-frame">
						<img
							src="{base}/assets/landing/{showcase.img}"
							alt={t[showcase.altKey]}
							loading="lazy"
						/>
					</figure>
				</div>
			{/each}
		</div>
	</section>
</main>

<footer class="footer">
	<div class="footer-inner">
		<p class="footer-copy">© 2026 Dogany · BMFM Project #2</p>
		<nav class="footer-links" aria-label="Footer">
			<a href="{base}/legal/privacy/">{t.privacyPolicy}</a>
			<a href="https://github.com/dogany/cyclope" target="_blank" rel="noopener noreferrer"
				>GitHub</a
			>
		</nav>
	</div>
</footer>
