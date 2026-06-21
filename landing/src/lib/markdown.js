// Privacy policy is the single source of truth in the GitHub repo. The landing
// page fetches the raw markdown from there and renders it, so the content never
// has to be duplicated into this project.

const RAW_BASE = 'https://raw.githubusercontent.com/dogany/cyclope/main';

/** @param {'en' | 'ko' | string} language */
export function privacyMarkdownUrl(language) {
	const file = language === 'ko' ? 'ko' : 'en';
	return `${RAW_BASE}/legal/privacy/${file}.md`;
}

/** @param {string} value */
function escapeHtml(value) {
	return value
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&#39;');
}

/** @param {string} value */
function sanitizeHref(value) {
	try {
		const url = new URL(value, RAW_BASE);
		if (['http:', 'https:', 'mailto:'].includes(url.protocol)) {
			return escapeHtml(value);
		}
	} catch {
		return '#';
	}
	return '#';
}

/** @param {string} markdown */
function renderInline(markdown) {
	return escapeHtml(markdown)
		.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
		.replace(
			/\[([^\]]+)\]\(([^)]+)\)/g,
			(_match, label, href) => `<a href="${sanitizeHref(href)}">${label}</a>`
		);
}

/**
 * Render a small markdown subset (headings, paragraphs, bold, links) to HTML.
 * Matches the original static site's renderer; output is escaped before markup.
 * @param {string} markdown
 */
export function renderMarkdown(markdown) {
	const lines = markdown.replace(/\r\n/g, '\n').split('\n');
	/** @type {string[]} */
	const html = [];
	/** @type {string[]} */
	let paragraph = [];

	function flushParagraph() {
		if (!paragraph.length) return;
		html.push(`<p>${renderInline(paragraph.join(' '))}</p>`);
		paragraph = [];
	}

	for (const line of lines) {
		const trimmed = line.trim();

		if (!trimmed) {
			flushParagraph();
			continue;
		}

		const heading = /^(#{1,6})\s+(.+)$/.exec(trimmed);

		if (heading) {
			flushParagraph();
			const level = heading[1].length;
			html.push(`<h${level}>${renderInline(heading[2])}</h${level}>`);
			continue;
		}

		paragraph.push(trimmed);
	}

	flushParagraph();
	return html.join('\n');
}

/**
 * Fetch the privacy policy markdown for a language from the GitHub repo.
 * @param {'en' | 'ko' | string} language
 * @param {typeof fetch} [fetchFn]
 */
export async function fetchPrivacyMarkdown(language, fetchFn = fetch) {
	const url = privacyMarkdownUrl(language);
	const response = await fetchFn(url, { cache: 'no-cache' });
	if (!response.ok) {
		throw new Error(`Unable to load ${url} (${response.status})`);
	}
	return response.text();
}
