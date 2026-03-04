---
name: code-review
description: Use when reviewing code diffs for correctness bugs, convention compliance, and test quality. Applies to PR submissions, pre-commit reviews, CI automation, or any request to review, check, or audit code changes.
---

# Code Review

## Overview

Find real issues that a human reviewer should care about. Do not waste reviewer time with noise. Every finding must survive independent scrutiny.

## Inputs

The invoking system provides:

- **Diff** — the code changes to review (committed changes vs base branch locally, PR diff in CI)
- **Project context** — `CLAUDE.md` content, repository structure, existing conventions
- **Rationale context** (optional) — plan file path, session summary, commit messages explaining intent

Read all provided context before starting review passes.

## Review Passes

Exactly three passes, each focused on a different concern. Isolation between passes reduces bias — a correctness bug should not make convention checking harsher for that file. Each pass runs as a separate sub-agent. Do not reorganize by file or change area — the pass structure is by concern type, not by code area.

### Pass 1: Correctness

Examine the diff for defects that affect runtime behavior.

**What to look for:**

- **Bugs** — logic errors, off-by-one, null/undefined access, type mismatches, incorrect conditions
- **Edge cases** — boundary conditions, empty inputs, concurrent access, error propagation
- **Regressions** — does this change break existing behavior? Check callers of modified functions.
- **Error handling** — are errors caught, propagated, and reported correctly? Are resources cleaned up?
- **Security** — injection, authentication bypass, data exposure, unsafe deserialization (only if clearly introduced by this diff)

**Verification process:** For each potential issue, read the surrounding code (not just the diff lines), trace the data flow to verify the issue is real, check if tests cover the problematic path, and only report if you can explain a concrete scenario where the bug manifests. If you cannot construct a concrete scenario, the issue is hypothetical — do not report it.

### Pass 2: Conventions

Check the diff against `CLAUDE.md` and established codebase patterns.

**What to look for:**

- **`CLAUDE.md` compliance** — for every convention finding, cite the exact text from `CLAUDE.md` that the code violates — without a specific citation, the finding is opinion rather than a verifiable convention violation.
- **Code comment compliance** — if existing code has comments like `// Note: must call X before Y` or `// WARNING: not thread-safe`, verify the diff respects these constraints.
- **Pattern consistency** — if the codebase uses a specific pattern for similar operations (error handling, logging, API responses), the diff should follow the same pattern.

Do NOT flag general "best practices" that are not documented in `CLAUDE.md` or established by codebase convention. If you cannot cite a specific `CLAUDE.md` rule or existing codebase pattern, it is not a finding.

### Pass 3: Test Quality

Evaluate whether tests accompanying the diff are adequate.

**What to look for:**

- **Testing the right thing** — do tests exercise the behavior introduced or changed by the diff? A test that passes before AND after the change tests nothing relevant.
- **Determinism** — flag: time-dependent assertions, random data without seeds, filesystem ordering assumptions, uncontrolled external dependencies. Prefer contract tests, deterministic test servers, or in-process fakes over mocks for controlling external behavior.
- **Speed** — flag: sleep/delay in tests, unnecessarily heavy test infrastructure, testing large datasets when small ones prove the same thing. Prefer lightweight real implementations (in-memory databases, local test servers) over mocks for managing test speed.
- **Behavior over implementation** — do tests assert on observable behavior (output, side effects, state changes) or on implementation details (internal method calls, private state, execution order)?
- **Mocking discipline** — never mock what you can use for real. Flag tests that mock internal modules, classes, or functions when the real implementation could be used. Acceptable mock targets: external services behind a network boundary, system clocks, hardware interfaces. If a dependency is hard to use in tests without mocking, that's a design smell in the dependency, not a reason to mock.
- **Coverage of the changes** — are the meaningful code paths introduced by the diff exercised by tests?

Only evaluate tests that are part of the diff or directly related to changed code. Do not flag pre-existing test quality issues.

## Orchestration

Spawn three Task sub-agents in parallel — one per pass. Do NOT instruct sub-agents to write files. All communication is inline — sub-agents return their results as JSON in their response messages.

Each sub-agent receives:
- The git command to run the diff (e.g., `git diff "$BASE_BRANCH"...HEAD`) — sub-agents run this themselves to keep the full diff out of the coordinator's context
- `CLAUDE.md` content
- Rationale context (if available)
- The pass criteria from the relevant section above (copy the criteria into the sub-agent prompt)
- The return schema (from the "Review Agent Return Schema" section below)
- Instruction to return findings as a JSON object

