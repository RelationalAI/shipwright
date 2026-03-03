# README Catalog Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the README's command/skill catalog always in sync with the actual plugin contents via a pre-commit hook and an authoring skill.

**Architecture:** A git pre-commit hook validates completeness (every public command/skill has a README entry). A Claude Code SessionStart hook ensures the git hook is always active. A repo-level `/update-readme` skill guides Claude through authoring compelling descriptions. Descriptions are authored once with user input and maintained over time — not mechanically regenerated.

**Tech Stack:** Bash (hooks + smoke test), Markdown (skill + README)

**Design doc:** `docs/plans/2026-03-03-readme-catalog-design.md`

---

### Task 1: Write the validate-readme smoke test

Write the test before the implementation. This test checks that every public command and skill on disk has a corresponding entry in README.md.

**Files:**
- Create: `plugins/dockyard/tests/smoke/validate-readme.sh`
- Modify: `plugins/dockyard/tests/smoke/run-all.sh`

**Step 1: Write validate-readme.sh**

```bash
#!/usr/bin/env bash
#
# validate-readme.sh — Verify every public command and skill has a README entry.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
README="$REPO_ROOT/README.md"
PASS=0
FAIL=0

echo "=== validate-readme ==="

if [ ! -f "$README" ]; then
  echo "  FAIL  README.md not found"
  exit 1
fi

# --- Check all public commands are listed ---
echo ""
echo "Commands in README:"
for cmd_file in "$REPO_ROOT"/plugins/*/commands/*.md; do
  [ -f "$cmd_file" ] || continue
  plugin=$(echo "$cmd_file" | sed "s|.*/plugins/||" | cut -d/ -f1)
  cmd=$(basename "$cmd_file" .md)
  if grep -q "/$plugin:$cmd" "$README"; then
    echo "  PASS  /$plugin:$cmd"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  /$plugin:$cmd not found in README"
    FAIL=$((FAIL + 1))
  fi
done

# --- Check all public skills are listed ---
echo ""
echo "Skills in README:"
for skill_dir in "$REPO_ROOT"/plugins/*/skills/*/; do
  [ -d "$skill_dir" ] || continue
  # Skip internal skills
  echo "$skill_dir" | grep -q '/internal/' && continue
  [ -f "$skill_dir/SKILL.md" ] || continue
  skill=$(basename "$skill_dir")
  if grep -q "$skill" "$README"; then
    echo "  PASS  $skill"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $skill not found in README"
    FAIL=$((FAIL + 1))
  fi
done

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "validate-readme: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
```

**Step 2: Register the new suite in run-all.sh**

Add after the existing `validate-commands` line:

```bash
run_suite "validate-readme"  "$SCRIPT_DIR/validate-readme.sh"
```

**Step 3: Run the smoke test to verify it fails**

Run: `bash plugins/dockyard/tests/smoke/validate-readme.sh`

Expected: FAIL — the current README doesn't have `/dockyard:codebase-analyze` etc. in the expected format.

**Step 4: Commit**

```bash
git add plugins/dockyard/tests/smoke/validate-readme.sh plugins/dockyard/tests/smoke/run-all.sh
git commit -m "test: add validate-readme smoke test (fails until README is populated)"
```

---

### Task 2: Create the git pre-commit hook

A git pre-commit hook that only fires when plugin command/skill files are staged, then validates README completeness.

**Files:**
- Create: `.githooks/pre-commit`

**Step 1: Write the pre-commit hook**

```bash
#!/usr/bin/env bash
#
# pre-commit — Block commits when README.md is missing entries for public
#              commands or skills. Only runs when plugin files are staged.
#
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Check if any public plugin commands or skills are staged
STAGED=$(git diff --cached --name-only)
PLUGIN_CHANGES=$(echo "$STAGED" | grep -E '^plugins/[^/]+/(commands/.*\.md|skills/[^/]+/SKILL\.md)' | grep -v '/internal/' || true)

if [ -z "$PLUGIN_CHANGES" ]; then
  exit 0
fi

# Scan file system for all public commands and skills, check each is in README
README="$REPO_ROOT/README.md"
MISSING=()

for cmd_file in "$REPO_ROOT"/plugins/*/commands/*.md; do
  [ -f "$cmd_file" ] || continue
  plugin=$(echo "$cmd_file" | sed "s|.*/plugins/||" | cut -d/ -f1)
  cmd=$(basename "$cmd_file" .md)
  if ! grep -q "/$plugin:$cmd" "$README"; then
    MISSING+=("/$plugin:$cmd")
  fi
done

for skill_dir in "$REPO_ROOT"/plugins/*/skills/*/; do
  [ -d "$skill_dir" ] || continue
  echo "$skill_dir" | grep -q '/internal/' && continue
  [ -f "$skill_dir/SKILL.md" ] || continue
  skill=$(basename "$skill_dir")
  if ! grep -q "$skill" "$README"; then
    MISSING+=("skill: $skill")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "README.md is missing entries for:"
  for item in "${MISSING[@]}"; do
    echo "  - $item"
  done
  echo ""
  echo "Run /update-readme to add missing entries, then stage README.md."
  exit 1
fi

exit 0
```

**Step 2: Make it executable**

Run: `chmod +x .githooks/pre-commit`

**Step 3: Commit**

```bash
git add .githooks/pre-commit
git commit -m "feat: add pre-commit hook to enforce README completeness"
```

---

### Task 3: Create the SessionStart hook

A Claude Code hook that ensures `core.hooksPath` is set on every session, so the git pre-commit hook is always active without manual setup.

**Files:**
- Create: `.claude/hooks.json`
- Create: `.claude/hooks/setup-githooks.sh`

**Step 1: Write the setup script**

