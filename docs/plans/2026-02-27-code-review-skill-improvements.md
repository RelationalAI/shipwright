# Code Review Skill Improvements

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve the code-review skill for correctness, testability, context efficiency, and best-practice compliance.

**Architecture:** The code-review skill (`skills/code-review/SKILL.md`) defines review criteria. The review-and-submit skill (`skills/review-and-submit/SKILL.md`) is the primary consumer that orchestrates execution. Changes restructure the code-review skill to use progressive disclosure (SKILL.md + reference files), add a parseable output schema, fix spec bugs, and move execution-specific orchestration into review-and-submit where it belongs.

**Tech Stack:** Markdown (skill files), Bash (smoke tests), JSON (output schema, eval fixtures)

**Context:**
- `skills/code-review/SKILL.md` — current: 135 lines, single file, mixes criteria with execution
- `skills/review-and-submit/SKILL.md` — current: 213 lines, references code-review skill
- `tests/smoke/validate-structure.sh` — checks file existence
- `tests/smoke/validate-skills.sh` — checks skill conventions
- Design doc: `docs/plans/2026-02-26-code-review-design.md`

**Dependency order:** Tasks 1-3 are independent. Task 4 depends on 2. Task 5 depends on 4. Task 6 depends on 4. Task 7 depends on 3.

**Note:** Original Task 7 (file-based sub-agent communication) was merged into Task 5 (orchestration protocol). Old Task 8 is now Task 7.

---

## Phase 1: Quick Fixes (independent, no structural changes)

### Task 1: Fix confidence threshold inconsistency

The skill says "75" in one place and "80+" in another. This is a spec bug.

**Files:**
- Modify: `skills/code-review/SKILL.md:83,99,108`

**Step 1: Fix the three inconsistent lines**

Line 83 says threshold is 75. Lines 99 and 108 say 80+. The rubric defines 75 as "Verified — very likely real, important, should be addressed" — these should be included. Standardize on 75.

In `skills/code-review/SKILL.md`, change line 99 from:
```
List of findings that survived confidence scoring (80+), each with:
```
to:
```
List of findings that survived confidence scoring (75+), each with:
```

Change line 108 from:
```
- **Confidence:** score from confidence scoring (80–100)
```
to:
```
- **Confidence:** score from confidence scoring (75–100)
```

Line 83 is already correct: "Drop all findings scoring below 75."

**Step 2: Run smoke tests**

```bash
bash tests/smoke/run-all.sh
```

Expected: all pass (no structural changes, just content edits).

**Step 3: Commit**

```bash
git add skills/code-review/SKILL.md
git commit -m "fix: standardize confidence threshold to 75 in code-review skill"
```

---

### Task 2: Rewrite skill description

The current description summarizes the workflow ("Structured three-pass code review...with confidence scoring"), which violates both Anthropic's skill-creator guidance and the superpowers writing-skills CSO rules. Descriptions should state triggering conditions, not workflow.

**Files:**
- Modify: `skills/code-review/SKILL.md:3`

**Step 1: Replace the description**

Change line 3 from:
```yaml
description: Structured three-pass code review (correctness, conventions, test quality) with confidence scoring. Use when reviewing diffs for PR submission or CI automation.
```
to:
```yaml
description: Use when reviewing code diffs for correctness bugs, convention compliance, and test quality. Applies to PR submissions, pre-commit reviews, CI automation, or any request to review, check, or audit code changes.
```

**Step 2: Run smoke tests**

```bash
bash tests/smoke/run-all.sh
```

Expected: all pass.

**Step 3: Commit**

```bash
git add skills/code-review/SKILL.md
git commit -m "fix: rewrite code-review description to focus on triggers not workflow"
```

---

### Task 3: Define JSON output schema

The skill describes output format in prose but doesn't define a parseable schema. Adding one enables testing, CI integration, and mechanical threshold enforcement.

