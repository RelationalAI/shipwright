# Marketplace Conversion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure the shipwright repo from a single plugin into a marketplace containing two plugins (dockyard + shipwright).

**Architecture:** Hybrid monorepo marketplace. All content moves under `plugins/dockyard/` or `plugins/shipwright/`. Root level holds marketplace infrastructure (marketplace.json, README, CONTRIBUTING, CODEOWNERS, templates). Existing `.claude-plugin/plugin.json` is replaced with `marketplace.json`.

**Tech Stack:** Claude Code plugin system, bash (hooks), JSON (manifests), Markdown (skills/commands/agents)

**Design doc:** `docs/plans/2026-02-27-marketplace-conversion-design.md`

---

## File Move Map

This is the complete mapping from current location to target location. Reference this for every task.

### Root level (marketplace infrastructure)

| Current | Target | Action |
|---------|--------|--------|
| `.claude-plugin/plugin.json` | `.claude-plugin/marketplace.json` | Replace with marketplace.json |
| `README.md` | `README.md` | Rewrite for marketplace |
| `THIRD_PARTY_NOTICES` | `THIRD_PARTY_NOTICES` | Stays |
| `.gitignore` | `.gitignore` | Stays |
| N/A | `CONTRIBUTING.md` | Create new |
| N/A | `CODEOWNERS` | Create new |
| N/A | `templates/SKILL_TEMPLATE.md` | Create placeholder |
| N/A | `templates/AGENT_TEMPLATE.md` | Create placeholder |
| `docs/plans/*` | `docs/plans/*` | Stays at marketplace root |

### Dockyard plugin (`plugins/dockyard/`)

| Current | Target |
|---------|--------|
| `skills/brownfield-analysis/SKILL.md` | `plugins/dockyard/skills/brownfield-analysis/SKILL.md` |
| `skills/observability/SKILL.md` | `plugins/dockyard/skills/observability/SKILL.md` |
| `skills/observability/RESEARCH.md` | `plugins/dockyard/skills/observability/RESEARCH.md` |
| `commands/debug.md` | `plugins/dockyard/commands/debug.md` |
| `commands/codebase-analyze.md` | `plugins/dockyard/commands/codebase-analyze.md` |
| `commands/doc-digest.md` | `plugins/dockyard/commands/doc-digest.md` |
| `commands/investigate.md` | `plugins/dockyard/commands/investigate.md` |
| `agents/doc-digest.md` | `plugins/dockyard/agents/doc-digest.md` |
| `docs/skills/brownfield/mvp-requirements.md` | `plugins/dockyard/docs/skills/brownfield/mvp-requirements.md` |
| `tests/fixtures/sample-app/*` | `plugins/dockyard/tests/fixtures/sample-app/*` |
| `tests/smoke/*` | `plugins/dockyard/tests/smoke/*` |
| N/A | `plugins/dockyard/.claude-plugin/plugin.json` (create) |
| N/A | `plugins/dockyard/commands/feedback.md` (create) |

### Shipwright plugin (`plugins/shipwright/`)

| Current | Target |
|---------|--------|
| `commands/shipwright.md` | `plugins/shipwright/commands/shipwright.md` |
| `internal/agents/triage.md` | `plugins/shipwright/internal/agents/triage.md` |
| `internal/agents/implementer.md` | `plugins/shipwright/internal/agents/implementer.md` |
| `internal/agents/reviewer.md` | `plugins/shipwright/internal/agents/reviewer.md` |
| `internal/agents/validator.md` | `plugins/shipwright/internal/agents/validator.md` |
| `internal/skills/tdd/SKILL.md` | `plugins/shipwright/internal/skills/tdd/SKILL.md` |
| `internal/skills/systematic-debugging/SKILL.md` | `plugins/shipwright/internal/skills/systematic-debugging/SKILL.md` |
| `internal/skills/verification-before-completion/SKILL.md` | `plugins/shipwright/internal/skills/verification-before-completion/SKILL.md` |
| `internal/skills/anti-rationalization/SKILL.md` | `plugins/shipwright/internal/skills/anti-rationalization/SKILL.md` |
| `internal/skills/decision-categorization/SKILL.md` | `plugins/shipwright/internal/skills/decision-categorization/SKILL.md` |
| `docs/design/shipwright-design-v1.md` | `plugins/shipwright/docs/design/shipwright-design-v1.md` |
| `docs/milestones/m1-tier1-bugfix.md` | `plugins/shipwright/docs/milestones/m1-tier1-bugfix.md` |
| `docs/milestones/m1-verification-report.md` | `plugins/shipwright/docs/milestones/m1-verification-report.md` |
| `docs/research/shipwright-vs-others-v1.md` | `plugins/shipwright/docs/research/shipwright-vs-others-v1.md` |
| `docs/research/shipwright-ideas-from-beads-gsd-v1.md` | `plugins/shipwright/docs/research/shipwright-ideas-from-beads-gsd-v1.md` |
| N/A | `plugins/shipwright/.claude-plugin/plugin.json` (create) |
| N/A | `plugins/shipwright/hooks/hooks.json` (create) |
| N/A | `plugins/shipwright/hooks/check-dockyard.sh` (create) |
| N/A | `plugins/shipwright/commands/feedback.md` (create) |

