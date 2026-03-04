---
name: code-review
description: Use when reviewing code diffs for correctness bugs, convention compliance, and test quality. Applies to PR submissions, pre-commit reviews, CI automation, or any request to review, check, or audit code changes.
allowed-tools: Read, Glob, Grep, Bash(git diff *), Bash(git log *), Bash(git rev-parse *), Bash(git merge-base *), Agent, LSP
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
- **Determinism** — flag: time-dependent assertions, random data without seeds, filesystem ordering assumptions, network calls without mocks.
- **Speed** — flag: sleep/delay in tests, spinning up real servers when mocks suffice, testing large datasets when small ones prove the same thing.
- **Behavior over implementation** — do tests assert on observable behavior (output, side effects, state changes) or on implementation details (internal method calls, private state, execution order)?
- **Coverage of the changes** — are the meaningful code paths introduced by the diff exercised by tests?

Only evaluate tests that are part of the diff or directly related to changed code. Do not flag pre-existing test quality issues.

## Orchestration

Spawn three `dockyard:code-reviewer` sub-agents in parallel — one per pass. All communication is inline — sub-agents return their results as JSON in their response messages.

Each sub-agent receives:
- The git command to run the diff (e.g., `git diff "$BASE_BRANCH"...HEAD`) — sub-agents run this themselves to keep the full diff out of the coordinator's context
- `CLAUDE.md` content
- Rationale context (if available)
- The full text of the relevant pass criteria section — copy the complete section content into the sub-agent prompt:
  - Pass 1: copy the entire "Pass 1: Correctness" section above (from "Examine the diff for defects..." through the verification process)
  - Pass 2: copy the entire "Pass 2: Conventions" section above (from "Check the diff against..." through the "not a finding" rule)
  - Pass 3: copy the entire "Pass 3: Test Quality" section above (from "Evaluate whether tests..." through the pre-existing issues rule)
- The full JSON schema from the "Output Format" section below — copy the complete JSON block and all field rules into each sub-agent prompt
- Instruction to return findings as a JSON object

```
Pass 1 (dockyard:code-reviewer):
  Include: Full text of "Pass 1: Correctness" section
  Include: Full JSON schema and field rules from "Output Format"
  Return: { "pass": "correctness", "findings": [...] }

Pass 2 (dockyard:code-reviewer):
  Include: Full text of "Pass 2: Conventions" section
  Include: Full JSON schema and field rules from "Output Format"
  Return: { "pass": "conventions", "findings": [...] }

Pass 3 (dockyard:code-reviewer):
  Include: Full text of "Pass 3: Test Quality" section
  Include: Full JSON schema and field rules from "Output Format"
  Return: { "pass": "test-quality", "findings": [...] }
```

Each sub-agent returns a JSON object containing its `pass` name and the `findings` array. The coordinator extracts the findings from each sub-agent's response.

## Confidence Scoring

After all passes complete, spawn one Haiku Task sub-agent to score findings independently. The scorer receives all three findings arrays and the relevant diff context.

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