**Files:**
- Create: `skills/code-review/references/output-schema.md`
- Modify: `skills/code-review/SKILL.md:87-118` (replace prose output section with schema reference)

**Step 1: Create the output schema reference file**

Create `skills/code-review/references/output-schema.md`:

```markdown
# Code Review Output Schema

The review MUST produce output matching this JSON structure. The invoking system parses this output.

## Schema

```json
{
  "recommendation": "APPROVE | NEEDS_CHANGES",
  "findings": [
    {
      "file": "exact/file/path.ts",
      "line_start": 42,
      "line_end": 45,
      "severity": "blocker | warning | nit",
      "category": "correctness | convention | test-quality",
      "confidence": 75,
      "description": "What the issue is and why it matters",
      "suggested_fix": "Concrete suggestion for how to resolve it",
      "citation": "Exact quoted text from CLAUDE.md (convention findings only, null otherwise)"
    }
  ],
  "summary": "Overall assessment: what the diff does well, key concerns, where the human reviewer should focus"
}
```

## Field Rules

- **recommendation**: `NEEDS_CHANGES` if any finding has `severity: "blocker"`. Otherwise `APPROVE`.
- **findings**: Only findings scoring 75+ in confidence scoring. Empty array if none survive.
- **severity**:
  - `blocker` — must fix before merge (correctness defect, security issue, critical convention violation)
  - `warning` — should fix, important but not blocking
  - `nit` — suggestion, style, minor improvement, optional
- **category**: Which review pass produced the finding.
- **confidence**: Integer 75-100 from the scoring rubric.
- **citation**: Required for `convention` category. Must be exact quoted text from `CLAUDE.md`. Set to `null` for other categories.
- **summary**: 2-4 sentences. Be specific about what the diff does well and where the human reviewer should focus.
```

**Step 2: Update SKILL.md to reference the schema**

Replace the entire "## Output Format" section (lines 87-118) in `skills/code-review/SKILL.md` with:

```markdown
## Output Format

Produce structured JSON output matching the schema in `references/output-schema.md`. Read that file for the exact structure, field rules, and severity definitions.

Key rules:
- If ANY finding has severity `blocker`, recommendation is `NEEDS_CHANGES`. Otherwise `APPROVE`.
- Only findings scoring 75+ survive into the output.
- Convention findings MUST include a `citation` with exact quoted `CLAUDE.md` text.
```

**Step 3: Update smoke tests for new file**

In `tests/smoke/validate-structure.sh`, after the code-review check (line 29), add:

```bash
check "skills/code-review/references/output-schema.md" "$REPO_ROOT/skills/code-review/references/output-schema.md"
```

Update the comment on line 25 to reflect the new count.

**Step 4: Run smoke tests**

```bash
bash tests/smoke/run-all.sh
```

Expected: all pass including the new structure check.

**Step 5: Commit**

```bash
git add skills/code-review/references/output-schema.md skills/code-review/SKILL.md tests/smoke/validate-structure.sh
git commit -m "feat: add JSON output schema for code-review skill"
```

---

## Phase 2: Structural Refactor (progressive disclosure)

### Task 4: Split pass criteria into reference files

The three review passes (correctness, conventions, test quality) contain detailed criteria that only the sub-agent running that specific pass needs. Moving them to reference files enables progressive disclosure — each sub-agent reads only its own pass criteria, and the main SKILL.md stays lean.

**Files:**
- Create: `skills/code-review/references/pass-correctness.md`
- Create: `skills/code-review/references/pass-conventions.md`
- Create: `skills/code-review/references/pass-test-quality.md`
- Create: `skills/code-review/references/scoring-rubric.md`
- Modify: `skills/code-review/SKILL.md:24-85` (replace detailed passes with summaries + references)
- Modify: `tests/smoke/validate-structure.sh` (add checks for new files)

**Step 1: Create pass-correctness.md**

Create `skills/code-review/references/pass-correctness.md`:

```markdown
# Pass 1: Correctness

Examine the diff for defects that affect runtime behavior.

## What to Look For

- **Bugs** — logic errors, off-by-one, null/undefined access, type mismatches, incorrect conditions
- **Edge cases** — boundary conditions, empty inputs, concurrent access, error propagation
- **Regressions** — does this change break existing behavior? Check callers of modified functions.
- **Error handling** — are errors caught, propagated, and reported correctly? Are resources cleaned up?
- **Security** — injection, authentication bypass, data exposure, unsafe deserialization (only if clearly introduced by this diff)

## Verification Process

For each potential issue:

1. Read the surrounding code (not just the diff lines) to understand the full context
2. Trace the data flow to verify the issue is real
3. Check if tests cover the problematic path
4. Only report if you can explain a concrete scenario where the bug manifests

If you cannot construct a concrete scenario, the issue is hypothetical — do not report it.
```

**Step 2: Create pass-conventions.md**

Create `skills/code-review/references/pass-conventions.md`:

```markdown
# Pass 2: Conventions

Check the diff against `CLAUDE.md` and established codebase patterns.

## What to Look For

- **`CLAUDE.md` compliance** — for every convention finding, you MUST cite the exact text from `CLAUDE.md` that the code violates. No over-generalization. If you cannot point to a specific rule, it is not a convention violation.
- **Code comment compliance** — if existing code has comments like `// Note: must call X before Y` or `// WARNING: not thread-safe`, verify the diff respects these constraints.
- **Pattern consistency** — if the codebase uses a specific pattern for similar operations (error handling, logging, API responses), the diff should follow the same pattern.

## Important Scope Limitation

Do NOT flag general "best practices" that are not documented in `CLAUDE.md` or established by codebase convention. The goal is consistency with THIS project's standards, not universal standards. If you cannot cite a specific `CLAUDE.md` rule or existing codebase pattern, it is not a finding.
```

**Step 3: Create pass-test-quality.md**

Create `skills/code-review/references/pass-test-quality.md`:

```markdown
# Pass 3: Test Quality

Evaluate whether tests accompanying the diff are adequate.

## What to Look For

- **Testing the right thing** — do tests exercise the behavior introduced or changed by the diff? A test that passes before AND after the change tests nothing relevant.
- **Determinism** — are tests deterministic? Flag: time-dependent assertions, random data without seeds, filesystem ordering assumptions, network calls without mocks.
- **Speed** — are tests unnecessarily slow? Flag: sleep/delay in tests, spinning up real servers when mocks suffice, testing large datasets when small ones prove the same thing.
- **Behavior over implementation** — do tests assert on observable behavior (output, side effects, state changes) or on implementation details (internal method calls, private state, execution order)?
- **Coverage of the changes** — are the meaningful code paths introduced by the diff exercised by tests? Are edge cases from the correctness pass covered?

## Important Scope Limitation

Only evaluate tests that are part of the diff or directly related to changed code. Do not flag pre-existing test quality issues.
```

**Step 4: Create scoring-rubric.md**

Create `skills/code-review/references/scoring-rubric.md`:

```markdown
# Confidence Scoring

After all review passes complete, each finding is scored independently by a separate scorer.

## Why Independent Scoring

Detection and evaluation are separate concerns. The review passes cast a wide net (high recall). The scorer filters noise (high precision). Combining both in one step leads to anchoring — the reviewer justifies its own findings rather than evaluating them objectively.

## Rubric

| Score | Meaning | Example |
|-------|---------|---------|
| 0 | False positive — does not hold up to scrutiny, or pre-existing issue | "Bug" that is actually handled by a try/catch 3 lines below |
| 25 | Might be real — could not verify with available context | Potential race condition, but unclear if this code path is concurrent |
| 50 | Verified real — but nitpick, rare in practice, or cosmetic | Unused import, inconsistent spacing that doesn't violate CLAUDE.md |
| 75 | Verified — very likely real, important, should be addressed | Missing null check on user input that will throw in production |
| 100 | Definitely real — evidence directly confirms, happens frequently | SQL injection via string concatenation with request parameter |

