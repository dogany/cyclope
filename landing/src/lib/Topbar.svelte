<script>
	import { base } from '$app/paths';
	import { prefs, toggleTheme, setLanguage } from './prefs.svelte.js';
	import CyclopeMark from './CyclopeMark.svelte';

	const themeAction = $derived(prefs.theme === 'dark' ? 'light' : 'dark');

	/** @param {Event & { currentTarget: HTMLSelectElement }} event */
	function onLanguageChange(event) {
		setLanguage(event.currentTarget.value);
	}
</script>

<header class="topbar" aria-label="Site header">
	<div class="topbar-inner">
		<div class="liquid-group index-group">
			<a class="brand" href="{base}/" aria-label="Cyclope home">
				<CyclopeMark class="brand-mark" />
				<span class="brand-text">Cyclope</span>
			</a>
		</div>
		<div class="liquid-group control-group" aria-label="Display preferences">
			<button
				class="theme-toggle"
				type="button"
				aria-pressed={prefs.theme === 'dark'}
				aria-label="Switch to {themeAction} theme"
				title="Switch to {themeAction} theme"
				onclick={toggleTheme}
			>
				{#if prefs.theme === 'dark'}
					<!-- Currently dark → show sun (click for light) -->
					<svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
						<path
							d="M12 4V2M12 20V22M6.41421 6.41421L5 5M17.728 17.728L19.1422 19.1422M4 12H2M20 12H22M17.7285 6.41421L19.1427 5M6.4147 17.728L5.00049 19.1422M12 17C9.23858 17 7 14.7614 7 12C7 9.23858 9.23858 7 12 7C14.7614 7 17 9.23858 17 12C17 14.7614 14.7614 17 12 17Z"
							stroke="currentColor"
							stroke-width="2"
							stroke-linecap="round"
							stroke-linejoin="round"
						></path>
					</svg>
				{:else}
					<!-- Currently light → show moon (click for dark) -->
					<svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
						<path
							d="M3.32031 11.6835C3.32031 16.6541 7.34975 20.6835 12.3203 20.6835C16.1075 20.6835 19.3483 18.3443 20.6768 15.032C19.6402 15.4486 18.5059 15.6834 17.3203 15.6834C12.3497 15.6834 8.32031 11.654 8.32031 6.68342C8.32031 5.50338 8.55165 4.36259 8.96453 3.32996C5.65605 4.66028 3.32031 7.89912 3.32031 11.6835Z"
							stroke="currentColor"
							stroke-width="2"
							stroke-linecap="round"
							stroke-linejoin="round"
						></path>
					</svg>
				{/if}
			</button>
			<div class="language-switch">
				<select value={prefs.language} onchange={onLanguageChange} aria-label="Site language">
					<option value="en">English</option>
					<option value="ko">한국어</option>
				</select>
			</div>
		</div>
	</div>
</header>
