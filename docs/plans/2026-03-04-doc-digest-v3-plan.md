> **EXECUTED** — This plan has been fully implemented. Kept for historical context.

# Doc-Digest v3 Implementation Plan

**Goal:** Replace the overengineered 112-line doc-digest skill with a ~30-line version that specifies flow and trusts the model for analysis quality.

**Architecture:** Two-file system (SKILL.md + command). The skill defines three phases: setup (read + chunk), review loop (present + analyze + wait), wrap-up (summarize + offer). No formal state machine, tracker table, ripple propagation, or intent inference rules.

**Tech Stack:** Markdown skill files, bash smoke/behavioral tests, Claude API for behavioral tests.

---

### Task 1: Rewrite SKILL.md from scratch

**Files:**
- Rewrite: `plugins/dockyard/skills/doc-digest/SKILL.md`

**Step 1: Read the current SKILL.md to confirm starting state**

The current file is 112 lines. We're replacing it entirely.

**Step 2: Write the new SKILL.md**

```markdown
---
name: doc-digest
description: Interactive document review — section-by-section walkthrough with context-aware analysis. Use when the user wants to review, walk through, digest, or critique any document.
---

# Doc Digest

Read the entire document into context. Split it into semantic sections that can each be read in about 30 seconds (~20-40 lines). Use natural boundaries: headings, topic shifts, logical breaks. Never split mid-paragraph or mid-code-block. For YAML/JSON, split on top-level keys or logical groupings.

Code files are not supported — use code-review instead.

If the document exceeds 2000 lines, warn the user and confirm before proceeding.

Tell the user how many sections you found, then begin.

## Review Loop

For each section:

1. Show **Section N of M: [Title]**
2. Present the section content verbatim with its original formatting. Render markdown as markdown, YAML/JSON in fenced code blocks.
3. After a horizontal rule, show your analysis:
   - **Summary:** 1-2 sentences on what this section covers and how it relates to the rest of the document.
   - **Problems** (only if found): inconsistencies with other sections, unclear language, missing information, flawed reasoning. Describe each problem plainly.
4. Ask: *"Any questions or feedback, or ready to move on?"*
5. Wait for the user's response before advancing.

If the user asks a question, answer it using the full document context, then ask if they want to move on. If they request an edit, apply it and confirm. If they share an observation, note it as feedback and move on.

## Wrap-up

After the last section, summarize the review: how many sections were reviewed, key issues found, and any feedback that was noted but not applied. Offer to apply noted feedback or revisit any section.
```

**Step 3: Verify the file is ~30 lines and reads cleanly**

Run: `wc -l plugins/dockyard/skills/doc-digest/SKILL.md`
Expected: ~33 lines

**Step 4: Commit**

```bash
git add plugins/dockyard/skills/doc-digest/SKILL.md
git commit -m "feat(doc-digest): rewrite skill from scratch — v3 minimal design"
```

---

### Task 2: Rewrite smoke test for v3

**Files:**
- Rewrite: `plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh`

The old smoke test checks for internal terms from v2 (status names, flag categories, line thresholds, change log types). The v3 skill doesn't use any of those. The new smoke test should verify structural correctness only.

**Step 1: Write the new smoke test**

```bash
#!/usr/bin/env bash
#
# validate-doc-digest-consistency.sh — Verify doc-digest skill and command
# files are structurally sound and consistent.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/dockyard/skills/doc-digest/SKILL.md"
COMMAND="$REPO_ROOT/plugins/dockyard/commands/doc-digest.md"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== validate-doc-digest-consistency ==="

# --- Both files exist and are non-empty ---
echo ""
echo "File presence:"
for f in "$SKILL" "$COMMAND"; do
  label=$(basename "$(dirname "$f")")/$(basename "$f")
  if [ -s "$f" ]; then
    pass "$label exists"
  else
    fail "$label missing or empty"
  fi
done

# Agent file should NOT exist
AGENT="$REPO_ROOT/plugins/dockyard/agents/doc-digest.md"
if [ -f "$AGENT" ]; then
  fail "agent file should not exist (agents/doc-digest.md still present)"
else
  pass "agent file correctly absent"
fi

# --- Skill structure ---
echo ""
echo "Skill structure:"

# Has YAML frontmatter with name
if head -5 "$SKILL" | grep -q 'name: doc-digest'; then
  pass "skill has correct name in frontmatter"
else
  fail "skill missing name in frontmatter"
fi

# Has the three key sections
for section in "Review Loop" "Wrap-up"; do
  if grep -q "## $section" "$SKILL"; then
    pass "skill has '## $section' section"
  else
    fail "skill missing '## $section' section"
  fi
done

# Has 2000-line guardrail
if grep -q '2000' "$SKILL"; then
  pass "skill mentions 2000-line guardrail"
else
  fail "skill missing 2000-line guardrail"
fi

# References code-review for code files
if grep -qi 'code-review' "$SKILL"; then
  pass "skill references code-review for code files"
else
  fail "skill missing code-review reference"
fi

# --- Command references skill ---
echo ""
echo "Command-skill linkage:"
if grep -q 'skills/doc-digest/SKILL.md' "$COMMAND"; then
  pass "command references skill by path"
else
  fail "command does not reference skills/doc-digest/SKILL.md"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "validate-doc-digest-consistency: $PASS/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
```

