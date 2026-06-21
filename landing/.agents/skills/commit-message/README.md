# commit-message

Format Git commit messages with a one-line summary plus title-case `Summary` and `Changes` sections.

This skill gives coding agents a small, repeatable commit message convention. It keeps messages concise, avoids prefix tags, and asks the agent to explain why a change was made, not only what changed.

## Install

Install just this skill:

```bash
npx skills add ujon/skills --skill commit-message
```

Manual install: copy `skills/commit-message` into `.agents/skills/commit-message` and reference `SKILL.md` from your project `AGENTS.md`.

## Requirements

- An AI coding agent that can load skill instructions from `SKILL.md`
- A Git repository with changes that need a commit message

## Use

Ask your coding agent to create, edit, or review a commit message:

```text
write a commit message for the staged changes
```

The agent should produce a one-line summary followed by `## Summary` and `## Changes`.

## Language

The default language for commit message content is English:

```yaml
metadata:
  locale: en
```

Edit `metadata.locale` in your local copy of `SKILL.md` to change the language used for the one-line summary, the body under `## Summary`, and the bullets under `## Changes`. The `## Summary` and `## Changes` headers stay in English.

## Format

```text
<one-line summary>

## Summary
<1-3 sentences on motivation and context>

## Changes
- <change 1>
- <change 2>
```

## Rules

- Use `metadata.locale` only for commit message content: the one-line summary, the body under `## Summary`, and the bullets under `## Changes`.
- Do not use prefix or scope tags such as `feat:`, `fix:`, or `chore:`.
- Keep `## Summary` and `## Changes` headers in English and title case.
- Explain why the change was made, not only what changed.

## What You Get

- A concise commit message in the configured language
- A consistent structure for summary and change details
- Change bullets focused on meaningful behavior or maintenance impact
- No conventional-commit prefix or scope tags

## License

MIT
