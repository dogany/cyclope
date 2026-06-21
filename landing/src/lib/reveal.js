// Svelte action: fade/slide an element into view once it scrolls into the
// viewport. Falls back to immediately visible without IntersectionObserver or
// when the user prefers reduced motion.

/**
 * @param {HTMLElement} node
 * @param {{ delay?: number }} [options]
 */
export function reveal(node, options = {}) {
	const reduce =
		typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

	if (typeof IntersectionObserver === 'undefined' || reduce) {
		node.classList.add('is-visible');
		return {};
	}

	if (options.delay) node.style.transitionDelay = `${options.delay}ms`;
	node.classList.add('reveal');

	const observer = new IntersectionObserver(
		(entries) => {
			for (const entry of entries) {
				if (entry.isIntersecting) {
					node.classList.add('is-visible');
					observer.unobserve(node);
				}
			}
		},
		{ threshold: 0.15, rootMargin: '0px 0px -10% 0px' }
	);

	observer.observe(node);

	return {
		destroy() {
			observer.disconnect();
		}
	};
}
