---
description: Run a structured 3-pass code review on committed changes
argument-hint: "[base branch, default main] [--json for machine-readable output]"
allowed-tools: Read, Glob, Grep, Bash(git diff *), Bash(git log *), Bash(git rev-parse *), Bash(git merge-base *), Bash(gh *), Agent, LSP
---

# Code Review

You are running the Dockyard Code Review command. This is a standalone review — no fix loop, no PR creation. Use `/dockyard:review-and-submit` if you want the full flow.

Find real issues that a human reviewer should care about. Do not waste reviewer time with noise. Every finding must survive independent scrutiny.

## Setup

### Parse arguments

```bash
# ARGUMENTS may contain: [base-branch] [--json]
# Examples: "main", "--json", "develop --json"
```

Extract the base branch (default `main`) and check for `--json` flag. If `--json` is present, output raw JSON at the end. Otherwise, present a human-readable table.

### Determine the base branch

```bash
BASE_BRANCH="${ARGUMENTS:-main}"  # strip --json if present
git diff --stat "$BASE_BRANCH"...HEAD
```

If the diff stat is empty, stop: "No committed changes found relative to $BASE_BRANCH."

Do NOT read the full diff here — that happens inside the sub-agents.

### Gather context (lightweight)

- Read `CLAUDE.md` from the project root (if it exists)
- Collect commit messages: `git log "$BASE_BRANCH"..HEAD --format="%s%n%b"`

## Reviewer Definitions

Each reviewer runs in its own sub-agent. Adding or removing a reviewer means adding or removing a section here.

### Reviewer 1: Correctness

**Pass name:** `correctness`

Examine the diff for defects that affect runtime behavior.

**What to look for:**

- **Bugs** — logic errors, off-by-one, null/undefined access, type mismatches, incorrect conditions
- **Edge cases** — boundary conditions, empty inputs, concurrent access, error propagation
- **Regressions** — does this change break existing behavior? Check callers of modified functions.
- **Error handling** — are errors caught, propagated, and reported correctly? Are resources cleaned up?
- **Security** — injection, authentication bypass, data exposure, unsafe deserialization (only if clearly introduced by this diff)

**Verification process:** For each potential issue, read the surrounding code (not just the diff lines), trace the data flow to verify the issue is real, check if tests cover the problematic path, and only report if you can explain a concrete scenario where the bug manifests. If you cannot construct a concrete scenario, the issue is hypothetical — do not report it.

### Reviewer 2: Conventions

**Pass name:** `conventions`

Check the diff against `CLAUDE.md` and established codebase patterns.

**What to look for:**

- **`CLAUDE.md` compliance** — for every convention finding, cite the exact text from `CLAUDE.md` that the code violates — without a specific citation, the finding is opinion rather than a verifiable convention violation.
- **Code comment compliance** — if existing code has comments like `// Note: must call X before Y` or `// WARNING: not thread-safe`, verify the diff respects these constraints.
- **Pattern consistency** — if the codebase uses a specific pattern for similar operations (error handling, logging, API responses), the diff should follow the same pattern.

Do NOT flag general "best practices" that are not documented in `CLAUDE.md` or established by codebase convention. If you cannot cite a specific `CLAUDE.md` rule or existing codebase pattern, it is not a finding.

### Reviewer 3: Test Quality

**Pass name:** `test-quality`

Evaluate whether tests accompanying the diff are adequate.

**What to look for:**

- **Testing the right thing** — do tests exercise the behavior introduced or changed by the diff? A test that passes before AND after the change tests nothing relevant.
- **Determinism** — flag: time-dependent assertions, random data without seeds, filesystem ordering assumptions, uncontrolled external dependencies. Prefer contract tests, deterministic test servers, or in-process fakes over mocks for controlling external behavior.
- **Speed** — flag: sleep/delay in tests, unnecessarily heavy test infrastructure, testing large datasets when small ones prove the same thing. Prefer lightweight real implementations (in-memory databases, local test servers) over mocks for managing test speed.
- **Behavior over implementation** — do tests assert on observable behavior (output, side effects, state changes) or on implementation details (internal method calls, private state, execution order)?
- **Mocking discipline** — never mock what you can use for real. Flag tests that mock internal modules, classes, or functions when the real implementation could be used. Acceptable mock targets: external services behind a network boundary, system clocks, hardware interfaces. If a dependency is hard to use in tests without mocking, that's a design smell in the dependency, not a reason to mock.
- **Coverage of the changes** — are the meaningful code paths introduced by the diff exercised by tests?

Only evaluate tests that are part of the diff or directly related to changed code. Do not flag pre-existing test quality issues.

## Sub-agent Output Contract

Each sub-agent prompt must include this output contract verbatim. This is a strict machine contract — the coordinator consumes output programmatically.

Return exactly this JSON structure and nothing else (no markdown fences, no explanatory text):

```json
{
  "pass": "<pass-name>",
  "findings": [
    {
      "file": "exact/file/path.ext",
      "line_start": 42,
      "line_end": 45,
      "severity": "blocker",
      "category": "<pass-name>",
      "confidence": 92,
      "description": "What the issue is and why it matters",
      "suggested_fix": "Concrete suggestion for how to resolve it",
      "citation": null
    }
  ]
}
```

**Mandatory field rules:**

