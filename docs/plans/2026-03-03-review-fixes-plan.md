> **SUPERSEDED** — See [2026-03-04-doc-digest-v3-design.md](2026-03-04-doc-digest-v3-design.md)

# Doc Digest Review Fixes — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 5 code review findings from the doc-digest redesign.

**Architecture:** Small targeted fixes across CLAUDE.md, smoke tests, and behavioral tests.

**Tech Stack:** Markdown, bash scripts.

---

### Task 1: Fix CLAUDE.md stale agent reference

**Files:**
- Modify: `CLAUDE.md:22`

**Step 1: Make the edit**

In `CLAUDE.md`, find line 22 which currently reads:

```
- Agents: `doc-digest`
```

Replace with:

```
- Agents: (none currently)
```

**Step 2: Verify**

Run: `grep 'Agents:' CLAUDE.md`

Expected output should show `(none currently)`, not `doc-digest`.

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "fix: remove stale doc-digest agent reference from CLAUDE.md"
```

---

### Task 2: Add API error guards to behavioral tests 1, 2, 4

**Files:**
- Modify: `plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh`

Tests 3 and 5 already have API error guards. Tests 1, 2, and 4 do not. Add matching guards.

**Step 1: Wrap Test 1 assertions (lines 103-129)**

Currently lines 103-129 have four bare `if echo "$RESULT_T1"` assertion blocks. Wrap all four in an error guard. The result should look like:

```bash
if [[ "$RESULT_T1" == "API_ERROR" || -z "$RESULT_T1" ]]; then
  skip "Test 1 skipped — API call failed"
else
  # Check for section header pattern
  if echo "$RESULT_T1" | grep -qiE 'section [0-9]+ of [0-9]+'; then
    pass "output contains section header (Section N of M)"
  else
    fail "output missing section header pattern"
  fi

  # Check for analysis block
  if echo "$RESULT_T1" | grep -qiE '(\*\*analysis\*\*|## analysis|---.*analysis)'; then
    pass "output contains analysis block"
  else
    fail "output missing analysis block"
  fi

  # Check for summary in analysis
  if echo "$RESULT_T1" | grep -qiE '(\*\*summary\*\*|summary:)'; then
    pass "analysis contains summary"
  else
    fail "analysis missing summary"
  fi

  # Check for feedback prompt
  if echo "$RESULT_T1" | grep -qiE '(feedback|move on|thoughts)\?'; then
    pass "output contains feedback prompt"
  else
    fail "output missing feedback prompt"
  fi
fi
```

**Step 2: Wrap Test 2 assertions (lines 148-169)**

Wrap the `INCONSISTENCY_COUNT` logic and the final check. Everything from `INCONSISTENCY_COUNT=0` through the pass/fail check at line 169 goes inside the guard:

```bash
if [[ "$RESULT_T2" == "API_ERROR" || -z "$RESULT_T2" ]]; then
  skip "Test 2 skipped — API call failed"
else
  # ... all existing INCONSISTENCY_COUNT logic and assertions ...
fi
```

**Step 3: Wrap Test 4 assertions (lines 207-217)**

Wrap both assertion blocks:

```bash
if [[ "$RESULT_T4" == "API_ERROR" || -z "$RESULT_T4" ]]; then
  skip "Test 4 skipped — API call failed"
else
  if echo "$RESULT_T4" | grep -qiE 'section [0-9]+ of [0-9]+'; then
    pass "headingless document produces section headers"
  else
    fail "headingless document missing section headers"
  fi

  if echo "$RESULT_T4" | grep -qiE '(\*\*analysis\*\*|## analysis|---.*analysis)'; then
    pass "headingless document produces analysis"
  else
    fail "headingless document missing analysis"
  fi