### Files to delete after move

| File | Reason |
|------|--------|
| `commands/report.md` | Replaced by `/feedback` in each plugin |
| `commands/promote.md` | Removed from design |
| `internal/plugin.stable.json` | Replaced by marketplace.json |
| `.claude/commands/doc-digest.md` | Local override, no longer needed |
| `.claude/commands/investigate.md` | Local override, no longer needed |

---

## Tasks

### Task 1: Create marketplace directory scaffold

**Files:**
- Create: `plugins/dockyard/.claude-plugin/` (directory)
- Create: `plugins/dockyard/skills/` (directory)
- Create: `plugins/dockyard/commands/` (directory)
- Create: `plugins/dockyard/agents/` (directory)
- Create: `plugins/dockyard/docs/` (directory)
- Create: `plugins/dockyard/tests/` (directory)
- Create: `plugins/shipwright/.claude-plugin/` (directory)
- Create: `plugins/shipwright/hooks/` (directory)
- Create: `plugins/shipwright/commands/` (directory)
- Create: `plugins/shipwright/internal/agents/` (directory)
- Create: `plugins/shipwright/internal/skills/` (directory)
- Create: `plugins/shipwright/docs/` (directory)
- Create: `plugins/shipwright/tests/` (directory)
- Create: `templates/` (directory)

**Step 1: Create all directories**

```bash
mkdir -p plugins/dockyard/{.claude-plugin,skills,commands,agents,docs,tests}
mkdir -p plugins/shipwright/{.claude-plugin,hooks,commands,docs,tests}
mkdir -p plugins/shipwright/internal/{agents,skills}
mkdir -p templates
```

**Step 2: Commit**

```bash
# Add .gitkeep files so empty dirs are tracked
touch plugins/dockyard/tests/.gitkeep plugins/shipwright/tests/.gitkeep
git add plugins/ templates/
git commit -m "scaffold: Create marketplace directory structure"
```

---

### Task 2: Create marketplace.json (replace plugin.json)

**Files:**
- Delete: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

**Step 1: Create marketplace.json**

Write `.claude-plugin/marketplace.json` with the exact content from design doc Section 5.

**Step 2: Delete old plugin.json**

```bash
git rm .claude-plugin/plugin.json
```

**Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat: Replace plugin.json with marketplace.json registry"
```

---

### Task 3: Create Dockyard plugin manifest

**Files:**
- Create: `plugins/dockyard/.claude-plugin/plugin.json`

**Step 1: Write plugin.json**

Write `plugins/dockyard/.claude-plugin/plugin.json` with exact content from design doc Section 6 (Dockyard manifest).

**Step 2: Commit**

```bash
git add plugins/dockyard/.claude-plugin/plugin.json
git commit -m "feat: Add dockyard plugin manifest"
```

---

### Task 4: Create Shipwright plugin manifest

**Files:**
- Create: `plugins/shipwright/.claude-plugin/plugin.json`

**Step 1: Write plugin.json**

Write `plugins/shipwright/.claude-plugin/plugin.json` with exact content from design doc Section 6 (Shipwright manifest).

**Step 2: Commit**

```bash
git add plugins/shipwright/.claude-plugin/plugin.json
git commit -m "feat: Add shipwright plugin manifest"
```

---

### Task 5: Move Dockyard skills

**Files:**
- Move: `skills/brownfield-analysis/` -> `plugins/dockyard/skills/brownfield-analysis/`
- Move: `skills/observability/` -> `plugins/dockyard/skills/observability/`

**Step 1: Move files using git mv**

```bash
git mv skills/brownfield-analysis plugins/dockyard/skills/brownfield-analysis
git mv skills/observability plugins/dockyard/skills/observability
```

**Step 2: Verify files exist at new location**

```bash
ls plugins/dockyard/skills/brownfield-analysis/SKILL.md
ls plugins/dockyard/skills/observability/SKILL.md
ls plugins/dockyard/skills/observability/RESEARCH.md
```

**Step 3: Commit**

```bash
git commit -m "refactor: Move skills to dockyard plugin"
```

---

### Task 6: Move Dockyard commands

**Files:**
- Move: `commands/debug.md` -> `plugins/dockyard/commands/debug.md`
- Move: `commands/codebase-analyze.md` -> `plugins/dockyard/commands/codebase-analyze.md`
- Move: `commands/doc-digest.md` -> `plugins/dockyard/commands/doc-digest.md`
- Move: `commands/investigate.md` -> `plugins/dockyard/commands/investigate.md`

**Step 1: Move files using git mv**

```bash
git mv commands/debug.md plugins/dockyard/commands/debug.md
git mv commands/codebase-analyze.md plugins/dockyard/commands/codebase-analyze.md
git mv commands/doc-digest.md plugins/dockyard/commands/doc-digest.md
git mv commands/investigate.md plugins/dockyard/commands/investigate.md
```

**Step 2: Commit**

```bash
git commit -m "refactor: Move standalone commands to dockyard plugin"
```

---

### Task 7: Move Dockyard agent

**Files:**
- Move: `agents/doc-digest.md` -> `plugins/dockyard/agents/doc-digest.md`

**Step 1: Move file**

```bash
git mv agents/doc-digest.md plugins/dockyard/agents/doc-digest.md
```

**Step 2: Commit**

```bash
git commit -m "refactor: Move doc-digest agent to dockyard plugin"
```

---

### Task 8: Move Dockyard docs and tests

**Files:**
- Move: `docs/skills/brownfield/` -> `plugins/dockyard/docs/skills/brownfield/`
- Move: `tests/fixtures/` -> `plugins/dockyard/tests/fixtures/`
- Move: `tests/smoke/` -> `plugins/dockyard/tests/smoke/`

**Step 1: Move files**

```bash
git mv docs/skills plugins/dockyard/docs/skills
git mv tests/fixtures plugins/dockyard/tests/fixtures
git mv tests/smoke plugins/dockyard/tests/smoke
```

**Step 2: Remove empty parent dirs and leftover files**

```bash
# tests/smoke/run-all.sh references may need path updates -- check in Task 14
rm -f plugins/dockyard/tests/.gitkeep
```

**Step 3: Commit**

```bash
git add -A
git commit -m "refactor: Move docs and tests to dockyard plugin"
```

---

### Task 9: Move Shipwright command

**Files:**
- Move: `commands/shipwright.md` -> `plugins/shipwright/commands/shipwright.md`

**Step 1: Move file**

```bash
git mv commands/shipwright.md plugins/shipwright/commands/shipwright.md
```

**Step 2: Commit**

```bash
git commit -m "refactor: Move orchestrator command to shipwright plugin"
```

---

### Task 10: Move Shipwright internal agents and skills

**Files:**
- Move: `internal/agents/` -> `plugins/shipwright/internal/agents/`
- Move: `internal/skills/` -> `plugins/shipwright/internal/skills/`

**Step 1: Move files**

```bash
git mv internal/agents/triage.md plugins/shipwright/internal/agents/triage.md
git mv internal/agents/implementer.md plugins/shipwright/internal/agents/implementer.md
git mv internal/agents/reviewer.md plugins/shipwright/internal/agents/reviewer.md
git mv internal/agents/validator.md plugins/shipwright/internal/agents/validator.md
git mv internal/skills/tdd plugins/shipwright/internal/skills/tdd
git mv internal/skills/systematic-debugging plugins/shipwright/internal/skills/systematic-debugging
git mv internal/skills/verification-before-completion plugins/shipwright/internal/skills/verification-before-completion
git mv internal/skills/anti-rationalization plugins/shipwright/internal/skills/anti-rationalization
git mv internal/skills/decision-categorization plugins/shipwright/internal/skills/decision-categorization
```

**Step 2: Commit**

```bash
git add -A
git commit -m "refactor: Move internal agents and skills to shipwright plugin"
```

---

### Task 11: Move Shipwright docs

**Files:**
- Move: `docs/design/` -> `plugins/shipwright/docs/design/`
- Move: `docs/milestones/` -> `plugins/shipwright/docs/milestones/`
- Move: `docs/research/` -> `plugins/shipwright/docs/research/`

**Step 1: Move files**

```bash
git mv docs/design plugins/shipwright/docs/design
git mv docs/milestones plugins/shipwright/docs/milestones
git mv docs/research plugins/shipwright/docs/research
```

**Step 2: Commit**

```bash
git commit -m "refactor: Move design docs to shipwright plugin"
```

---

### Task 12: Delete obsolete files

**Files:**
- Delete: `commands/report.md` (replaced by /feedback)
- Delete: `commands/promote.md` (removed from design)
- Delete: `internal/plugin.stable.json` (replaced by marketplace.json)
- Delete: `.claude/commands/doc-digest.md` (local override, no longer needed)
- Delete: `.claude/commands/investigate.md` (local override, no longer needed)

**Step 1: Remove files**

```bash
git rm commands/report.md
git rm commands/promote.md
git rm internal/plugin.stable.json
git rm .claude/commands/doc-digest.md
git rm .claude/commands/investigate.md
```

**Step 2: Clean up any empty directories**

```bash
# Remove empty dirs left behind
rmdir commands/ 2>/dev/null || true
rmdir internal/ 2>/dev/null || true
rmdir agents/ 2>/dev/null || true
rmdir skills/ 2>/dev/null || true
rmdir tests/ 2>/dev/null || true
rmdir docs/skills/ 2>/dev/null || true
```

**Step 3: Commit**

```bash
git add -A
git commit -m "cleanup: Remove obsolete files (report, promote, stable manifest, local overrides)"
```

---

### Task 13: Create dependency enforcement hook

**Files:**
- Create: `plugins/shipwright/hooks/hooks.json`
- Create: `plugins/shipwright/hooks/check-dockyard.sh`

**Step 1: Write hooks.json**

Write `plugins/shipwright/hooks/hooks.json` with exact content from design doc Section 7.

**Step 2: Write check-dockyard.sh**

Write `plugins/shipwright/hooks/check-dockyard.sh` with exact content from design doc Section 7.

**Step 3: Make script executable**

```bash
chmod +x plugins/shipwright/hooks/check-dockyard.sh
```

**Step 4: Commit**

```bash
git add plugins/shipwright/hooks/
git commit -m "feat: Add SessionStart hook to enforce dockyard dependency"
```

---

### Task 14: Create feedback commands

**Files:**
- Create: `plugins/dockyard/commands/feedback.md`
- Create: `plugins/shipwright/commands/feedback.md`

**Step 1: Write Dockyard feedback command**

Write `plugins/dockyard/commands/feedback.md` -- a command that files bugs/feedback against the dockyard plugin on the `RelationalAI/shipwright` repo. Base it on the existing `report.md` pattern but target dockyard-specific labels.

**Step 2: Write Shipwright feedback command**

Write `plugins/shipwright/commands/feedback.md` -- same pattern but for the shipwright plugin with shipwright-specific labels.

**Step 3: Commit**

```bash
git add plugins/dockyard/commands/feedback.md plugins/shipwright/commands/feedback.md
git commit -m "feat: Add /feedback command to both plugins"
```

---

### Task 15: Create marketplace root files

**Files:**
- Create: `CODEOWNERS`
- Create: `CONTRIBUTING.md`
- Create: `templates/SKILL_TEMPLATE.md` (placeholder)
- Create: `templates/AGENT_TEMPLATE.md` (placeholder)
- Rewrite: `README.md`

**Step 1: Write CODEOWNERS**

```
# Marketplace registry -- plugin additions require CODEOWNERS approval
.claude-plugin/marketplace.json @RelationalAI/eng-ai-agents

