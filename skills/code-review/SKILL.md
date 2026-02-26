---
name: code-review
description: Structured three-pass code review (correctness, conventions, test quality) with confidence scoring. Use when reviewing diffs for PR submission or CI automation.
---

# Code Review

## Overview

Find real issues that a human reviewer should care about. Do not waste reviewer time with noise. Every finding must survive independent scrutiny.

This skill is model-agnostic — the invoking system controls model selection (Opus local, Sonnet CI, Haiku scoring).

## Inputs

The invoking system provides:

- **Diff** — the code changes to review (committed changes vs base branch locally, PR diff in CI)
- **Project context** — `CLAUDE.md` content, repository structure, existing conventions
- **Rationale context** (optional) — plan file path, session summary, commit messages explaining intent

Read all provided context before starting review passes.

## Review Passes

Run all three passes. They are independent and can execute in parallel.

### Pass 1: Correctness

Examine the diff for defects that affect runtime behavior:

- **Bugs** — logic errors, off-by-one, null/undefined access, type mismatches, incorrect conditions
- **Edge cases** — boundary conditions, empty inputs, concurrent access, error propagation
- **Regressions** — does this change break existing behavior? Check callers of modified functions.
- **Error handling** — are errors caught, propagated, and reported correctly? Are resources cleaned up?
- **Security** — injection, authentication bypass, data exposure, unsafe deserialization (only if clearly introduced by this diff)

For each potential issue:

1. Read the surrounding code (not just the diff lines) to understand the full context
2. Trace the data flow to verify the issue is real
3. Check if tests cover the problematic path
4. Only report if you can explain a concrete scenario where the bug manifests

### Pass 2: Conventions

Check the diff against `CLAUDE.md` and established codebase patterns:

- **`CLAUDE.md` compliance** — for every convention finding, you MUST cite the exact text from `CLAUDE.md` that the code violates. No over-generalization. If you cannot point to a specific rule, it is not a convention violation.
- **Code comment compliance** — if existing code has comments like `// Note: must call X before Y` or `// WARNING: not thread-safe`, verify the diff respects these constraints.
- **Pattern consistency** — if the codebase uses a specific pattern for similar operations (error handling, logging, API responses), the diff should follow the same pattern.

**Important:** Do NOT flag general "best practices" that are not documented in `CLAUDE.md` or established by codebase convention. The goal is consistency with THIS project's standards, not universal standards.

### Pass 3: Test Quality

Evaluate whether tests accompanying the diff are adequate:

- **Testing the right thing** — do tests exercise the behavior introduced or changed by the diff? A test that passes before AND after the change tests nothing relevant.
- **Determinism** — are tests deterministic? Flag: time-dependent assertions, random data without seeds, filesystem ordering assumptions, network calls without mocks.
- **Speed** — are tests unnecessarily slow? Flag: sleep/delay in tests, spinning up real servers when mocks suffice, testing large datasets when small ones prove the same thing.
- **Behavior over implementation** — do tests assert on observable behavior (output, side effects, state changes) or on implementation details (internal method calls, private state, execution order)?
- **Coverage of the changes** — are the meaningful code paths introduced by the diff exercised by tests? Are edge cases from Pass 1 covered?

**Important:** Only evaluate tests that are part of the diff or directly related to changed code. Do not flag pre-existing test quality issues.

## Confidence Scoring

After all three passes complete, collect all findings. Each finding is scored independently by a separate evaluation agent (the invoking system spawns this — use Haiku for cost/speed).

**Scoring prompt per finding:** Provide the finding (file, line range, description, suggested fix), the relevant diff context, and the relevant surrounding code. Ask the scorer to evaluate on this rubric:

| Score | Meaning |
|-------|---------|
| 0 | False positive — does not hold up to scrutiny, or pre-existing issue |
| 25 | Might be real — could not verify with available context |
| 50 | Verified real — but nitpick, rare in practice, or cosmetic |
| 75 | Verified — very likely real, important, should be addressed |
| 100 | Definitely real — evidence directly confirms, happens frequently |

**Threshold:** Drop all findings with confidence below 80. Only findings scoring 80+ are included in the output.

**Why independent scoring:** This decouples detection from evaluation. The review passes are optimized to cast a wide net (high recall). The scorer is optimized to filter noise (high precision). Combining both in one pass leads to anchoring — the reviewer justifies its own findings rather than evaluating them objectively.

## Output Format

Produce structured output consumed by the invoking system.

### Recommendation

`APPROVE` or `NEEDS_CHANGES`

**Blocker logic:** If ANY finding has severity `blocker`, the recommendation is `NEEDS_CHANGES`. Otherwise `APPROVE`.

### Findings

List of findings that survived confidence scoring (80+), each with:

- **File** — exact file path
- **Line range** — start and end lines in the diff
- **Severity:**
  - `blocker` — must fix before merge; correctness defect, security issue, or critical convention violation
  - `warning` — should fix; important but not blocking
  - `nit` — suggestion; style, minor improvement, optional
- **Category:** `correctness`, `convention`, or `test-quality`
- **Confidence:** score from confidence scoring (80–100)
- **Description** — what the issue is and why it matters
- **Suggested fix** — concrete suggestion for how to resolve it
- **Citation** (convention findings only) — exact quoted text from `CLAUDE.md`

### Summary

A few sentences explaining the overall assessment. Be specific:
- What the diff does well
- What the key concerns are (if any)
- What the human reviewer should focus on

## False Positive Avoidance

These rules are mandatory. Violating them produces noise that wastes human reviewer time.

1. **Pre-existing issues are excluded.** If the issue exists in code not touched by the diff, do not report it. The diff did not introduce it.

2. **Linter/typechecker/compiler issues are excluded.** CI catches these automatically. Do not duplicate what automated tooling already handles.

3. **General quality issues are NOT flagged** unless `CLAUDE.md` explicitly requires them. Do not flag: missing documentation, insufficient security hardening, low test coverage — unless `CLAUDE.md` says these are required.

4. **Convention findings require exact citations.** You must quote the specific `CLAUDE.md` text being violated. "General best practice" is not a citation.

5. **Hypothetical issues are excluded.** "This could be a problem if..." is not a finding. Only flag issues with a concrete scenario demonstrating real impact.

6. **Do not flag removed code.** If code was deleted, do not flag issues in the deleted code. It no longer exists.