## Threshold

Drop all findings scoring below 75. Only findings scoring 75+ are included in the output.

## Scoring Process

For each finding, the scorer receives:
- The finding (file, line range, description, suggested fix)
- The relevant diff context
- The surrounding source code

The scorer evaluates each finding on its own merits. One finding's score must not influence another's.
```

**Step 5: Replace detailed pass sections in SKILL.md with summaries**

Replace lines 24-85 (from `## Review Passes` through end of `## Confidence Scoring`) in `skills/code-review/SKILL.md` with:

```markdown
## Review Passes

Run three passes, each focused on a different concern. Isolation between passes prevents findings in one area from biasing scrutiny in another — a correctness bug should not make convention checking harsher for that file.

Each pass reads its reference file for detailed criteria:

| Pass | Focus | Reference |
|------|-------|-----------|
| 1 | Correctness — bugs, edge cases, regressions, error handling, security | `references/pass-correctness.md` |
| 2 | Conventions — CLAUDE.md compliance, code comment compliance, pattern consistency | `references/pass-conventions.md` |
| 3 | Test Quality — testing the right thing, determinism, speed, behavior over implementation | `references/pass-test-quality.md` |

## Confidence Scoring

After all passes complete, score each finding independently using the rubric in `references/scoring-rubric.md`. Findings below 75 are dropped. This decouples detection (high recall) from evaluation (high precision).
```

**Step 6: Update smoke tests**

In `tests/smoke/validate-structure.sh`, after the code-review SKILL.md check, add checks for each reference file:

```bash
check "skills/code-review/references/pass-correctness.md"  "$REPO_ROOT/skills/code-review/references/pass-correctness.md"
check "skills/code-review/references/pass-conventions.md"   "$REPO_ROOT/skills/code-review/references/pass-conventions.md"
check "skills/code-review/references/pass-test-quality.md"  "$REPO_ROOT/skills/code-review/references/pass-test-quality.md"
check "skills/code-review/references/scoring-rubric.md"     "$REPO_ROOT/skills/code-review/references/scoring-rubric.md"
```

