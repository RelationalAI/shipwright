> **SUPERSEDED** — See [2026-03-04-doc-digest-v3-design.md](2026-03-04-doc-digest-v3-design.md)

# Doc Digest Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Simplify doc-digest from a three-file system (command + skill + agent) with disposition modes and PR integration into a two-file system (command + skill) with inline change application and intent inference.

**Architecture:** Command invokes skill directly (no agent). Skill handles everything: chunking, presentation, analysis, feedback with intent inference, ripple propagation, change tracking, and end-of-review summary. No disposition modes, no PR detection, no code file chunking.

**Tech Stack:** Markdown skill files, bash smoke tests, bash + curl + jq behavioral tests against Claude API.

**Design doc:** `plugins/dockyard/docs/plans/2026-03-03-doc-digest-redesign.md`

---

### Task 1: Rewrite the skill file

**Files:**
- Modify: `plugins/dockyard/skills/doc-digest/SKILL.md` (full rewrite)

**Step 1: Read current skill for reference**

Read `plugins/dockyard/skills/doc-digest/SKILL.md` (137 lines) and the design doc `plugins/dockyard/docs/plans/2026-03-03-doc-digest-redesign.md`.

**Step 2: Write the new skill**

Replace the entire contents of `plugins/dockyard/skills/doc-digest/SKILL.md` with the redesigned version. The new skill must contain these sections in this order:

1. **Frontmatter** — keep existing `name: doc-digest` and `description`. Update description to remove "change management" and "PR integration" language.

2. **Overview** — One sentence: walk user through a document section by section with analysis and feedback tracking.

3. **Setup** — Same as current: read entire doc, 2000-line guardrail warning, parse into sections, initialize tracker with `pending` status.

4. **Chunking Strategy** — Per design doc:
   - Supported file types: Markdown, YAML/JSON, plain text. **No code files.**
   - Remove the `Code: function/class/block boundaries` line from non-markdown section.
   - Keep everything else: `##` headings (fallback to `#`), >150 line sub-chunking, <5 line merging, 30-150 line target.

5. **Presenting Sections** — Same as current except:
   - Change the feedback prompt from `"Does this look right, or do you have feedback?"` to `"Any feedback, or ready to move on?"`
   - Keep section header format, sub-chunk notation, rendering rules.

6. **Per-Section Analysis** — Same as current: summary, flags (Inconsistency, Clarity, Completeness, Redundancy), cite sections, no filler. No changes needed.

7. **Handling Feedback** — Replace current section. New content per design doc:
   - Section statuses: `pending` → `approved` | `has-feedback` | `punted`
   - Table mapping user phrases to statuses and actions (looks good → approved; skip → punted; opinion → has-feedback + log; actionable instruction → has-feedback + apply edit + ripple check)
   - Intent inference paragraph: imperative verb + specific change → apply. Opinion → log. Ambiguous → ask.
   - Navigation: jump by number, check status, ask clarifications.
   - Remove all references to "disposition" and "suggestion mode".

8. **Cross-Section Ripple Propagation** — Rename from "Cross-Section Changes" and rewrite per design:
   - Triggered only when user requests a change (not during analysis).
   - Steps: make edit → scan document → tell user if ripples → ask before fixing → log as `ripple` → never silent changes.
   - When affected section comes up later: "Already updated due to change in section N."
   - Remove "(edit mode only)" qualifier — there are no modes.

9. **Change Tracker** — Update types from `edit, suggestion, ripple, punted` to `edit, ripple, punted, feedback`. Update statuses from `applied, pending` to `applied, noted`.

10. **Output** — Update per design:
    - Stats line (same format)
    - Change log table with updated types and statuses
    - Change wrap-up prompt to: "Want me to apply any of the noted feedback, revisit any section, or is the review complete?"
    - Remove all PR comment posting references.

**Sections to delete entirely:**
- `## Feedback Disposition` (lines 82-98) — replaced by intent inference in Handling Feedback
- All references to "suggestion mode", "edit mode", "disposition", PR detection, `gh` commands

**Step 3: Verify skill structure**

Read the rewritten file and verify:
- All 8 sections present (Overview, Setup, Chunking Strategy, Presenting Sections, Per-Section Analysis, Handling Feedback, Cross-Section Ripple Propagation, Change Tracker, Output — 9 total including frontmatter)
- No references to: `disposition`, `suggestion mode`, `edit mode`, `PR`, `gh pr`, `gh `, `code: function/class`
- References present for: `pending`, `approved`, `has-feedback`, `punted`, `edit`, `ripple`, `feedback`, `Inconsistency`, `Clarity`, `Completeness`, `Redundancy`, `2000`, `150`