```
Pass 1 sub-agent:
  Include: Pass 1 criteria (from "Pass 1: Correctness" above)
  Include: Return schema (from "Review Agent Return Schema" below)
  Return: { "pass": "correctness", "findings": [...] }

Pass 2 sub-agent:
  Include: Pass 2 criteria (from "Pass 2: Conventions" above)
  Include: Return schema (from "Review Agent Return Schema" below)
  Return: { "pass": "conventions", "findings": [...] }

Pass 3 sub-agent:
  Include: Pass 3 criteria (from "Pass 3: Test Quality" above)
  Include: Return schema (from "Review Agent Return Schema" below)
  Return: { "pass": "test-quality", "findings": [...] }
```

**Model:** Opus for all review passes.

Each sub-agent returns a JSON object containing its `pass` name and the `findings` array. The coordinator extracts the findings from each sub-agent's response.

## Review Agent Return Schema

Each review sub-agent must return its findings using exactly this schema:

```json
{
  "pass": "correctness",
  "findings": [
    {
      "file": "exact/file/path.ts",
      "line_start": 42,
      "line_end": 45,
      "severity": "blocker | warning | nit",
      "category": "correctness | convention | test-quality",
      "description": "What the issue is and why it matters",
      "suggested_fix": "Concrete suggestion for how to resolve it",
      "citation": "Exact quoted text from CLAUDE.md (convention findings only, null otherwise)"
    }
  ]
}
```

Do NOT include `confidence`, `recommendation`, or `summary` — these are added by the scorer.

## Confidence Scoring

After all passes complete, spawn one Haiku Task sub-agent to score findings independently. The scorer receives raw findings without confidence scores. Review agents must not pre-score findings — the scorer is the sole source of confidence values. The scorer receives all three findings arrays and the relevant diff context.

Scores are integers 0–100. 0 means false positive, 100 means certainty. The scorer evaluates each finding on its own merits — one finding's score must not influence another's. Drop all findings scoring below **80**.

The scorer returns the final JSON output (recommendation + filtered findings + summary).

## Output Format

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
      "confidence": 80,
      "description": "What the issue is and why it matters",
      "suggested_fix": "Concrete suggestion for how to resolve it",
      "citation": "Exact quoted text from CLAUDE.md (convention findings only, null otherwise)"
    }
  ],
  "summary": "Overall assessment: what the diff does well, key concerns, where the human reviewer should focus"
}
```

**Field rules:**

- **recommendation**: `NEEDS_CHANGES` if any finding has `severity: "blocker"`. Otherwise `APPROVE`.
- **findings**: Only findings surviving the confidence threshold. Empty array if none survive.
- **severity**: `blocker` (must fix before merge), `warning` (should fix, not blocking), `nit` (suggestion, optional)
- **category**: Which review pass produced the finding.
- **confidence**: Integer 80+.
- **citation**: Required for `convention` category — exact quoted text from `CLAUDE.md`. `null` for other categories.
- **summary**: 2-4 sentences. Be specific about what the diff does well and where the human reviewer should focus.

## False Positive Avoidance

Every false positive wastes a human reviewer's time and erodes trust in the review system. These rules exist to keep the signal-to-noise ratio high:

1. **Pre-existing issues are out of scope.** If the issue exists in code not touched by the diff, the diff didn't introduce it. Flagging it creates noise without actionable value.

2. **Linter/typechecker/compiler issues are out of scope.** CI catches these automatically. Duplicating automated tooling adds noise and teaches reviewers to ignore findings.

3. **General quality issues are out of scope** unless `CLAUDE.md` explicitly requires them. Missing documentation, insufficient security hardening, low test coverage — unless the project has explicitly decided these matter (by putting them in `CLAUDE.md`), flagging them is opinion, not review.

4. **Convention findings need evidence.** Quote the specific `CLAUDE.md` text or codebase pattern being violated. "General best practice" is not evidence — it's the reviewer substituting their preferences for the project's standards.

5. **Hypothetical issues are out of scope.** "This could be a problem if..." is speculation. Only report issues where you can describe a concrete scenario with real impact.

6. **Removed code is out of scope.** Deleted code no longer exists. Flagging issues in it is noise.

7. **Generated files are out of scope.** Auto-generated code, compiled bundles, snapshot test outputs, and other generated artifacts that happen to be committed are not hand-written code. Findings in them are not actionable — review the source that generates them instead.
