// Fully static site: prerender every route so adapter-static can emit plain HTML.
export const prerender = true;

// Emit directory-style pages (e.g. legal/privacy/index.html) so clean URLs like
// /legal/privacy/ resolve on GitHub Pages without per-path rewrites.
export const trailingSlash = 'always';