**Step 4: Commit**

```bash
git add plugins/dockyard/skills/doc-digest/SKILL.md
git commit -m "refactor: rewrite doc-digest skill per redesign — drop disposition, add intent inference"
```

---

### Task 2: Rewrite the command file

**Files:**
- Modify: `plugins/dockyard/commands/doc-digest.md`

**Step 1: Write the new command**

Replace contents of `plugins/dockyard/commands/doc-digest.md`. The command should:
- Keep the YAML frontmatter with `description` and `argument-hint: <doc-path>`
- Invoke the skill directly: reference `skills/doc-digest/SKILL.md`
- Pass `$ARGUMENTS` as the document path
- If no arguments, ask the user for the path
- **Remove** all references to the agent file (`agents/doc-digest.md`)

New content (approximately):

```markdown
---
description: Walk through any document section by section for interactive review
argument-hint: <doc-path>
---

Read and follow the doc-digest skill from `skills/doc-digest/SKILL.md`.

Use `$ARGUMENTS` as the document path. If no arguments provided, ask the user for the document path before proceeding.
```

**Step 2: Verify**

Read the file and confirm:
- References `skills/doc-digest/SKILL.md`
- Does NOT reference `agents/doc-digest.md`
- Has frontmatter with description and argument-hint

**Step 3: Commit**

```bash
git add plugins/dockyard/commands/doc-digest.md
git commit -m "refactor: command invokes skill directly, remove agent reference"
```

---

### Task 3: Delete the agent file

**Files:**
- Delete: `plugins/dockyard/agents/doc-digest.md`

**Step 1: Delete the agent file**

```bash
git rm plugins/dockyard/agents/doc-digest.md
```

**Step 2: Verify no remaining agent references**

Search the entire dockyard plugin for references to `agents/doc-digest.md`:

```bash
grep -r "agents/doc-digest" plugins/dockyard/ --include="*.md" --include="*.sh" --include="*.json"
```

Expected: no matches (command was already updated in Task 2).

**Step 3: Commit**

```bash
git commit -m "refactor: delete doc-digest agent file — skill handles everything"
```

---

### Task 4: Update smoke test — validate-doc-digest-consistency.sh

**Files:**
- Modify: `plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh` (134 lines → ~90 lines)

**Step 1: Read current test**

Read `plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh`.

**Step 2: Rewrite the smoke test**

The test currently validates 3 files (skill, agent, command) and checks disposition types, agent linkage, and PR integration. Rewrite to validate only skill + command:

**Variables at top:**
- Keep `SKILL` and `COMMAND` paths
- Remove `AGENT` path
- Keep `PASS`/`FAIL` counters and helper functions

**File presence (update):**
- Check `SKILL` and `COMMAND` exist and are non-empty
- Remove agent file check

**Status consistency (keep as-is):**
- Extract Handling Feedback section from skill
- Verify `pending`, `approved`, `has-feedback`, `punted` are all referenced

**Change log types (replace disposition types):**
- Extract from Change Tracker through Output sections
- Verify types: `edit`, `ripple`, `punted`, `feedback`
- Remove references to `suggestion` type
- This replaces the old "Disposition types" check

**Analysis flags (keep as-is):**
- Verify `Inconsistency`, `Clarity`, `Completeness`, `Redundancy` in skill

**Command-skill linkage (replace agent linkage):**
- Verify command references `skills/doc-digest/SKILL.md`
- Remove: agent references skill check
- Remove: agent disposition detection check
- Remove: agent PR integration check
- Remove: command references agent check

**Guardrails (keep as-is):**
- Verify skill mentions `2000` and `150`

**Step 3: Run the test**

```bash
bash plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh
```

Expected: all checks pass.

**Step 4: Commit**

```bash
git add plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh
git commit -m "test: update doc-digest smoke test — remove agent/disposition/PR checks"
```

---

### Task 5: Update smoke test — validate-agents.sh

**Files:**
- Modify: `plugins/dockyard/tests/smoke/validate-agents.sh`

**Step 1: Read current test**

Read `plugins/dockyard/tests/smoke/validate-agents.sh`.

**Step 2: Remove doc-digest agent validation**

Remove the `validate_agent` call for `plugins/dockyard/agents/doc-digest.md` (lines 59-62). The dockyard section currently only validates doc-digest, so the "Dockyard public agents" section becomes empty. Replace it with a comment or remove the section header.