**Step 2: Run the smoke test**

Run: `bash plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh`
Expected: All pass

**Step 3: Run the full smoke suite**

Run: `bash plugins/dockyard/tests/smoke/run-all.sh`
Expected: All 5 suites pass

**Step 4: Commit**

```bash
git add plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh
git commit -m "test(doc-digest): rewrite smoke test for v3 — structural checks only"
```

---

### Task 3: Rewrite behavioral tests for v3

**Files:**
- Rewrite: `plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh`
- Keep: all fixtures in `plugins/dockyard/tests/behavioral/doc-digest/fixtures/` (still useful)

The old behavioral tests checked for formal sub-chunk notation (2a), analysis with bold **Summary**/**Flags** labels, table formatting in summary, and specific section header patterns. The v3 tests should check:

1. Section headers appear (Section N of M)
2. Analysis appears after content (summary + problems if any)
3. Feedback prompt appears
4. Inconsistencies are detected in the inconsistent fixture
5. Non-markdown documents still get sectioned and analyzed

Drop: sub-chunking test (no formal sub-chunk notation in v3), formal change-log table test (no formal table in v3).

**Step 1: Write the new behavioral test file**

```bash
#!/usr/bin/env bash
#
# run-tests.sh — Behavioral tests for the doc-digest skill (v3).
#
# Requires: ANTHROPIC_API_KEY environment variable
# These tests call the Claude API and cost tokens. Run manually, not in CI.
#
set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/../../../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/dockyard/skills/doc-digest/SKILL.md"
FIXTURES="$TEST_DIR/fixtures"
PASS=0
FAIL=0
SKIP=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP  $1"; SKIP=$((SKIP + 1)); }

# --- Preflight ---
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "ANTHROPIC_API_KEY not set. Skipping behavioral tests."
  exit 0
fi

if ! command -v curl &>/dev/null || ! command -v jq &>/dev/null; then
  echo "curl and jq are required. Skipping behavioral tests."
  exit 0
fi

MODEL="${DOC_DIGEST_TEST_MODEL:-claude-haiku-4-5-20251001}"

LAST_STOP_REASON=""

call_claude() {
  local system_prompt="$1"
  local user_message="$2"

  local response
  response=$(curl -s https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$(jq -n \
      --arg model "$MODEL" \
      --arg system "$system_prompt" \
      --arg user "$user_message" \
      '{
        model: $model,
        max_tokens: 4096,
        temperature: 0,
        system: $system,
        messages: [{role: "user", content: $user}]
      }')")

  if ! echo "$response" | jq -e . &>/dev/null; then
    echo "API_ERROR: Non-JSON response" >&2
    LAST_STOP_REASON="error"
    echo "API_ERROR"
    return
  fi

  if echo "$response" | jq -e '.error' &>/dev/null; then
    echo "API_ERROR: $(echo "$response" | jq -r '.error.message')" >&2
    LAST_STOP_REASON="error"
    echo "API_ERROR"
    return
  fi

  LAST_STOP_REASON=$(echo "$response" | jq -r '.stop_reason // "unknown"')
  echo "$response" | jq -r '.content[0].text // "ERROR: no content"'
}

echo "=== doc-digest behavioral tests (v3) ==="
echo "Model: $MODEL"
echo ""

SKILL_CONTENT=$(cat "$SKILL")
SYSTEM="$(printf 'You are the Doc Digest assistant.\n\nSKILL:\n%s' "$SKILL_CONTENT")"

# --- Test 1: Section presentation ---
echo "Test 1: Section presentation"
DOC_CONTENT=$(cat "$FIXTURES/test-markdown.md")

USER="$(printf 'Review this document. Present only the FIRST section, then stop and wait.\n\nDocument path: test-markdown.md\nDocument content:\n%s' "$DOC_CONTENT")"

RESULT_T1=$(call_claude "$SYSTEM" "$USER")

if [[ "$RESULT_T1" == "API_ERROR" || -z "$RESULT_T1" ]]; then
  skip "Test 1 skipped — API call failed"
else
  if echo "$RESULT_T1" | grep -qiE 'section [0-9]+ of [0-9]+'; then
    pass "section header present (Section N of M)"
  else
    fail "section header missing"
  fi

  if echo "$RESULT_T1" | grep -qiE '(summary|overview|covers|describes)'; then
    pass "analysis contains summary"
  else
    fail "analysis missing summary"
  fi

  if echo "$RESULT_T1" | grep -qiE '(feedback|move on|next|thoughts|questions)\?'; then
    pass "feedback prompt present"
  else
    fail "feedback prompt missing"
  fi
fi

echo ""

# --- Test 2: Inconsistency detection ---
echo "Test 2: Inconsistency detection"
DOC_CONTENT=$(cat "$FIXTURES/test-inconsistent.md")

USER="$(printf 'Review this document. Present ALL sections with analysis. Do not wait for feedback — auto-approve each section.\n\nDocument path: test-inconsistent.md\nDocument content:\n%s' "$DOC_CONTENT")"

RESULT_T2=$(call_claude "$SYSTEM" "$USER")

if [[ "$RESULT_T2" == "API_ERROR" || -z "$RESULT_T2" ]]; then
  skip "Test 2 skipped — API call failed"
else
  FLAT_T2=$(echo "$RESULT_T2" | tr '\n' ' ')

  if echo "$FLAT_T2" | grep -qiE '(inconsisten|contradict|conflict|discrepanc|mismatch)'; then
    pass "inconsistency language detected"
  else
    fail "no inconsistency language found"
  fi

  if echo "$FLAT_T2" | grep -qiE '(inconsisten|contradict).{0,200}(approv|weekend|saturday|threshold|error.rate|5%|2%)'; then
    pass "specific contradiction identified"
  else
    fail "no specific contradiction identified"
  fi
fi

echo ""

# --- Test 3: Non-markdown chunking ---
echo "Test 3: Non-markdown chunking"
DOC_CONTENT=$(cat "$FIXTURES/test-no-headings.txt")

USER="$(printf 'Review this document. Present only the FIRST section, then stop and wait.\n\nDocument path: test-no-headings.txt\nDocument content:\n%s' "$DOC_CONTENT")"

RESULT_T3=$(call_claude "$SYSTEM" "$USER")

if [[ "$RESULT_T3" == "API_ERROR" || -z "$RESULT_T3" ]]; then
  skip "Test 3 skipped — API call failed"
else
  if echo "$RESULT_T3" | grep -qiE 'section [0-9]+ of [0-9]+'; then
    pass "plain text produces section headers"
  else
    fail "plain text missing section headers"
  fi

  if echo "$RESULT_T3" | grep -qiE '(summary|overview|covers|describes|about)'; then
    pass "plain text produces analysis"
  else
    fail "plain text missing analysis"
  fi
fi

echo ""

# --- Summary ---
echo "================================================================"
TOTAL=$((PASS + FAIL + SKIP))
echo "doc-digest behavioral tests: $PASS passed, $FAIL failed, $SKIP skipped (of $TOTAL)"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
```

**Step 2: Run the behavioral tests (if API key available)**

Run: `bash plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh`
Expected: All pass (or skip if no API key)

**Step 3: Commit**

```bash
git add plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh
git commit -m "test(doc-digest): rewrite behavioral tests for v3 — drop sub-chunk and table tests"
```

---

### Task 4: Delete the large-section fixture

**Files:**
- Delete: `plugins/dockyard/tests/behavioral/doc-digest/fixtures/test-large-section.md`

The large-section fixture was specifically built to test sub-chunking behavior (>150 line threshold, letter notation like 2a). The v3 skill has no formal sub-chunking rules, so this fixture has no corresponding test.

**Step 1: Delete the fixture**

Run: `rm plugins/dockyard/tests/behavioral/doc-digest/fixtures/test-large-section.md`

**Step 2: Commit**

```bash
git add -u plugins/dockyard/tests/behavioral/doc-digest/fixtures/test-large-section.md
git commit -m "test(doc-digest): remove large-section fixture — no sub-chunking in v3"
```

---

### Task 5: Mark old design docs as superseded

**Files:**
- Modify: `plugins/dockyard/docs/plans/2026-03-01-doc-digest-design.md` (line 1 area)
- Modify: `plugins/dockyard/docs/plans/2026-03-03-doc-digest-redesign.md` (line 1 area)
- Modify: `plugins/dockyard/docs/plans/2026-03-03-doc-digest-redesign-plan.md` (line 1 area)
- Modify: `plugins/dockyard/docs/plans/2026-03-03-review-fixes-plan.md` (line 1 area)

Add a superseded notice at the top of each file pointing to the v3 design doc.

**Step 1: Add superseded notice to each old doc**

Add this line at the very top of each file:
```
> **SUPERSEDED** — See [2026-03-04-doc-digest-v3-design.md](2026-03-04-doc-digest-v3-design.md)
>
```

**Step 2: Commit**

```bash
git add plugins/dockyard/docs/plans/2026-03-01-doc-digest-design.md \
       plugins/dockyard/docs/plans/2026-03-03-doc-digest-redesign.md \
       plugins/dockyard/docs/plans/2026-03-03-doc-digest-redesign-plan.md \
       plugins/dockyard/docs/plans/2026-03-03-review-fixes-plan.md
git commit -m "docs(doc-digest): mark old design docs as superseded by v3"
```

---

### Task 6: Run full smoke suite and verify clean state

**Files:** None (verification only)

**Step 1: Run full smoke suite**

Run: `bash plugins/dockyard/tests/smoke/run-all.sh`
Expected: All 5 suites pass

**Step 2: Run git status**

Run: `git status`
Expected: Clean working tree, all changes committed

**Step 3: Review git log**

Run: `git log --oneline -10`
Expected: 5 new commits (skill rewrite, smoke test, behavioral tests, fixture deletion, superseded docs) plus the design doc commit
