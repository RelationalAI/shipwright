---
description: Promote skills, agents, or commands from beta to stable
argument-hint: "[optional comment]"
---

# Promote to Stable

You are running the Shipwright promote command. Your job is to help the user cherry-pick skills, agents, and commands from the beta plugin into the stable plugin.

## Directory Layout

- **Beta** (active development): `skills/`, `agents/`, `commands/`, `internal/skills/`, `internal/agents/`
- **Stable** (promoted): `stable/skills/`, `stable/agents/`, `stable/commands/`, `stable/internal/skills/`, `stable/internal/agents/`
- **Beta manifest**: `.claude-plugin/plugin.json` (name: `shipwright`)
- **Stable manifest**: `internal/plugin.stable.json` (name: `shipwright`) — not active until copied to `.claude-plugin/` during release

## Workflow

### Step 1: Show current state

List what exists in beta vs stable for each category (skills, internal skills, agents, internal agents, commands).

Use a table like:

| Type | File | Beta | Stable | Changed? |
|------|------|------|--------|----------|

- **Beta**: exists in `skills/`, `internal/skills/`, `agents/`, `internal/agents/`, or `commands/`
- **Stable**: exists in `stable/skills/`, `stable/internal/skills/`, `stable/agents/`, `stable/internal/agents/`, or `stable/commands/`
- **Changed?**: if the file exists in both, compare contents. Show "yes" if they differ, "no" if identical, "-" if only in one place.

### Step 2: Ask what to promote

Ask the user to pick which items to promote. They can:
- Name specific files (e.g., "tdd.md and systematic-debugging.md")
- Say "all skills" or "all agents" or "all commands"
- Say "everything"

If `$ARGUMENTS` contains a comment, note it for the commit message later.

### Step 3: Confirm

Show exactly what will be copied:
```
Will copy to stable:
  skills/tdd.md -> stable/skills/tdd.md
  skills/systematic-debugging.md -> stable/skills/systematic-debugging.md
```

Ask for confirmation before proceeding.

### Step 4: Copy

For each selected file, copy from beta to stable:
- `skills/<name>` -> `stable/skills/<name>`
- `internal/skills/<name>` -> `stable/internal/skills/<name>`
- `agents/<name>` -> `stable/agents/<name>`
- `internal/agents/<name>` -> `stable/internal/agents/<name>`
- `commands/<name>` -> `stable/commands/<name>`

Create the `stable/` subdirectories if they don't exist.

This is a straight file copy — the stable version is an exact snapshot of beta at promotion time.

### Step 5: Summary

Show what was promoted and remind the user:
- The changes are local — commit and push when ready
- To publish to the marketplace, update `plugins/shipwright/` in `RelationalAI/claude-plugins`

## Rules

1. **Never auto-promote** — always confirm with the user
2. **Never modify beta files** — promote is a one-way copy from beta to stable
3. **Overwrite is OK** — if a file already exists in stable, overwrite it (the user confirmed)
4. **No partial file promotion** — each file is promoted as a whole
