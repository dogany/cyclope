// Resolve the latest released build from GitHub Releases at runtime, so the
// download button always points at the newest .dmg without rebuilding the site.

const REPO = 'dogany/cyclope';

/** Releases page — always valid, used as the fallback before/if the API fails. */
export const RELEASES_URL = `https://github.com/${REPO}/releases/latest`;

/**
 * @typedef {{ version: string, dmgUrl: string | null, sizeMb: number | null, htmlUrl: string }} LatestRelease
 */

/**
 * Fetch the latest release and its macOS .dmg asset.
 * @param {typeof fetch} [fetchFn]
 * @returns {Promise<LatestRelease>}
 */
export async function fetchLatestRelease(fetchFn = fetch) {
	const response = await fetchFn(`https://api.github.com/repos/${REPO}/releases/latest`, {
		headers: { Accept: 'application/vnd.github+json' }
	});
	if (!response.ok) {
		throw new Error(`Unable to load latest release (${response.status})`);
	}

	const data = await response.json();
	const dmg = (data.assets ?? []).find((/** @type {{ name?: string, size?: number }} */ asset) =>
		asset.name?.toLowerCase().endsWith('.dmg')
	);

	return {
		// Strip both the old (release-<v>) and new (release/v<v>) tag prefixes.
		version: String(data.tag_name ?? '').replace(/^release[\/-]v?/, ''),
		dmgUrl: dmg?.browser_download_url ?? null,
		sizeMb: dmg?.size ? Math.round((dmg.size / 1048576) * 10) / 10 : null,
		htmlUrl: data.html_url ?? RELEASES_URL
	};
}