(If Task 3's output-schema.md check is already there, add these after it.)

**Step 7: Run smoke tests**

```bash
bash tests/smoke/run-all.sh
```

Expected: all pass.

**Step 8: Commit**

```bash
git add skills/code-review/references/ skills/code-review/SKILL.md tests/smoke/validate-structure.sh
git commit -m "refactor: split code-review pass criteria into reference files for progressive disclosure"
```

---

## Phase 3: Orchestration & Tone

### Task 5: Add orchestration protocol to code-review skill

The code-review skill defines WHAT to review but doesn't specify HOW to execute the passes. The orchestration protocol (sub-agent spawning, file-based communication, scoring pipeline) belongs in the code-review skill as a Level 3 reference file — it's detailed execution instructions that the invoking system loads when actually running the review.

File-based sub-agent communication conserves context: sub-agents write findings to temp files instead of returning them in-context, preventing raw findings from 4 agent invocations accumulating in the main context.

**Files:**
- Create: `skills/code-review/references/orchestration.md`
- Modify: `skills/code-review/SKILL.md` (add reference to orchestration protocol)

**Step 1: Create orchestration.md**

Create `skills/code-review/references/orchestration.md`:

```markdown
# Orchestration Protocol

How to execute the three review passes with minimal context consumption.

## Context Conservation

Sub-agents write results to temp files instead of returning them in-context. This prevents raw findings from 4 agent invocations accumulating in the main context. Only the final filtered result enters context.

## Step 1: Create temp directory

```bash
REVIEW_DIR=$(mktemp -d)
```

## Step 2: Run review passes

Spawn three Task sub-agents in parallel. Each sub-agent receives:
- The diff to review
- `CLAUDE.md` content
- Rationale context (if available)
- Its pass-specific reference file
- The output schema reference file
- Instruction to write findings JSON to a specific file path

```
Pass 1 (correctness):
  Read: references/pass-correctness.md
  Read: references/output-schema.md
  Write findings to: $REVIEW_DIR/pass-1-findings.json

Pass 2 (conventions):
  Read: references/pass-conventions.md
  Read: references/output-schema.md
  Write findings to: $REVIEW_DIR/pass-2-findings.json

Pass 3 (test quality):
  Read: references/pass-test-quality.md
  Read: references/output-schema.md
  Write findings to: $REVIEW_DIR/pass-3-findings.json
```

**Model:** Opus for all review passes (higher quality, fewer false positives).

Each sub-agent writes a JSON file containing only the `findings` array from the output schema. The sub-agent's return message to the main context should be a one-line summary: "Found N potential issues in [category]. Findings written to [path]."

## Step 3: Score findings

Spawn one Haiku Task sub-agent that:
1. Reads all three findings files from `$REVIEW_DIR/`
2. Reads the scoring rubric from `references/scoring-rubric.md`
3. Reads the relevant diff context
4. Scores each finding independently
5. Drops findings below 75
6. Assembles the final JSON output (recommendation + filtered findings + summary)
7. Writes the result to `$REVIEW_DIR/review-result.json`

The scorer's return message: "Scored N findings, M survived (threshold 75). Result written to [path]."

## Step 4: Read results

Read `$REVIEW_DIR/review-result.json` into the main context. This is the only review data that enters the main context — the individual pass findings stay on disk.

## Step 5: Cleanup

```bash
rm -rf "$REVIEW_DIR"
```
```

**Step 2: Add orchestration reference to SKILL.md**

In `skills/code-review/SKILL.md`, add a line after the Review Passes section referencing the orchestration protocol. After the pass table, before Confidence Scoring, add:

```markdown
For execution details (sub-agent spawning, file-based communication, model selection), see `references/orchestration.md`.
```

**Step 3: Run smoke tests**

```bash
bash tests/smoke/run-all.sh
```

Expected: all pass (smoke tests auto-discover reference files).

**Step 4: Commit**

```bash
git add skills/code-review/references/orchestration.md skills/code-review/SKILL.md
git commit -m "feat: add orchestration protocol with file-based sub-agent communication"
```

---

### Task 6: Soften tone per skill-creator guidance

Anthropic's skill-creator explicitly warns: "If you find yourself writing ALWAYS or NEVER in all caps, or using super rigid structures, that's a yellow flag — try to reframe and explain the reasoning." The code-review skill and its reference files should explain WHY rules exist rather than commanding compliance.

**Files:**
- Modify: `skills/code-review/SKILL.md` (soften "mandatory" language)
- Modify: `skills/code-review/references/pass-conventions.md` (soften MUST language)
- Review all reference files created in Task 4 for tone

**Step 1: Soften the false positive avoidance section**

In `skills/code-review/SKILL.md`, the false positive section currently starts with "These rules are mandatory. Violating them produces noise that wastes human reviewer time."

Rewrite it as:

```markdown
## False Positive Avoidance

Every false positive wastes a human reviewer's time and erodes trust in the review system. These rules exist to keep the signal-to-noise ratio high:

1. **Pre-existing issues are out of scope.** If the issue exists in code not touched by the diff, the diff didn't introduce it. Flagging it creates noise without actionable value.

2. **Linter/typechecker/compiler issues are out of scope.** CI catches these automatically. Duplicating automated tooling adds noise and teaches reviewers to ignore findings.

3. **General quality issues are out of scope** unless `CLAUDE.md` explicitly requires them. Missing documentation, insufficient security hardening, low test coverage — unless the project has explicitly decided these matter (by putting them in `CLAUDE.md`), flagging them is opinion, not review.

4. **Convention findings need evidence.** Quote the specific `CLAUDE.md` text or codebase pattern being violated. "General best practice" is not evidence — it's the reviewer substituting their preferences for the project's standards.

5. **Hypothetical issues are out of scope.** "This could be a problem if..." is speculation. Only report issues where you can describe a concrete scenario with real impact.

6. **Removed code is out of scope.** Deleted code no longer exists. Flagging issues in it is noise.
```

**Step 2: Review reference files for tone**

Check each reference file created in Task 4. Replace instances of "you MUST" with explanations of why. For example, in `pass-conventions.md`, if it says:

```
you MUST cite the exact text from `CLAUDE.md` that the code violates
```

Reframe as:

```
cite the exact text from `CLAUDE.md` that the code violates — without a specific citation, the finding is opinion rather than a verifiable convention violation
```

**Step 3: Run smoke tests**

```bash
bash tests/smoke/run-all.sh
```

Expected: all pass.

**Step 4: Commit**

```bash
git add skills/code-review/SKILL.md skills/code-review/references/
git commit -m "refactor: soften code-review tone — explain why, not just mandate"
```

---

## Phase 4: Testability

### Task 7: Add eval fixtures for code-review skill

Create test diffs and expected findings so the skill can be tested using Anthropic's skill-creator eval framework. These are golden test cases — known inputs with known expected outputs.

**Files:**
- Create: `skills/code-review/evals/evals.json`
- Create: `skills/code-review/evals/files/null-access-bug.patch`
- Create: `skills/code-review/evals/files/null-access-bug-claude.md`
- Create: `skills/code-review/evals/files/clean-diff.patch`
- Create: `skills/code-review/evals/files/clean-diff-claude.md`
- Create: `skills/code-review/evals/files/convention-violation.patch`
- Create: `skills/code-review/evals/files/convention-violation-claude.md`

**Step 1: Create the evals.json**

Create `skills/code-review/evals/evals.json`:

```json
{
  "skill_name": "code-review",
  "evals": [
    {
      "id": 1,
      "prompt": "Review the following diff. The project CLAUDE.md and diff are provided as files.",
      "expected_output": "Should find the null access bug, recommend NEEDS_CHANGES with a blocker finding",
      "files": [
        "evals/files/null-access-bug.patch",
        "evals/files/null-access-bug-claude.md"
      ],
      "expectations": [
        "Output is valid JSON with recommendation, findings, and summary fields",
        "Recommendation is NEEDS_CHANGES",
        "At least one finding has severity blocker",
        "A finding identifies the null/undefined access on user.name without a null check",
        "The finding has confidence score of 75 or higher",
        "No findings reference code outside the diff (pre-existing issues excluded)",
        "Summary is present and non-empty"
      ]
    },
    {
      "id": 2,
      "prompt": "Review the following diff. The project CLAUDE.md and diff are provided as files.",
      "expected_output": "Should approve with no findings — the diff is clean",
      "files": [
        "evals/files/clean-diff.patch",
        "evals/files/clean-diff-claude.md"
      ],
      "expectations": [
        "Output is valid JSON with recommendation, findings, and summary fields",
        "Recommendation is APPROVE",
        "Findings array is empty or contains only nit-level items",
        "No false positives — no blocker or warning findings",
        "Summary acknowledges the change is clean"
      ]
    },
    {
      "id": 3,
      "prompt": "Review the following diff. The project CLAUDE.md and diff are provided as files. Pay attention to convention compliance.",
      "expected_output": "Should find the CLAUDE.md convention violation and cite the exact rule",
      "files": [
        "evals/files/convention-violation.patch",
        "evals/files/convention-violation-claude.md"
      ],
      "expectations": [
        "Output is valid JSON with recommendation, findings, and summary fields",
        "At least one finding has category convention",
        "The convention finding includes a citation field with exact quoted text from the CLAUDE.md",
        "The citation matches actual text in the provided CLAUDE.md file",
        "No convention findings lack citations (every convention finding must have one)"
      ]
    }
  ]
}
```

**Step 2: Create the null-access-bug test diff**

Create `skills/code-review/evals/files/null-access-bug.patch`:

```diff
diff --git a/src/user-service.js b/src/user-service.js
index 1234567..abcdefg 100644
--- a/src/user-service.js
+++ b/src/user-service.js
@@ -10,6 +10,15 @@ class UserService {
     return this.db.findById(id);
   }

+  async getUserDisplayName(id) {
+    const user = await this.db.findById(id);
+    // BUG: user could be null if id doesn't exist
+    const displayName = user.name.split(' ')[0];
+    return displayName;
+  }
+
+  async getUserEmail(id) {
+    const user = await this.db.findById(id);
+    if (!user) return null;
+    return user.email;
+  }
+
   async updateUser(id, data) {
     return this.db.update(id, data);
   }
```

**Step 3: Create the matching CLAUDE.md for null-access-bug**

Create `skills/code-review/evals/files/null-access-bug-claude.md`:

```markdown
# Project Standards

## Error Handling
- All database lookups must check for null/undefined before accessing properties.
- Use early returns for null checks.

## Naming
- Use camelCase for functions and variables.
```

**Step 4: Create the clean diff**

Create `skills/code-review/evals/files/clean-diff.patch`:

```diff
diff --git a/src/utils.js b/src/utils.js
index 1234567..abcdefg 100644
--- a/src/utils.js
+++ b/src/utils.js
@@ -5,3 +5,10 @@ function formatDate(date) {
   return date.toISOString().split('T')[0];
 }

+function formatCurrency(amount, currency = 'USD') {
+  return new Intl.NumberFormat('en-US', {
+    style: 'currency',
+    currency,
+  }).format(amount);
+}
+
 module.exports = { formatDate, formatCurrency };
```

**Step 5: Create the matching CLAUDE.md for clean diff**

Create `skills/code-review/evals/files/clean-diff-claude.md`:

```markdown
# Project Standards

## Code Style
- Use camelCase for functions and variables.
- Use const/let, never var.
- Use default parameters where appropriate.
```

**Step 6: Create the convention violation diff**

Create `skills/code-review/evals/files/convention-violation.patch`:

```diff
diff --git a/src/api.js b/src/api.js
index 1234567..abcdefg 100644
--- a/src/api.js
+++ b/src/api.js
@@ -1,5 +1,12 @@
 const express = require('express');
 const router = express.Router();

+router.get('/users/:id', async (req, res) => {
+  var user = await db.findById(req.params.id);
+  if (!user) {
+    res.status(404).send('Not found');
+    return;
+  }
+  res.json({ user_name: user.name, user_email: user.email });
+});
+
 module.exports = router;
```

**Step 7: Create the matching CLAUDE.md for convention violation**

Create `skills/code-review/evals/files/convention-violation-claude.md`:

```markdown
# Project Standards

## Code Style
- Use camelCase for functions and variables.
- Use const/let, never var.
- API responses must use camelCase keys (e.g., userName, not user_name).

## Error Handling
- All database lookups must check for null/undefined before accessing properties.
```

**Step 8: Run smoke tests**

```bash
bash tests/smoke/run-all.sh
```

Expected: all pass (eval files don't affect structure checks).

**Step 9: Commit**

```bash
git add skills/code-review/evals/
git commit -m "feat: add eval fixtures for code-review skill testing"
```

---

## Verification

After all tasks are complete, run the full smoke test suite:

```bash
bash tests/smoke/run-all.sh
```

Then optionally run the evals using Anthropic's skill-creator:

```
/skill-creator:skill-creator eval skills/code-review
```

This will execute each eval case and grade expectations, giving a measurable baseline for the improved skill.
