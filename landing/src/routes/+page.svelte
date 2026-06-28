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
	const canonicalUrl = 'https://dogany.github.io/cyclope/';
	const shareImageUrl = 'https://dogany.github.io/cyclope/assets/og-image.png';
	const homebrewCommand = 'brew install --cask dogany/tap/cyclope';
	let heroFlow = $state(0);
	let installCopied = $state(false);
	let copyTimer = /** @type {ReturnType<typeof setTimeout> | undefined} */ (undefined);
	const shareTitle = $derived(`${t.title} - ${t.heroTagline}`);

	const heroStyle = $derived(
		[
			`--hero-flow: ${heroFlow.toFixed(3)}`,
			`--hero-content-y: ${(-22 * heroFlow).toFixed(2)}px`,
			`--hero-scale: ${(1 - 0.025 * heroFlow).toFixed(3)}`,
			`--hero-content-opacity: ${(1 - 0.12 * heroFlow).toFixed(3)}`,
			`--feature-lift: ${(24 - 24 * heroFlow).toFixed(2)}px`,
			`--bridge-y: ${(14 * heroFlow).toFixed(2)}px`,
			`--bridge-opacity: ${(1 - 0.55 * heroFlow).toFixed(3)}`
		].join('; ')
	);

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

	async function copyInstallCommand() {
		if (!browser) return;
		if (copyTimer) clearTimeout(copyTimer);

		try {
			if (navigator.clipboard?.writeText) {
				await navigator.clipboard.writeText(homebrewCommand);
			} else {
				const textArea = document.createElement('textarea');
				textArea.value = homebrewCommand;
				textArea.setAttribute('readonly', '');
				textArea.style.position = 'fixed';
				textArea.style.opacity = '0';
				document.body.appendChild(textArea);
				textArea.select();
				document.execCommand('copy');
				document.body.removeChild(textArea);
			}
			installCopied = true;
			copyTimer = setTimeout(() => {
				installCopied = false;
				copyTimer = undefined;
			}, 1800);
		} catch {
			installCopied = false;
		}
	}

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

	// Connect the hero and feature section with a light scroll-driven motion.
	$effect(() => {
		if (!browser) return;
		const motionQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
		let frame = 0;

		const update = () => {
			frame = 0;
			if (motionQuery.matches) {
				heroFlow = 0;
				return;
			}
			const viewport = window.innerHeight || 1;
			const next = Math.min(1, Math.max(0, window.scrollY / (viewport * 0.74)));
			heroFlow = next;
		};
		const queue = () => {
			if (!frame) frame = requestAnimationFrame(update);
		};

		update();
		window.addEventListener('scroll', queue, { passive: true });
		window.addEventListener('resize', queue);
		motionQuery.addEventListener('change', update);

		return () => {
			cancelAnimationFrame(frame);
			window.removeEventListener('scroll', queue);
			window.removeEventListener('resize', queue);
			motionQuery.removeEventListener('change', update);
		};
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
	<link rel="canonical" href={canonicalUrl} />

	<meta property="og:type" content="website" />
	<meta property="og:site_name" content="Cyclope" />
	<meta property="og:url" content={canonicalUrl} />
	<meta property="og:title" content={shareTitle} />
	<meta property="og:description" content={t.description} />
	<meta property="og:image" content={shareImageUrl} />
	<meta property="og:image:secure_url" content={shareImageUrl} />
	<meta property="og:image:type" content="image/png" />
	<meta property="og:image:width" content="1200" />
	<meta property="og:image:height" content="630" />
	<meta property="og:image:alt" content={t.shareImageAlt} />

	<meta name="twitter:card" content="summary_large_image" />
	<meta name="twitter:title" content={shareTitle} />
	<meta name="twitter:description" content={t.description} />
	<meta name="twitter:image" content={shareImageUrl} />
	<meta name="twitter:image:alt" content={t.shareImageAlt} />
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

<main id="top" style={heroStyle}>
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
				<button
					class:copied={installCopied}
					class="install-command"
					type="button"
					aria-label={t.installCopyLabel}
					onclick={copyInstallCommand}
				>
					<code><span aria-hidden="true">$</span>{homebrewCommand}</code>
					<span class="install-command-action" aria-live="polite">
						{#if installCopied}
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
							<span class="sr-only">{t.installCopied}</span>
						{:else}
							<svg viewBox="0 0 24 24" aria-hidden="true">
								<rect
									x="9"
									y="9"
									width="10"
									height="10"
									rx="2"
									fill="none"
									stroke="currentColor"
									stroke-width="2"
								></rect>
								<path
									d="M5 15V7a2 2 0 0 1 2-2h8"
									fill="none"
									stroke="currentColor"
									stroke-width="2"
									stroke-linecap="round"
								></path>
							</svg>
							<span class="sr-only">{t.installCopy}</span>
						{/if}
					</span>
				</button>
			</div>
			<p class="download-meta">{t.downloadNote}</p>
		</div>
		<a class="hero-scroll-link" href="#features" aria-label="View Cyclope features">
			<span class="hero-scroll-line"></span>
			<svg viewBox="0 0 24 24" aria-hidden="true">
				<path
					d="M6 9l6 6 6-6"
					fill="none"
					stroke="currentColor"
					stroke-width="2.4"
					stroke-linecap="round"
					stroke-linejoin="round"
				></path>
			</svg>
		</a>
	</section>

	<section class="section" id="features">
		<div class="section-inner">
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
