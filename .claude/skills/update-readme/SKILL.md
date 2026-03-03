---
name: update-readme
description: >
  Use when the pre-commit hook blocks a commit due to missing README entries, when adding
  or removing commands/skills, or when you want to refresh README descriptions after
  significant changes to a command or skill.
---

# Update README Catalog

Maintain the command and skill catalog in README.md. This skill ensures every public
command and skill has a compelling, value-oriented entry in the README.

## Process

### 1. Inventory

Scan for all public commands and skills:

- Commands: `plugins/*/commands/*.md`
- Skills: `plugins/*/skills/*/SKILL.md` (exclude anything under `internal/`)

Compare against what's currently in the README.

### 2. Handle new items

For each item on disk but missing from README:

1. Read the full file content to understand what the tool does
2. Draft a 2-4 sentence description that:
   - Leads with the problem it solves or the value it delivers
   - Highlights what makes it special (not just "runs a code review" but what kind, why it's better)
   - Gives the user a reason to be excited about using it
3. Ask the user: "Anything I should know that isn't in the file? For example, does this integrate with CI, pair with another tool, or unlock a workflow?"
4. Refine the description with the user's input
5. Add the entry to the correct table in README.md

### 3. Handle removed items

For each item in README but no longer on disk, remove the entry.

### 4. Handle modified items (optional)

If the user invoked this skill proactively (not from a hook failure), ask: "Want me to
review existing descriptions for accuracy?" If yes, check each description against the
current file content and flag any that seem stale.

## README Format

The catalog is organized by plugin, then by type. Each plugin has a Commands section and
a Skills section (omit a section if the plugin has no items of that type).

### Command entry format

```
| [`/plugin:command-name`](plugins/plugin/commands/command-name.md) | Description here. |
```

### Skill entry format

```
| [`skill-name`](plugins/plugin/skills/skill-name/SKILL.md) | Description here. |
```

## Description Guidelines

Good descriptions sell value. Compare:

- Bad: "Performs a code review on your changes."
- Good: "Runs a structured 3-pass review — correctness bugs, convention compliance, and test quality — with confidence scoring. The same review runs in CI, so catching issues locally saves you a round-trip."

- Bad: "Analyzes your codebase."
- Good: "Produces 7 focused profile documents covering your stack, architecture, conventions, and testing patterns. Run it once and every future Claude session deeply understands your project."

Focus on: What problem does this solve? What makes it better than the alternative? Why should I be excited?

## Scope

Only public-facing items belong in the README:
- All commands in `plugins/*/commands/`
- All skills in `plugins/*/skills/` (not under `internal/`)
- Agents and internal skills/agents are excluded
