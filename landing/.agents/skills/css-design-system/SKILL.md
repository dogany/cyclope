---
name: css-design-system
description: Create or update a CSS design system with tokens, themes, layers, components, and opt-in preview generation.
license: MIT
metadata:
  author: ujon
  design_system: simple
  theme:
    - light
    - dark
    - system
  version: 1.0.0
---

# CSS Design System

Create CSS design-system foundations using CSS files only. Do not add Tailwind, Sass, component libraries, CDNs, build steps, or generated JavaScript.

This skill follows a portable structure: one clear CSS entry point loads primitive tokens, semantic theme tokens, base styles, and component classes when the project uses that split. The root directory and file split must follow the target project's existing style location when one exists; do not assume any fixed path from the reference project.

## Command Rules

### Preview

Do not create `preview.html` during normal design-system generation. Only create it when the user explicitly invokes a preview command, such as:

```text
css-design-system preview
css-design-system preview.html
generate preview.html with css-design-system
```

Without one of those preview commands, write CSS files only.

### Design System

Use `metadata.design_system` as the default design-system setting. Initial default is `simple`.

When the user explicitly names a design system while asking to create, switch, migrate, or update the design system, update `metadata.design_system` in this `SKILL.md` before generating files.

```text
css-design-system design-system material-ui
css-design-system design-system carbon
change css-design-system to Fluent
use Material UI design system for this app
```

Store the design-system key in lowercase kebab-case, such as `simple`, `material-ui`, `carbon`, `fluent`, or `custom`.

If the requested system is external, inspect the codebase first, then search official or primary documentation before choosing token names, token values, and theme defaults.

Selection rules:

1. Always use `metadata.design_system` as the selected design system unless the user explicitly names another one.
2. If this appears to be the first time this skill is used in the codebase and existing styles clearly match a different design system, ask whether to update `metadata.design_system` to match before generating.
3. Treat it as a first use when there is no existing generated CSS entry, no prior `css-design-system` comments, and no project documentation naming this skill.
4. If `metadata.design_system` is `simple`, create a compact neutral CSS foundation with primitive tokens, semantic themes, base reset, and common component classes.

### Themes

Use `metadata.theme` as the default themes setting. Initial default is `light`, `dark`, and `system`.

When the user explicitly names themes while asking to create, switch, migrate, or update the design system, update `metadata.theme` in this `SKILL.md` before generating files.

```text
css-design-system themes light dark system
css-design-system themes dark
generate this design system with light, dark, and high-contrast themes
```

Store theme names in `metadata.theme` as a YAML list.

Theme selection order:

1. Follow existing codebase theme conventions.
2. Otherwise use `metadata.theme`.
3. For a named external design system, consider that system's documented default theme model first, such as standard light/dark modes or default color-scheme assumptions.
4. Add named themes with `[data-theme='<name>']` blocks and keep shared semantic token names stable across themes.

## File Structure

Use this as an example structure, not a required file list. The actual split may change by project size, existing conventions, and user request.

```text
styles/
├── index.css
├── base.css
├── theme.css
├── primitives/
│   ├── index.css
│   ├── palette.css
│   ├── size.css
│   └── typography.css
└── components/
    ├── index.css
    ├── button.css
    ├── form.css
    ├── badge.css
    ├── avatar.css
    ├── card.css
    ├── alert.css
    ├── progress.css
    ├── tabs.css
    ├── table.css
    └── link.css
```

The `styles/` root above is only an example. Before writing, choose the root directory with this priority:

1. Use the user-provided output directory when present.
2. Reuse an existing CSS/style root, such as `src/styles/`, `app/src/styles/`, `styles/`, `app/styles/`, `assets/styles/`, or the project's established equivalent.
3. If no convention exists, create `styles/` at the project root.

Do not prefer a candidate path only because it appeared in the reference project. Prefer the target project's actual imports and directory conventions.

Keep one clear CSS entry file. Split files only when it helps maintainability or matches the project convention.

When using the example split, `index.css` should import in this order:

```css
@import './primitives/index.css';
@import './theme.css';
@import './base.css';
@import './components/index.css';
```

When present, `primitives/index.css` imports primitive files and `components/index.css` imports component files.

## Token Guidance

Generate enough tokens for the CSS in this project to work, but do not create an exhaustive design-token encyclopedia. Token groups are conceptual; they may live in the example files above or in whatever file split the project already uses.

Primitives:

- Raw colors: black, white, gray scale, accent colors, danger, success, and warning.
- Size and motion: spacing scale, control heights, radius scale, transition duration/easing, and any project-specific layout sizes.
- Typography: sans and mono font families plus a small font-size scale.
- Effects when needed: shadows, focus rings, elevation, or other reusable visual effects.

Theme:

- Map primitive values to semantic tokens used by app CSS.
- Suggested semantic colors: `--bg`, `--bg-subtle`, `--bg-muted`, `--bg-elevated`, `--fg`, `--fg-muted`, `--fg-subtle`, `--border`, `--border-strong`, `--accent`, `--accent-muted`, `--highlight`, `--highlight-muted`, `--danger`, `--success`, `--warning`.
- Add, rename, or omit semantic tokens to match the codebase, but keep names stable once components depend on them.
- Include `:root` for light theme, `[data-theme='dark']` for dark theme, and `[data-theme='system']` for system theme when `system` is listed in `metadata.theme`. Implement system theme with `prefers-color-scheme` unless the project already has another convention.

Use this as a simple starting scale only when the project has no established scale:

```css
--space-xs: 4px;
--space-sm: 8px;
--space-md: 16px;
--space-lg: 24px;
--space-xl: 40px;
--btn-sm: 28px;
--btn-md: 32px;
--btn-lg: 40px;
--radius-sm: 4px;
--radius-md: 8px;
--radius-lg: 12px;
--transition: 150ms ease;
```

## CSS Layers

Use CSS imports and classes. CSS `@layer` is optional; use it only if the target project already uses layers or the user asks for them.

Prefer one clear CSS entry file. Keep variables as implementation details for the design-system CSS where practical; app-specific CSS may still reference tokens when composing project-specific views.

## Components

Write small, reusable component classes that consume semantic tokens. The list below is an example set, not a required set:

- Button: `.btn` with `.primary`, `.secondary`, `.ghost`, `.danger`, `.sm`, `.lg`, disabled state
- Form: `.field`, `.label`, `.input`, `.textarea`, `.select`, `.help`, `.choice`, `.switch`
- Common UI: `.badge`, `.avatar`, `.card`, `.alert`, `.progress`, `.tabs`, `.table`, `.link`

Keep components minimal. Generate only the components the project needs or already uses. Add project-specific component files only when they remove duplication.

## Base Styles

Base styles may live in `base.css` or the project's existing global stylesheet. Include only the reset and bare-element defaults the project needs:

- `box-sizing: border-box`
- basic resets for links, buttons, form fields, lists, images, SVG, and tables
- `html, body` defaults using `--bg`, `--fg`, and `--font-sans`
- heading defaults, `code`, `pre`, `::selection`, scrollbar defaults, and `:focus-visible`

## Workflow

1. Inspect existing style files before writing.
2. Apply command rules: update metadata when design system or themes are named, and keep preview opt-in.
3. Use `metadata.design_system`; on first use, ask before changing it to match an existing codebase system.
4. Choose the CSS root and file split from project conventions, using the example split only when it helps.
5. Generate in dependency order: primitive tokens, semantic themes, base/global styles, then component CSS.
6. Report files written, selected design system, selected themes, and whether preview was skipped or generated.