# Plugin-level ownership
plugins/dockyard/ @RelationalAI/eng-ai-agents
plugins/shipwright/ @RelationalAI/eng-ai-agents
```

Note: Verify the correct GitHub team name. Use `@omohamed-rai` as fallback if team does not exist.

**Step 2: Write CONTRIBUTING.md**

Cover:
- How to add skills/agents to existing plugins via PR
- Which plugin to contribute to (standalone -> dockyard, orchestration -> shipwright)
- Quality gates (template compliance, smoke test, PR review)
- How to request a new plugin (CODEOWNERS approval required)
- Version bump requirement for cache invalidation

**Step 3: Write template placeholders**

Create `templates/SKILL_TEMPLATE.md` and `templates/AGENT_TEMPLATE.md` with basic structure placeholders and a note that full templates are tracked in RAI-47777.

**Step 4: Rewrite README.md**

Cover:
- What shipwright-marketplace is
- Available plugins (dockyard, shipwright) with descriptions
- Installation instructions (individual + team settings.json)
- Link to CONTRIBUTING.md

**Step 5: Commit**

```bash
git add CODEOWNERS CONTRIBUTING.md templates/ README.md
git commit -m "feat: Add marketplace root files (CODEOWNERS, CONTRIBUTING, README, templates)"
```

---

### Task 16: Update smoke tests for new structure

**Files:**
- Modify: `plugins/dockyard/tests/smoke/validate-structure.sh`
- Modify: `plugins/dockyard/tests/smoke/validate-commands.sh`
- Modify: `plugins/dockyard/tests/smoke/validate-skills.sh`
- Modify: `plugins/dockyard/tests/smoke/validate-agents.sh`
- Modify: `plugins/dockyard/tests/smoke/run-all.sh`

**Step 1: Read each smoke test to understand current paths**

Read all 5 smoke test files.

**Step 2: Update all path references**

Update file path assertions in each test to reflect the new `plugins/dockyard/` and `plugins/shipwright/` structure. The smoke tests should validate:
- marketplace.json exists at `.claude-plugin/marketplace.json`
- Both plugin.json files exist
- All skills, commands, agents are at their new paths
- hooks/ directory exists for shipwright
- CODEOWNERS and CONTRIBUTING.md exist

**Step 3: Run smoke tests**

```bash
cd /Users/omohamed/code/shipwright
bash plugins/dockyard/tests/smoke/run-all.sh
```

Expected: All checks pass.

**Step 4: Commit**

```bash
git add plugins/dockyard/tests/smoke/
git commit -m "test: Update smoke tests for marketplace directory structure"
```

---

### Task 17: Final verification

**Step 1: Verify directory structure matches design**

```bash
find plugins/ -type f | sort
```

Compare output against the design doc Section 4 tree.

**Step 2: Verify no orphaned files at root**

```bash
ls -la commands/ agents/ skills/ internal/ 2>/dev/null
```

Expected: None of these directories should exist.

**Step 3: Verify marketplace.json is valid JSON**

```bash
jq . .claude-plugin/marketplace.json
```

Expected: Valid JSON output with two plugins listed.

**Step 4: Verify both plugin.json files are valid JSON**

```bash
jq . plugins/dockyard/.claude-plugin/plugin.json
jq . plugins/shipwright/.claude-plugin/plugin.json
```

Expected: Valid JSON for both.

**Step 5: Verify hook script is executable**

```bash
test -x plugins/shipwright/hooks/check-dockyard.sh && echo "OK" || echo "FAIL"
```

Expected: OK

**Step 6: Run smoke tests one final time**

```bash
bash plugins/dockyard/tests/smoke/run-all.sh
```

Expected: All checks pass.

**Step 7: Commit any fixes if needed, then done**

---

## Task Summary

| Task | Description | Type |
|------|-------------|------|
| 1 | Create directory scaffold | Setup |
| 2 | Create marketplace.json | Create |
| 3 | Create Dockyard plugin manifest | Create |
| 4 | Create Shipwright plugin manifest | Create |
| 5 | Move Dockyard skills | Move |
| 6 | Move Dockyard commands | Move |
| 7 | Move Dockyard agent | Move |
| 8 | Move Dockyard docs and tests | Move |
| 9 | Move Shipwright command | Move |
| 10 | Move Shipwright internal agents and skills | Move |
| 11 | Move Shipwright docs | Move |
| 12 | Delete obsolete files | Cleanup |
| 13 | Create dependency enforcement hook | Create |
| 14 | Create feedback commands | Create |
| 15 | Create marketplace root files | Create |
| 16 | Update smoke tests | Test |
| 17 | Final verification | Verify |