If doc-digest was the only dockyard agent, either:
- Remove the "Dockyard public agents" section entirely, OR
- Leave a comment: `# No public dockyard agents currently`

Keep the Shipwright internal agents section and cross-plugin skill reference validation unchanged.

**Step 3: Run the test**

```bash
bash plugins/dockyard/tests/smoke/validate-agents.sh
```

Expected: all remaining checks pass.

**Step 4: Commit**

```bash
git add plugins/dockyard/tests/smoke/validate-agents.sh
git commit -m "test: remove doc-digest from agent validation — agent file deleted"
```

---

### Task 6: Update behavioral tests — remove Test 6 and agent references

**Files:**
- Modify: `plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh` (295 lines)

**Step 1: Read current test**

Read `plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh`.

**Step 2: Remove agent from system prompt**

The `SYSTEM` variable (line 99) currently includes both skill and agent content:
```bash
SYSTEM="$(printf 'You are the Doc Digest agent.\n\nSKILL:\n%s\n\nAGENT:\n%s' "$SKILL_CONTENT" "$AGENT_CONTENT")"
```

Change to only include the skill:
```bash
SYSTEM="$(printf 'You are the Doc Digest assistant.\n\nSKILL:\n%s' "$SKILL_CONTENT")"
```

Remove the `AGENT` variable assignment (line ~23-24) and the `AGENT_CONTENT=$(cat "$AGENT")` line (line ~96).

**Step 3: Remove Test 6 (PR suggestion mode)**

Delete lines 260-283 (Test 6: PR-detected suggestion mode). This test validates disposition detection and PR context, which no longer exist.

Also remove the `SYSTEM_WITH_PR` variable and `PR_CONTEXT` that are only used by Test 6.

**Step 4: Update feedback prompt assertions**

In Test 1 (line 128-131), the feedback prompt check looks for `(look right|feedback|thoughts)\?`. Update to also match the new prompt "Any feedback, or ready to move on?":

```bash
if echo "$RESULT_T1" | grep -qiE '(feedback|move on|thoughts)\?'; then
```

**Step 5: Update Test 2 and Test 4 user prompts**

Tests 2, 4, and 5 have user prompts that say `Do not ask to confirm disposition.` Remove this clause from all user prompts — there is no disposition to confirm.

**Step 6: Update known coverage gaps comment**

Remove the "Change tracker accuracy" gap about ripple propagation in disposition modes. Keep the 2000-line and multi-turn gaps.

**Step 7: Run the test (if API key available)**

```bash
ANTHROPIC_API_KEY=<key> bash plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh
```

If no API key, verify the script parses correctly:
```bash
bash -n plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh
```

**Step 8: Commit**

```bash
git add plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh
git commit -m "test: remove Test 6 (PR mode) and agent refs from behavioral tests"
```

---

### Task 7: Run all smoke tests end-to-end

**Files:**
- None (validation only)

**Step 1: Run the full smoke test suite**

```bash
bash plugins/dockyard/tests/smoke/run-all.sh
```

Expected: all 5 suites pass. If any fail, investigate and fix before proceeding.

**Step 2: Run the behavioral test syntax check**

```bash
bash -n plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh
```

Expected: no syntax errors.

**Step 3: Verify no stale references**

```bash
grep -r "agents/doc-digest" plugins/ --include="*.md" --include="*.sh" --include="*.json"
grep -r "disposition" plugins/dockyard/skills/doc-digest/ plugins/dockyard/commands/doc-digest.md
grep -r "suggestion mode" plugins/dockyard/skills/doc-digest/ plugins/dockyard/commands/doc-digest.md
grep -r "gh pr" plugins/dockyard/skills/doc-digest/ plugins/dockyard/commands/doc-digest.md
```

Expected: no matches for any of these.

**Step 4: Commit (only if fixes were needed)**

If any fixes were required:
```bash
git add -A
git commit -m "fix: address smoke test failures from redesign"
```

---

### Task 8: Clean up old design doc reference

**Files:**
- Modify: `plugins/dockyard/docs/plans/2026-03-01-doc-digest-design.md` (optional — add superseded note)

**Step 1: Add superseded header**

Add to the top of `plugins/dockyard/docs/plans/2026-03-01-doc-digest-design.md`:

```markdown
> **Superseded** by `2026-03-03-doc-digest-redesign.md`. Kept for historical context.
```

**Step 2: Commit**

```bash
git add plugins/dockyard/docs/plans/2026-03-01-doc-digest-design.md
git commit -m "docs: mark original design doc as superseded"
```