- **pass**: Use the pass name from your assignment: `correctness`, `conventions`, or `test-quality`.
- **severity**: Only these three values — `blocker` (must fix before merge), `warning` (should fix, not blocking), `nit` (suggestion, optional). Never use "high", "medium", "low", "critical", or any other scale.
- **category**: Must match the pass name exactly.
- **confidence**: Integer 0-100. Score each finding using the anchored scale below. **Only include findings with confidence >= 80 in the output.** Any finding below 80 must be excluded entirely.
- **citation**: Required for `conventions` pass — exact quoted text from `CLAUDE.md`. Set to `null` for other passes.
- **findings**: Empty array `[]` if no findings reach confidence >= 80. Do not fabricate findings.
- Do NOT include `title`, `recommendation`, or `summary` fields. The coordinator adds those.

**Confidence scale** (use this anchored rubric — not gut feel):

| Score | Meaning | Example |
|-------|---------|---------|
| 0 | False positive or pre-existing issue | Issue exists in untouched code, not introduced by this diff |
| 25 | Might be real, couldn't verify | Suspicious pattern but can't trace a concrete failure path |
| 50 | Real but low-impact nitpick | Slightly misleading variable name, minor style inconsistency |
| 75 | Verified, likely real, important | Bug exists but only triggers in uncommon edge case |
| 100 | Confirmed, definitely real, will happen in practice | Nil dereference on a common code path with no guard |

## Orchestration

Follow these steps in order. You orchestrate but do not perform reviews directly.

### Step 1: Spawn three reviewer sub-agents in parallel

Using the Agent tool, spawn exactly three sub-agents **in a single response** (all three Agent calls in the same message). Each pass must run in its own independent sub-agent to prevent bias.

Each sub-agent prompt must contain exactly four things — nothing more:

1. **Identity** — "You are a read-only code reviewer. You analyze diffs and return structured JSON. You do not modify any files. Only use Bash for read-only git commands."
2. **Which pass** this agent is performing and its pass name (`correctness`, `conventions`, or `test-quality`)
3. **The git diff command** to run (e.g., `git diff main...HEAD`)
4. **The pass criteria** — copy the relevant Reviewer section from above verbatim into the prompt
5. **The output contract** — copy the entire "Sub-agent Output Contract" section above verbatim into the prompt

Example sub-agent prompt structure (for Reviewer 1):

```
You are a read-only code reviewer. You analyze diffs and return structured JSON. You do not modify any files. Only use Bash for read-only git commands.

Your pass: correctness

Run this command to get the diff: git diff main...HEAD

Read CLAUDE.md at the project root for conventions.

Review criteria (follow these exactly):

[paste the entire "Reviewer 1: Correctness" criteria here verbatim]

Output contract (follow exactly):

[paste the entire "Sub-agent Output Contract" section here verbatim]
```

Do the same for Reviewer 2 (conventions) and Reviewer 3 (test-quality), pasting the corresponding section.

### Step 2: Aggregate results

Wait for all three sub-agents to complete. Each returns a JSON object with `pass` and `findings` (with `confidence` scores, pre-filtered to >= 80). Extract the findings arrays and concatenate them into a single array.

If a sub-agent returns malformed JSON, discard its results and note the failure in the summary.

### Step 3: Produce final output

From the aggregated findings:

1. Set `recommendation`: `NEEDS_CHANGES` if any finding has `severity: "blocker"`. Otherwise `APPROVE`.
2. Write a `summary`: 2-4 sentences covering what the diff does well, key concerns, and where the human reviewer should focus.
3. Do not re-score or re-filter findings — the agents already applied the confidence threshold.

#### If `--json` flag is set (CI mode)

Return the raw JSON and nothing else:

```json
{
  "recommendation": "APPROVE | NEEDS_CHANGES",
  "findings": [
    {
      "file": "exact/file/path.ts",
      "line_start": 42,
      "line_end": 45,
      "severity": "blocker | warning | nit",
      "category": "correctness | conventions | test-quality",
      "confidence": 80,
      "description": "What the issue is and why it matters",
      "suggested_fix": "Concrete suggestion for how to resolve it",
      "citation": "Exact quoted text from CLAUDE.md (convention findings only, null otherwise)"
    }
  ],
  "summary": "Overall assessment"
}
```

#### Otherwise (interactive mode, default)

Present a human-readable review:

1. **Recommendation** — show `APPROVE` or `NEEDS_CHANGES` prominently
2. **Summary** — the 2-4 sentence summary
3. **Findings table** — if any findings exist, present them as a markdown table:

| # | Severity | File | Lines | Category | Description |
|---|----------|------|-------|----------|-------------|
| 1 | blocker | src/auth.ts | 42-45 | correctness | Missing null check on user lookup |

4. **Details** — below the table, for each finding, show the full description, suggested fix, and citation (if any)
5. **Next steps** — if the developer wants fixes and a PR, suggest `/dockyard:review-and-submit`

Do not auto-fix anything — this is review only.

## False Positive Avoidance

Every false positive wastes a human reviewer's time and erodes trust in the review system:

1. **Pre-existing issues are out of scope.** If the issue exists in code not touched by the diff, the diff didn't introduce it.
2. **Linter/typechecker/compiler issues are out of scope.** CI catches these automatically.
3. **General quality issues are out of scope** unless `CLAUDE.md` explicitly requires them.
4. **Convention findings need evidence.** Quote the specific `CLAUDE.md` text or codebase pattern being violated.
5. **Hypothetical issues are out of scope.** Only report issues where you can describe a concrete scenario with real impact.
6. **Removed code is out of scope.** Deleted code no longer exists.
7. **Generated files are out of scope.** Review the source that generates them instead.