```bash
#!/usr/bin/env bash
#
# setup-githooks.sh — Ensure git uses .githooks/ for hook scripts.
# Called by Claude Code SessionStart hook.
#
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

CURRENT=$(git config core.hooksPath 2>/dev/null || echo "")
if [ "$CURRENT" != ".githooks" ]; then
  git config core.hooksPath .githooks
fi
```

**Step 2: Write hooks.json**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/setup-githooks.sh"
          }
        ]
      }
    ]
  }
}
```

**Step 3: Make the script executable**

Run: `chmod +x .claude/hooks/setup-githooks.sh`

**Step 4: Activate git hooks for this session**

Run: `git config core.hooksPath .githooks`

**Step 5: Commit**

```bash
git add .claude/hooks.json .claude/hooks/setup-githooks.sh
git commit -m "feat: add SessionStart hook to auto-configure git hooks path"
```

---

### Task 4: Create the update-readme skill

**Files:**
- Create: `.claude/skills/update-readme/SKILL.md`

**Step 1: Write the skill**

```markdown
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
```

**Step 2: Commit**

```bash
git add .claude/skills/update-readme/SKILL.md
git commit -m "feat: add /update-readme skill for README catalog authoring"
```

---

### Task 5: Update README with catalog structure

Replace the current flat "Plugins" table with the full catalog. Start with the structural skeleton — descriptions will be populated interactively in the next task.

**Files:**
- Modify: `README.md`

**Step 1: Rewrite README with catalog structure**

Replace everything between `# Shipwright Marketplace` and `## Installation` with:

```markdown
# Shipwright Marketplace

RAI's curated Claude Code plugin marketplace.

## Plugins

| Plugin | Description |
|--------|-------------|
| **dockyard** | Standalone skills & commands |
| **shipwright** | Orchestrated bug-fix workflows (requires dockyard) |

## Dockyard

Standalone tools that work without orchestration.

### Commands

| Command | Description |
|---------|-------------|
| [`/dockyard:codebase-analyze`](plugins/dockyard/commands/codebase-analyze.md) | TODO |
| [`/dockyard:code-review`](plugins/dockyard/commands/code-review.md) | TODO |
| [`/dockyard:doc-digest`](plugins/dockyard/commands/doc-digest.md) | TODO |
| [`/dockyard:feedback`](plugins/dockyard/commands/feedback.md) | TODO |
| [`/dockyard:investigate`](plugins/dockyard/commands/investigate.md) | TODO |
| [`/dockyard:observe`](plugins/dockyard/commands/observe.md) | TODO |
| [`/dockyard:review-and-submit`](plugins/dockyard/commands/review-and-submit.md) | TODO |

### Skills

| Skill | Description |
|-------|-------------|
| [`brownfield-analysis`](plugins/dockyard/skills/brownfield-analysis/SKILL.md) | TODO |
| [`code-review`](plugins/dockyard/skills/code-review/SKILL.md) | TODO |
| [`observability`](plugins/dockyard/skills/observability/SKILL.md) | TODO |
| [`review-and-submit`](plugins/dockyard/skills/review-and-submit/SKILL.md) | TODO |

## Shipwright

Orchestrated bug-fix workflows. Requires dockyard.

### Commands

| Command | Description |
|---------|-------------|
| [`/shipwright:shipwright`](plugins/shipwright/commands/shipwright.md) | TODO |
| [`/shipwright:feedback`](plugins/shipwright/commands/feedback.md) | TODO |
```

Keep Installation, Team Setup, Contributing, and Attribution sections unchanged.

**Step 2: Run the validate-readme smoke test**

Run: `bash plugins/dockyard/tests/smoke/validate-readme.sh`

Expected: PASS — all commands and skills now have entries (even though descriptions are TODO).

**Step 3: Commit the structural skeleton**

```bash
git add README.md
git commit -m "feat: add README catalog structure with placeholder descriptions"
```

---

### Task 6: Populate descriptions interactively

Use the `/update-readme` skill to replace each TODO with a compelling description. This is an interactive step — Claude reads each file, drafts a description, asks the user for extra context, and refines.

**Step 1: Invoke /update-readme**

The skill walks through each TODO entry. For each one, Claude:
1. Reads the full command/skill file
2. Drafts a value-oriented description
3. Asks the user for extra context
4. Writes the final description to README.md

**Step 2: Review the full README**

Read through the complete README to verify formatting, links, and flow.

**Step 3: Run full smoke tests**

Run: `bash plugins/dockyard/tests/smoke/run-all.sh`

Expected: all 5 suites pass.

**Step 4: Commit**

```bash
git add README.md
git commit -m "feat: populate README catalog with command and skill descriptions"
```

---

### Task 7: Update CLAUDE.md smoke test count

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update the test description**

Change "Runs 4 suites" to "Runs 5 suites" and add "readme" to the list:

```
Runs 5 suites: structure, skills, agents, commands, readme. Validates both plugins.
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md to reflect 5 smoke test suites"
```

---

### Task 8: Final verification

**Step 1: Run all smoke tests**

Run: `bash plugins/dockyard/tests/smoke/run-all.sh`

Expected: 5/5 suites pass.

**Step 2: Test pre-commit hook end-to-end**

Temporarily create a fake command, stage it, and verify the hook blocks:

```bash
echo "---\ndescription: test\n---\n# Test" > plugins/dockyard/commands/test-fake.md
git add plugins/dockyard/commands/test-fake.md
git commit -m "test" 2>&1  # should fail with "README.md is missing entries"
git reset HEAD plugins/dockyard/commands/test-fake.md
rm plugins/dockyard/commands/test-fake.md
```

**Step 3: Verify README links work**

Spot-check that the relative links in the README resolve to actual files.
