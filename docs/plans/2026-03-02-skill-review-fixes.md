# Observability Skill Review Fixes

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix issues identified during skill-creator standards review — add SKILL.md frontmatter for discoverability, remove unreferenced research files.

**Architecture:** Two independent fixes: (1) add YAML frontmatter to SKILL.md so the observability skill is discoverable for basic questions, (2) remove the `research/` directory that ships with the plugin but is never referenced at runtime.

**Tech Stack:** Markdown, bash (smoke tests)

---

## Issue Triage (from review)

| # | Issue | Disposition |
|---|---|---|
| 1+3 | SKILL.md lacks frontmatter — no skill-level discovery | **Fix** — add name + description |
| 2a | RESEARCH.md in git diff but doesn't exist | **Drop** — git diff artifact, not a real file |
| 2b | `research/` directory ships unreferenced | **Fix** — remove from plugin |
| 4 | Query patterns inflate platform.md | **Keep as-is** — 14 lines (4.6%) is negligible overhead, examples help model write correct queries, zero-complexity alternative to adding another conditional load path |

---

### Task 1: Add YAML frontmatter to SKILL.md (parallel with Task 2)

**Context:** The observability skill was intentionally stripped of frontmatter in commit `a8a893e` to hide `/observability` from the command picker. But this also prevents Claude from discovering the skill for basic observability questions like "what dataset has transaction status?" — which the routing table says should be answered directly from this skill. The fix: add frontmatter with a description that triggers for observability knowledge questions, NOT for operational commands (those are handled by `/investigate` and `/observe`).

**Files:**
- Modify: `plugins/dockyard/skills/observability/SKILL.md`

**Step 1: Add YAML frontmatter**

Add to the top of SKILL.md (before the existing `# Observability` heading):

```yaml
---
name: observability
description: >
  RAI observability domain knowledge — Observe datasets, correlation tags, triage signals, and MCP tool usage.
  Use this skill when the user asks questions about observability data (datasets, metrics, monitors, dashboards),
  needs help understanding what data is available in Observe, or asks basic questions about the RAI telemetry
  platform. For operational queries (health checks, alert status), suggest /observe instead. For incident
  investigation, suggest /investigate instead.
---
```

**Step 2: Verify the skill passes smoke tests**

Run: `bash plugins/dockyard/tests/smoke/run-all.sh`
Expected: All suites pass (the validate-skills suite checks for "title heading or frontmatter")

**Step 3: Verify the description won't cause /observability to appear as a command**

Confirm: SKILL.md frontmatter uses `name` and `description` only — no `argument-hint` field. Commands use `argument-hint` to appear in the command picker. Skills without `argument-hint` are discoverable as skills but don't appear as `/commands`.

**Step 4: Commit**

```bash
git add plugins/dockyard/skills/observability/SKILL.md
git commit -m "feat: add frontmatter to observability SKILL.md for skill-level discovery

The skill was previously hidden from discovery (commit a8a893e) to avoid
appearing in the command picker. This re-adds frontmatter with a description
scoped to domain knowledge questions — operational queries are routed to
/observe and /investigate via the routing table."
```

---

### Task 2: Remove unreferenced research/ directory (parallel with Task 1)

**Context:** The `research/` directory contains 3 files (`confluence.md`, `incidents.md`, `observe.md`) that were working notes used during skill development. No command, skill, or agent references them. They ship with the plugin but serve no runtime purpose.

**Files:**
- Delete: `plugins/dockyard/skills/observability/research/confluence.md`
- Delete: `plugins/dockyard/skills/observability/research/incidents.md`
- Delete: `plugins/dockyard/skills/observability/research/observe.md`
- Delete: `plugins/dockyard/skills/observability/research/` (directory)

**Step 1: Verify no file references the research/ directory**

Run: Search for `research/` in all files under `plugins/dockyard/`. Expected: zero matches in commands, skills, or agents (only matches in the research files themselves).

**Step 2: Delete the research directory**

```bash
rm -rf plugins/dockyard/skills/observability/research/
```

**Step 3: Run smoke tests**

Run: `bash plugins/dockyard/tests/smoke/run-all.sh`
Expected: All suites pass (no test references research/ files)

**Step 4: Commit**

```bash
git commit -m "chore: remove unreferenced research/ working notes from observability skill

These files were development artifacts used during skill creation. No command,
skill, or agent references them at runtime."
```

---

### Task 3: Bump plugin version

**Context:** Both changes modify the shipped plugin content. Bump the dockyard version so users receive the update.

**Files:**
- Modify: `plugins/dockyard/.claude-plugin/plugin.json`

**Step 1: Bump version**

Change `"version": "0.2.0"` to `"version": "0.2.1"`.

**Step 2: Commit**

```bash
git add plugins/dockyard/.claude-plugin/plugin.json
git commit -m "chore: bump dockyard version to 0.2.1"
```

---

## Execution Notes

- **Tasks 1 and 2 are independent** — can be dispatched in parallel
- **Task 3 depends on both** — run after 1 and 2 complete
- Total: ~5 minutes of work, 3 commits
