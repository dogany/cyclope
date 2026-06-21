// Shared, reactive user preferences (theme + language) persisted to
// localStorage. SSR/prerender-safe: storage and matchMedia are only touched in
// the browser, so the modules can be imported during prerendering.

import { browser } from '$app/environment';

const THEME_KEY = 'theme';
const LOCALE_KEY = 'locale';

/** @type {{ theme: 'light' | 'dark', language: 'en' | 'ko' }} */
export const prefs = $state({
	theme: 'light',
	language: 'en'
});

function storedTheme() {
	if (!browser) return null;
	try {
		const value = localStorage.getItem(THEME_KEY);
		return value === 'light' || value === 'dark' ? value : null;
	} catch {
		return null;
	}
}

function systemTheme() {
	if (!browser) return 'light';
	return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function storedLanguage() {
	if (!browser) return null;
	try {
		const value = localStorage.getItem(LOCALE_KEY);
		return value === 'en' || value === 'ko' ? value : null;
	} catch {
		return null;
	}
}

function systemLanguage() {
	if (!browser) return 'en';
	return navigator.language.toLowerCase().startsWith('ko') ? 'ko' : 'en';
}

function applyTheme() {
	if (browser) {
		document.documentElement.dataset.theme = prefs.theme;
	}
}

/** Read persisted preferences and apply the theme. Call once on the client. */
export function initPrefs() {
	if (!browser) return;
	prefs.theme = storedTheme() ?? systemTheme();
	prefs.language = storedLanguage() ?? systemLanguage();
	applyTheme();
}

/** @param {'light' | 'dark'} theme */
export function setTheme(theme) {
	prefs.theme = theme === 'dark' ? 'dark' : 'light';
	if (browser) {
		try {
			localStorage.setItem(THEME_KEY, prefs.theme);
		} catch {
			// Keep the in-memory theme even if storage is unavailable.
		}
		applyTheme();
	}
}

export function toggleTheme() {
	setTheme(prefs.theme === 'dark' ? 'light' : 'dark');
}

/** @param {string} language */
export function setLanguage(language) {
	prefs.language = language === 'ko' ? 'ko' : 'en';
	if (browser) {
		try {
			localStorage.setItem(LOCALE_KEY, prefs.language);
		} catch {
			// Keep the in-memory language even if storage is unavailable.
		}
	}
}
