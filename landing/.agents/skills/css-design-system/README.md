# css-design-system

Create or update CSS design-system foundations.

This skill guides coding agents to create or update CSS design-system files with primitive tokens, semantic theme tokens, base styles, and common component classes. It prefers one clear style entry file, but the exact file split should follow the target project.

## Install

Install just this skill:

```bash
npx skills add ujon/skills --skill css-design-system
```

Manual install: copy `skills/css-design-system` into `.agents/skills/css-design-system` and reference `SKILL.md` from your project `AGENTS.md`.

## Requirements

- An AI coding agent that can load skill instructions from `SKILL.md`
- A web project that can use CSS files

## Use

Ask your coding agent to create a CSS design system:

```text
create a CSS design system for this app
```

The default design system and themes are stored in skill metadata.

```yaml
metadata:
  author: ujon
  design_system: simple
  theme:
    - light
    - dark
    - system
  version: '1.0.0'
```

Command rules:

- `preview`: create `preview.html` only for explicit preview commands.
- `design-system`: when the user names a design system, update `metadata.design_system` before generation.
- `themes`: when the user names themes, update `metadata.theme` before generation.

The selected design system follows `metadata.design_system`. On first use in a codebase, if existing styles clearly match another system, the agent should ask whether to update the metadata before generating. For named external systems, the agent should inspect official or primary documentation and consider the system's documented default theme model before writing `theme.css`.

Examples that update skill settings before generation:

```text
css-design-system design-system material-ui
css-design-system design-system carbon
change css-design-system to Fluent
css-design-system themes light dark system
css-design-system themes dark
```

By default, preview HTML is not created. Generate it explicitly later:

```text
css-design-system preview
```

## Example Structure

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

This is an example, not a required file list. The agent should reuse the project's existing style root and adjust the split to project conventions, including using fewer or more files when that better fits the codebase.

## What You Get

- CSS tokens organized into primitive and semantic layers
- Light, dark, and system themes by default
- Base reset and default element styles
- Component classes for common UI such as buttons, forms, badges, cards, tabs, tables, and links when the project needs them
- Optional `preview.html` only when explicitly requested

## License

MIT
