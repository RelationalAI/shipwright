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
| 3 | Test Quality — testing the right thing, determinism, speed, behavior over implementation, mocking discipline | `references/pass-test-quality.md` |

For execution details (sub-agent spawning, model selection), see `references/orchestration.md`.

## Confidence Scoring

After all passes complete, score each finding independently using the rubric in `references/scoring-rubric.md`. The scorer must be independent of the review passes — it evaluates findings on their own merits, not defending or attacking the reviewer's conclusions. Findings below 75 are dropped.

## Output Format

Produce structured JSON output matching the schema in `references/output-schema.md`. Read that file for the exact structure, field rules, and severity definitions.

Key rules:
- If ANY finding has severity `blocker`, recommendation is `NEEDS_CHANGES`. Otherwise `APPROVE`.
- Only findings scoring 75+ survive into the output.
- Convention findings need a `citation` with exact quoted `CLAUDE.md` text — without one, the finding is opinion rather than a verifiable violation.

## False Positive Avoidance

Every false positive wastes a human reviewer's time and erodes trust in the review system. These rules exist to keep the signal-to-noise ratio high:

1. **Pre-existing issues are out of scope.** If the issue exists in code not touched by the diff, the diff didn't introduce it. Flagging it creates noise without actionable value.

2. **Linter/typechecker/compiler issues are out of scope.** CI catches these automatically. Duplicating automated tooling adds noise and teaches reviewers to ignore findings.

3. **General quality issues are out of scope** unless `CLAUDE.md` explicitly requires them. Missing documentation, insufficient security hardening, low test coverage — unless the project has explicitly decided these matter (by putting them in `CLAUDE.md`), flagging them is opinion, not review.

4. **Convention findings need evidence.** Quote the specific `CLAUDE.md` text or codebase pattern being violated. "General best practice" is not evidence — it's the reviewer substituting their preferences for the project's standards.

5. **Hypothetical issues are out of scope.** "This could be a problem if..." is speculation. Only report issues where you can describe a concrete scenario with real impact.

6. **Removed code is out of scope.** Deleted code no longer exists. Flagging issues in it is noise.

7. **Generated files are out of scope.** Auto-generated code, compiled bundles, snapshot test outputs, and other generated artifacts that happen to be committed are not hand-written code. Findings in them are not actionable — review the source that generates them instead.
