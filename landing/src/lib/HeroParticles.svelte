<script>
	import { onMount } from 'svelte';

	/** @type {HTMLCanvasElement} */
	let canvas;

	onMount(() => {
		const ctx = /** @type {CanvasRenderingContext2D | null} */ (canvas.getContext('2d'));
		if (!ctx) return;
		/** @type {CanvasRenderingContext2D} */
		const c = ctx;

		const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
		const dpr = Math.min(window.devicePixelRatio || 1, 2);
		const parent = canvas.parentElement;

		let w = 0;
		let h = 0;
		let raf = 0;
		const pointer = { x: -9999, y: -9999 };
		const count = reduce ? 34 : 84;
		/** @type {{ x: number, y: number, r: number, vx: number, vy: number, a: number }[]} */
		let parts = [];

		const readAccent = () =>
			getComputedStyle(canvas).getPropertyValue('--accent').trim() || '#2563eb';
		let color = readAccent();

		function resize() {
			const rect = canvas.getBoundingClientRect();
			w = rect.width;
			h = rect.height;
			canvas.width = Math.round(w * dpr);
			canvas.height = Math.round(h * dpr);
			c.setTransform(dpr, 0, 0, dpr, 0, 0);
		}

		function seed() {
			parts = Array.from({ length: count }, () => ({
				x: Math.random() * w,
				y: Math.random() * h,
				r: Math.random() * 1.7 + 0.5,
				vx: (Math.random() - 0.5) * 0.16,
				vy: -(Math.random() * 0.32 + 0.1), // drift up — "liftoff"
				a: Math.random() * 0.5 + 0.18
			}));
		}

		function draw() {
			c.clearRect(0, 0, w, h);
			c.fillStyle = color;
			for (const p of parts) {
				const dx = p.x - pointer.x;
				const dy = p.y - pointer.y;
				const dist = Math.hypot(dx, dy);
				if (dist < 130) {
					const f = (1 - dist / 130) * 0.8;
					p.x += (dx / (dist + 0.001)) * f;
					p.y += (dy / (dist + 0.001)) * f;
				}
				p.x += p.vx;
				p.y += p.vy;
				if (p.y < -6) {
					p.y = h + 6;
					p.x = Math.random() * w;
				}
				if (p.x < -6) p.x = w + 6;
				else if (p.x > w + 6) p.x = -6;
				c.globalAlpha = p.a;
				c.beginPath();
				c.arc(p.x, p.y, p.r, 0, Math.PI * 2);
				c.fill();
			}
			c.globalAlpha = 1;
		}

		function loop() {
			draw();
			raf = requestAnimationFrame(loop);
		}

		const onMove = (/** @type {PointerEvent} */ e) => {
			const rect = canvas.getBoundingClientRect();
			pointer.x = e.clientX - rect.left;
			pointer.y = e.clientY - rect.top;
		};
		const onLeave = () => {
			pointer.x = -9999;
			pointer.y = -9999;
		};
		const onResize = () => {
			resize();
			seed();
		};

		resize();
		seed();
		if (reduce) {
			draw();
		} else {
			loop();
			parent?.addEventListener('pointermove', onMove);
			parent?.addEventListener('pointerleave', onLeave);
		}
		window.addEventListener('resize', onResize);

		// Recolor particles when the theme toggles.
		const observer = new MutationObserver(() => {
			color = readAccent();
		});
		observer.observe(document.documentElement, {
			attributes: true,
			attributeFilter: ['data-theme']
		});

		return () => {
			cancelAnimationFrame(raf);
			parent?.removeEventListener('pointermove', onMove);
			parent?.removeEventListener('pointerleave', onLeave);
			window.removeEventListener('resize', onResize);
			observer.disconnect();
		};
	});
</script>

<canvas bind:this={canvas} class="hero-particles" aria-hidden="true"></canvas>