fi
```

**Step 4: Verify syntax**

Run: `bash -n plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh`

Expected: no output (clean parse).

**Step 5: Commit**

```bash
git add plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh
git commit -m "fix: add API error guards to behavioral tests 1, 2, 4"
```

---

### Task 3: Make test scripts executable

**Files:**
- Modify permissions: `plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh`
- Modify permissions: `plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh`

**Step 1: Set executable bit**

```bash
chmod +x plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh
chmod +x plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh
```

**Step 2: Verify**

Run: `ls -la plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh | awk '{print $1, $NF}'`

Expected: both show `-rwxr-xr-x` (or at least the `x` bits set).

**Step 3: Commit**

```bash
git add plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh
git commit -m "fix: make test scripts executable to match codebase convention"
```

---

### Task 4: Harden inconsistency detection grep in behavioral test

**Files:**
- Modify: `plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh`

The co-occurrence grep patterns (lines 157-163) require flag word and specific term on the same line within 80 chars. LLM output often splits these across lines. Fix by collapsing output before checking.

**Step 1: Add collapsed variable and update patterns**

In the Test 2 section, find these three blocks (lines 151-163):

```bash
if echo "$RESULT_T2" | grep -qiE '(inconsisten|contradict|conflict|discrepanc|mismatch)'; then
  INCONSISTENCY_COUNT=$((INCONSISTENCY_COUNT + 1))
fi

# Check that at least one specific contradiction is identified by checking for
# co-occurrence of the flag word near a relevant term
if echo "$RESULT_T2" | grep -qiE '(inconsisten|contradict).{0,80}(approv|weekend|saturday|threshold|error.rate|retries|5%|2%)'; then
  INCONSISTENCY_COUNT=$((INCONSISTENCY_COUNT + 1))
fi

if echo "$RESULT_T2" | grep -qiE '(approv|weekend|saturday|threshold|error.rate|5%|2%).{0,80}(inconsisten|contradict)'; then
  INCONSISTENCY_COUNT=$((INCONSISTENCY_COUNT + 1))
fi
```

Replace with:

```bash
if echo "$RESULT_T2" | grep -qiE '(inconsisten|contradict|conflict|discrepanc|mismatch)'; then
  INCONSISTENCY_COUNT=$((INCONSISTENCY_COUNT + 1))
fi

# Check that at least one specific contradiction is identified by checking for
# co-occurrence of the flag word near a relevant term.
# Collapse to single line so cross-line formatting doesn't break matching.
FLAT_T2=$(echo "$RESULT_T2" | tr '\n' ' ')
if echo "$FLAT_T2" | grep -qiE '(inconsisten|contradict).{0,200}(approv|weekend|saturday|threshold|error.rate|retries|5%|2%)'; then
  INCONSISTENCY_COUNT=$((INCONSISTENCY_COUNT + 1))
fi

if echo "$FLAT_T2" | grep -qiE '(approv|weekend|saturday|threshold|error.rate|5%|2%).{0,200}(inconsisten|contradict)'; then
  INCONSISTENCY_COUNT=$((INCONSISTENCY_COUNT + 1))
fi
```

Changes: (1) add `FLAT_T2` collapsed variable, (2) use `FLAT_T2` for co-occurrence checks, (3) widen window from 80 to 200 chars. Keep the first pattern using `RESULT_T2` (it just checks word presence, line breaks don't matter).

**Step 2: Verify syntax**

Run: `bash -n plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh`

Expected: no output (clean parse).

**Step 3: Commit**

```bash
git add plugins/dockyard/tests/behavioral/doc-digest/run-tests.sh
git commit -m "fix: collapse output for co-occurrence grep in inconsistency test"
```

---

### Task 5: Add agent-absence assertion to smoke test

**Files:**
- Modify: `plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh`

**Step 1: Add agent absence check**

In `validate-doc-digest-consistency.sh`, find the end of the "File presence" section (line 29, after the `done` of the file existence loop). Insert after it:

```bash

# Agent file should NOT exist (deleted in redesign)
AGENT="$REPO_ROOT/plugins/dockyard/agents/doc-digest.md"
if [ -f "$AGENT" ]; then
  fail "agent file should not exist (agents/doc-digest.md still present)"
else
  pass "agent file correctly removed"
fi
```

**Step 2: Run the smoke test**

Run: `bash plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh`

Expected: 18/18 passed (was 17/17, now +1 for agent absence).

**Step 3: Run full smoke suite**

Run: `bash plugins/dockyard/tests/smoke/run-all.sh`

Expected: 5/5 suites pass.

**Step 4: Commit**

```bash
git add plugins/dockyard/tests/smoke/validate-doc-digest-consistency.sh
git commit -m "test: add agent-absence assertion to doc-digest smoke test"
```
