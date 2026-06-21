# Cyclope — Landing Page

The marketing landing page for [Cyclope](../README.md), a local Mac menu bar
utility for window snapping, sleep prevention, and custom shortcuts.

Built with [SvelteKit](https://svelte.dev/docs/kit) (Svelte 5, runes mode) and
prerendered to static HTML via
[`@sveltejs/adapter-static`](https://svelte.dev/docs/kit/adapter-static), so the
whole site can be hosted from any static file server (e.g. GitHub Pages).

## Tech stack

- **Framework:** SvelteKit 2 + Svelte 5 (runes)
- **Language:** JavaScript with JSDoc types
- **Build/dev:** Vite
- **Package manager:** bun
- **Output:** fully static (prerendered) site

## Getting started

Install dependencies and start the dev server:

```sh
bun install
bun run dev

# or open the app in a new browser tab automatically
bun run dev -- --open
```

## Building

Create a production build (static files) and preview it locally:

```sh
bun run build
bun run preview
```

The generated site is written to `build/` and contains only static assets.

## Other scripts

```sh
bun run check    # type-check with svelte-check
bun run format   # format with Prettier
bun run lint     # check formatting
```
