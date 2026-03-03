# Auto-Maintained README Catalog

## Problem

Plugin consumers have no way to discover available commands and skills or understand why they'd want to use them. The current README lists command names in a flat table with no descriptions.

## Design

### README Structure

The README gains a detailed catalog between the overview table and installation sections, grouped by plugin:

```
## Dockyard
### Commands (table with links + descriptions)
### Skills (table with links + descriptions)

## Shipwright
### Commands (table with links + descriptions)
### Skills (table with links + descriptions)
```

- Table entries link to source files using relative paths (works on GitHub)
- Commands use `/plugin:command` format matching how users invoke them
- Descriptions are 2-4 sentences, value-oriented — they sell why a user would want the tool, not just what it does mechanically
- Internal shipwright skills/agents are excluded; only public-facing skills (in `plugins/shipwright/skills/`) are listed
- Descriptions are authored by Claude with user input, not mechanically extracted from frontmatter
- Sections with no items are omitted (e.g. Shipwright Skills until public skills exist)

### Keeping It Up to Date

Three mechanisms work together:

**1. Git pre-commit hook** (`.githooks/pre-commit`)

A standard git pre-commit hook, tracked in the repo. Logic:

1. Check if any staged files match `plugins/*/commands/*.md` or `plugins/*/skills/*/SKILL.md` (excluding `internal/`)
2. If no matches, exit 0 (nothing to validate)
3. If matches found, scan file system for all public commands and skills
4. Parse README.md for listed items
5. If any item exists on disk but is missing from README, exit 1 with an error listing missing items and suggesting `/update-readme`

The hook checks **completeness, not content**. It does not validate whether descriptions are accurate or fresh — that's Claude's job.

**2. SessionStart hook to ensure git hooks are active** (`.claude/hooks.json`)

A Claude Code SessionStart hook that runs `git config core.hooksPath .githooks` on every session start. Since all changes go through Claude Code, this guarantees the git pre-commit hook is always wired up — no manual setup step for contributors.

**3. `/update-readme` skill** (`.claude/skills/update-readme/SKILL.md`)

Repo-level skill for maintaining this repository, not distributed to users. Invoked when the hook blocks a commit or proactively. When invoked:

1. Scans `plugins/*/commands/` and `plugins/*/skills/` for all public items (excluding `internal/`)
2. Parses the current README to find what's already listed
3. For new items: reads the full file, drafts a 2-4 sentence value-oriented description, asks the user for extra context (e.g. "this also runs in CI"), then writes the entry
4. For removed items: deletes the entry from the README
5. For modified items (proactive run): reviews whether the existing description still fits

Key guidance in the skill:
- Descriptions sell value, not just describe function
- Ask the user for context that isn't in the file
- 2-4 sentences per item, scaled to complexity
- Maintain table format with relative links to source files

### What Goes Where

| Concern | Location |
|---------|----------|
| README catalog format and structure | README.md itself |
| Completeness enforcement | Git pre-commit hook (`.githooks/pre-commit`) |
| Git hooks activation | Claude Code SessionStart hook (`.claude/hooks.json`) |
| Description authoring guidance | Repo-level skill (`.claude/skills/update-readme/SKILL.md`) |
| Project instructions | CLAUDE.md (no README-specific content needed) |

### What's Listed

**Included:**
- All commands in `plugins/*/commands/*.md`
- All public skills in `plugins/*/skills/*/SKILL.md` (not under `internal/`)

**Excluded:**
- Anything under `internal/` (shipwright's internal agents and skills)
- Agents (implementation details, not directly user-invoked)

## Key Decisions

- **Descriptions are authored, not generated.** They're written once by Claude with user refinement, then maintained over time. This allows incorporating context that isn't in the source files.
- **Hook checks completeness, not content.** It ensures every public item has a README entry but doesn't validate description quality.
- **Repo-level, not plugin-level.** The hook and skill live at the repo root (`.githooks/`, `.claude/`). They're tooling for maintaining this repository, not features distributed to plugin consumers.
- **No manual setup.** A Claude Code SessionStart hook automatically configures `core.hooksPath` so the git pre-commit hook is always active. No contributor action needed.
- **No CLAUDE.md bloat.** All README maintenance knowledge lives in the skill, loaded only when needed.
- **Structure accommodates growth.** Both plugins have Commands and Skills sections. Sections are omitted when empty but the hook and skill know to check both plugins.
