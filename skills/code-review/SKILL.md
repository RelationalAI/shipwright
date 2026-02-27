---
name: code-review
description: Use when reviewing code diffs for correctness bugs, convention compliance, and test quality. Applies to PR submissions, pre-commit reviews, CI automation, or any request to review, check, or audit code changes.
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

Three passes, each focused on a different concern. Isolation between passes reduces bias — a correctness bug should not make convention checking harsher for that file. The invoking system decides how to achieve isolation (separate sub-agents, separate API calls, etc.).

Each pass reads its reference file for detailed criteria:

| Pass | Focus | Reference |
|------|-------|-----------|
| 1 | Correctness — bugs, edge cases, regressions, error handling, security | `references/pass-correctness.md` |
| 2 | Conventions — CLAUDE.md compliance, code comment compliance, pattern consistency | `references/pass-conventions.md` |
| 3 | Test Quality — testing the right thing, determinism, speed, behavior over implementation | `references/pass-test-quality.md` |

## Confidence Scoring

After all passes complete, score each finding independently using the rubric in `references/scoring-rubric.md`. The scorer must be independent of the review passes — it evaluates findings on their own merits, not defending or attacking the reviewer's conclusions. Findings below 75 are dropped.

## Output Format

Produce structured JSON output matching the schema in `references/output-schema.md`. Read that file for the exact structure, field rules, and severity definitions.

Key rules:
- If ANY finding has severity `blocker`, recommendation is `NEEDS_CHANGES`. Otherwise `APPROVE`.
- Only findings scoring 75+ survive into the output.
- Convention findings MUST include a `citation` with exact quoted `CLAUDE.md` text.

## False Positive Avoidance

These rules are mandatory. Violating them produces noise that wastes human reviewer time.

1. **Pre-existing issues are excluded.** If the issue exists in code not touched by the diff, do not report it. The diff did not introduce it.

2. **Linter/typechecker/compiler issues are excluded.** CI catches these automatically. Do not duplicate what automated tooling already handles.

3. **General quality issues are NOT flagged** unless `CLAUDE.md` explicitly requires them. Do not flag: missing documentation, insufficient security hardening, low test coverage — unless `CLAUDE.md` says these are required.

4. **Convention findings require exact citations.** You must quote the specific `CLAUDE.md` text being violated. "General best practice" is not a citation.

5. **Hypothetical issues are excluded.** "This could be a problem if..." is not a finding. Only flag issues with a concrete scenario demonstrating real impact.

6. **Do not flag removed code.** If code was deleted, do not flag issues in the deleted code. It no longer exists.
