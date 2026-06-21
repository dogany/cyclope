import adapter from '@sveltejs/adapter-static';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		// fallback emits a 404.html so GitHub Pages can serve unknown/deep paths
		// through the app shell (base-aware) instead of a bare server 404.
		adapter: adapter({ fallback: '404.html' }),
		// The site is served from a GitHub Pages project page at /cyclope.
		// Override with BASE_PATH (empty for local dev / root deploys = default).
		paths: {
			base: process.env.BASE_PATH ?? ''
		}
	}
};

export default config;
