# Code Review System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the two-layer AI-assisted code review system (local submit + CI automation) defined in `docs/plans/2026-02-26-code-review-design.md`.

**Architecture:** Three components — a code-review skill (core review logic used by both flows), a submit command (local developer flow: review → fix → PR), and a CI GitHub Action (automated PR review with inline comments). The skill is model-agnostic; the invoking system controls model selection (Opus local, Sonnet CI, Haiku scoring).

**Tech Stack:** Markdown prompt engineering (skills, commands), GitHub Actions YAML (CI workflow), bash (smoke tests)

---

### Task 1: Add code-review skill to smoke tests (RED)

**Files:**
- Modify: `tests/smoke/validate-structure.sh:27-33`
- Modify: `tests/smoke/validate-skills.sh:11-18`

**Step 1: Add code-review to validate-structure.sh**

In `tests/smoke/validate-structure.sh`, add after line 33 (the last skill check):

```bash
check "skills/code-review/SKILL.md"             "$REPO_ROOT/skills/code-review/SKILL.md"
```

**Step 2: Add code-review to validate-skills.sh**

In `tests/smoke/validate-skills.sh`, add `code-review` to the end of the SKILLS array:

```bash
SKILLS=(
  tdd
  verification-before-completion
  systematic-debugging
  anti-rationalization
  decision-categorization
  brownfield-analysis
  code-review
)
```

**Step 3: Make attribution check optional for original skills**

In `tests/smoke/validate-skills.sh`, add an `ORIGINAL_SKILLS` array and helper function after the `SKILLS` array:

```bash
# Skills without external attribution (original Shipwright work)
ORIGINAL_SKILLS=(code-review)

is_original() {
  local skill="$1"
  for s in "${ORIGINAL_SKILLS[@]}"; do
    if [ "$s" = "$skill" ]; then return 0; fi
  done
  return 1
}
```

Then replace the existing attribution check block:

```bash
  # Contains attribution header
  if grep -q '> \*\*Attribution:\*\*' "$filepath"; then
    pass "$skill has attribution header"
  else
    fail "$skill missing attribution header (expected '> **Attribution:**')"
  fi
```

With:

```bash
  # Contains attribution header (skip for original skills)
  if is_original "$skill"; then
    pass "$skill is original (no attribution required)"
  elif grep -q '> \*\*Attribution:\*\*' "$filepath"; then
    pass "$skill has attribution header"
  else
    fail "$skill missing attribution header (expected '> **Attribution:**')"
  fi
```

**Step 4: Run smoke tests to verify they fail**

Run: `bash tests/smoke/run-all.sh`
Expected: FAIL — `skills/code-review/SKILL.md` does not exist yet

**Step 5: Commit**

```bash
git add tests/smoke/validate-structure.sh tests/smoke/validate-skills.sh
git commit -m "test: add code-review skill to smoke validation (RED)"
```

---

### Task 2: Create code-review skill (GREEN)

**Files:**
- Create: `skills/code-review/SKILL.md`

**Step 1: Create skill directory**

```bash
mkdir -p skills/code-review
```

**Step 2: Write the code-review skill**

Create `skills/code-review/SKILL.md` with the following content:

````markdown
---
name: code-review
description: Structured three-pass code review (correctness, conventions, test quality) with confidence scoring. Use when reviewing diffs for PR submission or CI automation.
---

# Code Review

## Overview

Find real issues that a human reviewer should care about. Do not waste reviewer time with noise. Every finding must survive independent scrutiny.

The skill is model-agnostic — the invoking system controls model selection (Opus local, Sonnet CI, Haiku scoring).

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
````

**Step 3: Run smoke tests to verify they pass**

Run: `bash tests/smoke/run-all.sh`
Expected: PASS — all checks including new code-review skill

**Step 4: Commit**

```bash
git add skills/code-review/SKILL.md
git commit -m "feat: add code-review skill — three-pass review with confidence scoring"
```

---

### Task 3: Add submit command to smoke tests (RED)

**Files:**
- Modify: `tests/smoke/validate-structure.sh:47-51`
- Modify: `tests/smoke/validate-commands.sh:11-17`

**Step 1: Add shipwright-submit to validate-structure.sh**

In `tests/smoke/validate-structure.sh`, add after line 51 (the last command check):

```bash
check "commands/shipwright-submit.md"    "$REPO_ROOT/commands/shipwright-submit.md"
```

**Step 2: Add shipwright-submit to validate-commands.sh**

In `tests/smoke/validate-commands.sh`, add `shipwright-submit.md` to the end of the COMMANDS array:

```bash
COMMANDS=(
  shipwright.md
  shipwright-codebase-analyze.md
  shipwright-doc-digest.md
  shipwright-debug.md
  shipwright-report.md
  shipwright-submit.md
)
```

**Step 3: Run smoke tests to verify they fail**

Run: `bash tests/smoke/run-all.sh`
Expected: FAIL — `commands/shipwright-submit.md` does not exist yet

**Step 4: Commit**

```bash
git add tests/smoke/validate-structure.sh tests/smoke/validate-commands.sh
git commit -m "test: add shipwright-submit command to smoke validation (RED)"
```

---

### Task 4: Create submit command (GREEN)

**Files:**
- Create: `commands/shipwright-submit.md`

**Step 1: Write the submit command**

Create `commands/shipwright-submit.md` with the following content:

````markdown
---
description: Review code, auto-fix blockers, generate PR description, and create a draft PR
argument-hint: "[optional: base branch, default main]"
---

# Shipwright Submit

You are running the Shipwright Submit command. This is the local developer flow from "done coding" to "draft PR ready."

**Review always runs.** There is no flag to skip it. After seeing results, the developer can choose to proceed past blockers, but the review itself is mandatory.

## Prerequisites

Before starting, verify:

1. You are on a feature branch (not `main` or `master`). If on main/master, stop: "You are on the main branch. Create a feature branch first."
2. There are committed changes on this branch relative to the base branch. If no changes, stop: "No changes to submit. Commit your changes first."
3. `gh` CLI is available and authenticated. Run `gh auth status` to check. If not authenticated, stop: "GitHub CLI is not authenticated. Run `gh auth login` first."

If any prerequisite fails, inform the developer with the specific message and stop.

## Step 1: Gather Context

### Determine the diff

```bash
# Base branch: use $ARGUMENTS if provided, otherwise "main"
BASE_BRANCH="${ARGUMENTS:-main}"

# Get the diff
git diff "$BASE_BRANCH"...HEAD
```

### Collect rationale context

Search for context that explains the intent behind the changes. This is optional — it helps generate better PR descriptions but is not required for review.

- **Plan files** — scan `docs/plans/` for recently modified files related to this work
- **Session context** — read `.workflow/CONTEXT.md` if it exists
- **Commit messages** — `git log "$BASE_BRANCH"..HEAD --format="%s%n%b"` for the progression of changes

## Step 2: Run Code Review

Invoke the `shipwright-beta:code-review` skill and follow its process exactly.

**Model selection for this step:**
- Review passes: use Opus (higher quality, fewer false positives — developer is paying and waiting)
- Confidence scoring: spawn a Haiku sub-agent per finding for independent evaluation

**Provide to the skill:**
- The diff from Step 1
- `CLAUDE.md` content (read from project root)
- Rationale context from Step 1 (if available)

**Present findings to the developer:**

```
## Code Review Results: [APPROVE | NEEDS_CHANGES]

### Blockers (N)
- [file:line] description (confidence: XX)
  Suggested fix: ...

### Warnings (N)
- [file:line] description (confidence: XX)
  Suggested fix: ...

### Nits (N)
- [file:line] description (confidence: XX)
  Suggested fix: ...

### Summary
[summary text from the skill output]
```

## Step 3: Fix Loop

**Only runs if findings were reported.**

If the review is APPROVE with no findings, skip to Step 4.

### Prompt developer for selection

Present all findings with numbered selection:

```
Which findings should I auto-fix? (comma-separated numbers, "all", or "none")

  [1] blocker  src/auth.ts:42    Missing null check on user lookup
  [2] blocker  src/auth.ts:87    Token expiry not validated
  [3] warning  src/api.ts:15     Error response missing status code
  [4] nit      src/api.ts:30     Inconsistent naming: userID vs userId
```

Wait for the developer to choose. Do not auto-fix anything without explicit selection.

### Fix selected findings

For each selected finding, spawn a sub-agent to fix it:

- **Input to sub-agent:** the finding (file, line range, description, suggested fix), the full file content, and the project context (`CLAUDE.md`)
- **Sub-agent task:** apply the fix, then run the project's test command to verify the fix does not break anything
- **Why sub-agents:** keeps the main context clean — each fix is isolated

Sub-agents can run in parallel if the findings are in different files.

### Re-review

After all fix sub-agents complete:

1. Get the updated diff: `git diff "$BASE_BRANCH"...HEAD`
2. Re-run the code-review skill on the updated diff
3. Present updated findings to the developer

**One cycle only.** Do not loop.

### Developer decision

After re-review, present the updated state:

```
Fixes applied. Updated review:

[updated findings, if any...]

Options:
1. Fix more manually and re-run /shipwright:submit
2. Proceed to PR creation (remaining findings will be noted in the PR description)
```

Wait for the developer to choose. Do not auto-proceed.

## Step 4: Generate PR Description

Synthesize a PR description from all available sources:

- **Diff analysis** — what concretely changed, notable decisions visible in the code
- **Commit messages** — the progression of changes on this branch
- **Plan files** — requirements, design intent (from Step 1)
- **Review results** — what the local review caught and fixed, remaining warnings/nits

**Use this template:**

```markdown
## What
<concise summary of what changed — proportional to diff size>

## Why
<rationale — the problem being solved, decisions that led here>

## How to review
<suggested focus areas, ordered by importance>

## Pre-submit review
<what the local review caught and fixed, remaining warnings/nits>
```

**Rules:**
- The description must be proportional to the change size — a 10-line diff gets a brief description
- Never longer than the diff itself
- Focus on WHY over WHAT (the diff shows what changed)
- Be specific about review focus areas — tell the reviewer exactly where to look

## Step 5: Create Draft PR

```bash
# Push the branch (set upstream if needed)
git push -u origin HEAD

# Create draft PR
gh pr create --draft \
  --title "<concise title>" \
  --body "<generated description from Step 4>"
```

Present the draft PR URL to the developer. Remind them:
- Review the description on GitHub and edit if needed
- Mark as "Ready for Review" when satisfied — this triggers the CI review bot

## Rules

1. **Review always runs.** No skip flag. Developer can proceed past blockers after seeing them.
2. **Developer chooses what to fix.** Never auto-fix without explicit selection.
3. **One fix cycle.** Fix selected findings once, re-review, then hand back to developer. No infinite loops.
4. **Sub-agents for fixes.** Keep main context clean.
5. **Draft PR default.** Author reviews on GitHub before marking ready.
6. **Description proportional to diff.** Small change = brief description.
7. **Never force-push.** Always `git push`, never `git push --force`.
````

**Step 2: Run smoke tests to verify they pass**

Run: `bash tests/smoke/run-all.sh`
Expected: PASS — all checks including new submit command

**Step 3: Commit**

```bash
git add commands/shipwright-submit.md
git commit -m "feat: add shipwright-submit command — review, fix, PR flow"
```

---

### Task 5: Create CI GitHub Action workflow

**Files:**
- Create: `.github/workflows/code-review.yml`

**Dependencies:** This workflow requires:
- A Claude API key stored as a GitHub Actions secret (e.g., `CLAUDE_API_KEY`)
- Claude Code available in the CI environment (installed as a step or pre-installed on runner)
- `gh` CLI available (standard on GitHub-hosted runners)

**Step 1: Create the workflow directory**

```bash
mkdir -p .github/workflows
```

**Step 2: Write the workflow**

Create `.github/workflows/code-review.yml` with the following content:

```yaml
name: Code Review

on:
  pull_request:
    types: [ready_for_review]
  push:
    branches-ignore:
      - main
      - master

permissions:
  contents: read
  pull-requests: write

jobs:
  review:
    name: AI Code Review
    runs-on: ubuntu-latest
    # Skip if: draft PR, bot author, or no open PR for this branch
    if: >-
      github.event_name == 'pull_request' && !github.event.pull_request.draft ||
      github.event_name == 'push'
    timeout-minutes: 15

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Check for open non-draft PR
        id: pr-check
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          if [ "${{ github.event_name }}" = "push" ]; then
            # For push events, find an open non-draft PR for this branch
            BRANCH="${GITHUB_REF_NAME}"
            PR_JSON=$(gh pr list --head "$BRANCH" --state open --json number,isDraft,author --limit 1)
            PR_NUMBER=$(echo "$PR_JSON" | jq -r '.[0].number // empty')
            IS_DRAFT=$(echo "$PR_JSON" | jq -r '.[0].isDraft // empty')
            AUTHOR_TYPE=$(echo "$PR_JSON" | jq -r '.[0].author.type // empty')

            if [ -z "$PR_NUMBER" ]; then
              echo "No open PR for branch $BRANCH. Skipping."
              echo "skip=true" >> "$GITHUB_OUTPUT"
              exit 0
            fi

            if [ "$IS_DRAFT" = "true" ]; then
              echo "PR #$PR_NUMBER is a draft. Skipping."
              echo "skip=true" >> "$GITHUB_OUTPUT"
              exit 0
            fi

            if [ "$AUTHOR_TYPE" = "Bot" ]; then
              echo "PR #$PR_NUMBER is from a bot. Skipping."
              echo "skip=true" >> "$GITHUB_OUTPUT"
              exit 0
            fi

            echo "pr_number=$PR_NUMBER" >> "$GITHUB_OUTPUT"
            echo "skip=false" >> "$GITHUB_OUTPUT"
          else
            # For ready_for_review events, use the PR from the event
            echo "pr_number=${{ github.event.pull_request.number }}" >> "$GITHUB_OUTPUT"
            echo "skip=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Get PR diff
        if: steps.pr-check.outputs.skip != 'true'
        id: diff
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          PR_NUMBER="${{ steps.pr-check.outputs.pr_number }}"
          gh pr diff "$PR_NUMBER" > /tmp/pr-diff.txt

          # Check diff size — bail if too large
          DIFF_LINES=$(wc -l < /tmp/pr-diff.txt)
          if [ "$DIFF_LINES" -gt 5000 ]; then
            echo "too_large=true" >> "$GITHUB_OUTPUT"
            gh pr comment "$PR_NUMBER" --body "$(cat <<'COMMENT'
          ## Code Review: Skipped

          This PR is too large for automated review (>5000 diff lines). Please break it into smaller PRs or request manual review.
          COMMENT
          )"
            exit 0
          fi

          echo "too_large=false" >> "$GITHUB_OUTPUT"

      - name: Install Claude Code
        if: steps.pr-check.outputs.skip != 'true' && steps.diff.outputs.too_large != 'true'
        run: npm install -g @anthropic-ai/claude-code

      - name: Run code review
        if: steps.pr-check.outputs.skip != 'true' && steps.diff.outputs.too_large != 'true'
        id: review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
        run: |
          # Read CLAUDE.md for project context (if exists)
          CLAUDE_MD=""
          if [ -f "CLAUDE.md" ]; then
            CLAUDE_MD=$(cat CLAUDE.md)
          fi

          PR_DIFF=$(cat /tmp/pr-diff.txt)

          # Run Claude Code with the code-review skill
          # The skill is loaded as context, the diff is the input
          # Model: Sonnet for CI (cost/speed across the org)
          claude --model sonnet --output-format json --max-turns 10 \
            --allowedTools "Read,Glob,Grep" \
            --print \
            "You are a code reviewer. Read and follow the skill defined in skills/code-review/SKILL.md exactly.

          Project context (CLAUDE.md):
          $CLAUDE_MD

          Review this diff:
          $PR_DIFF

          Output your findings as JSON with this structure:
          {
            \"recommendation\": \"APPROVE\" or \"NEEDS_CHANGES\",
            \"findings\": [
              {
                \"file\": \"path/to/file\",
                \"line_start\": 10,
                \"line_end\": 15,
                \"severity\": \"blocker|warning|nit\",
                \"category\": \"correctness|convention|test-quality\",
                \"confidence\": 85,
                \"description\": \"...\",
                \"suggested_fix\": \"...\",
                \"citation\": \"...\" // only for convention findings
              }
            ],
            \"summary\": \"...\"
          }" > /tmp/review-output.json

      - name: Post review comments
        if: steps.pr-check.outputs.skip != 'true' && steps.diff.outputs.too_large != 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          PR_NUMBER="${{ steps.pr-check.outputs.pr_number }}"
          REVIEW_OUTPUT="/tmp/review-output.json"

          # Parse the review output
          RECOMMENDATION=$(jq -r '.recommendation' "$REVIEW_OUTPUT")
          SUMMARY=$(jq -r '.summary' "$REVIEW_OUTPUT")
          FINDING_COUNT=$(jq '.findings | length' "$REVIEW_OUTPUT")
          BLOCKER_COUNT=$(jq '[.findings[] | select(.severity == "blocker")] | length' "$REVIEW_OUTPUT")
          WARNING_COUNT=$(jq '[.findings[] | select(.severity == "warning")] | length' "$REVIEW_OUTPUT")
          NIT_COUNT=$(jq '[.findings[] | select(.severity == "nit")] | length' "$REVIEW_OUTPUT")

          # Post inline comments for each finding
          jq -c '.findings[]' "$REVIEW_OUTPUT" | while read -r finding; do
            FILE=$(echo "$finding" | jq -r '.file')
            LINE=$(echo "$finding" | jq -r '.line_start')
            SEVERITY=$(echo "$finding" | jq -r '.severity')
            CATEGORY=$(echo "$finding" | jq -r '.category')
            CONFIDENCE=$(echo "$finding" | jq -r '.confidence')
            DESCRIPTION=$(echo "$finding" | jq -r '.description')
            SUGGESTED_FIX=$(echo "$finding" | jq -r '.suggested_fix')
            CITATION=$(echo "$finding" | jq -r '.citation // empty')

            SEVERITY_ICON="💡"
            if [ "$SEVERITY" = "blocker" ]; then SEVERITY_ICON="🚫"; fi
            if [ "$SEVERITY" = "warning" ]; then SEVERITY_ICON="⚠️"; fi

            COMMENT_BODY="$SEVERITY_ICON **$SEVERITY** ($CATEGORY, confidence: $CONFIDENCE)

          $DESCRIPTION

          **Suggested fix:** $SUGGESTED_FIX"

            if [ -n "$CITATION" ]; then
              COMMENT_BODY="$COMMENT_BODY

          **CLAUDE.md:** > $CITATION"
            fi

            # Post as PR review comment on specific line
            gh api \
              "repos/${{ github.repository }}/pulls/$PR_NUMBER/comments" \
              -f body="$COMMENT_BODY" \
              -f path="$FILE" \
              -F line="$LINE" \
              -f commit_id="${{ github.sha }}" || true
          done

          # Post summary comment
          gh pr comment "$PR_NUMBER" --body "$(cat <<SUMMARY_EOF
          ## Code Review: $RECOMMENDATION

          | Severity | Count |
          |----------|-------|
          | Blockers | $BLOCKER_COUNT |
          | Warnings | $WARNING_COUNT |
          | Nits | $NIT_COUNT |

          $SUMMARY

          ---
          *Shipwright Code Review (Sonnet) — $FINDING_COUNT findings*
          SUMMARY_EOF
          )"

      - name: Resolve stale comments on re-review
        if: steps.pr-check.outputs.skip != 'true' && steps.diff.outputs.too_large != 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          PR_NUMBER="${{ steps.pr-check.outputs.pr_number }}"

          # Find previous Shipwright review comments that are now stale
          # A comment is stale if the file+line it references no longer appears in the current diff
          CURRENT_DIFF_FILES=$(cat /tmp/pr-diff.txt | grep '^diff --git' | sed 's|.*b/||' | sort -u)

          gh api "repos/${{ github.repository }}/pulls/$PR_NUMBER/comments" \
            --jq '.[] | select(.body | contains("Shipwright")) | {id: .id, path: .path}' | \
          while read -r comment; do
            COMMENT_ID=$(echo "$comment" | jq -r '.id')
            COMMENT_PATH=$(echo "$comment" | jq -r '.path')
            if ! echo "$CURRENT_DIFF_FILES" | grep -q "^${COMMENT_PATH}$"; then
              # File no longer in diff — resolve the comment by minimizing
              gh api \
                "repos/${{ github.repository }}/pulls/comments/$COMMENT_ID" \
                -X PATCH \
                -f body="$(gh api "repos/${{ github.repository }}/pulls/comments/$COMMENT_ID" --jq '.body')

          ---
          *Resolved: this file is no longer in the diff.*" || true
            fi
          done
```

**Step 3: Commit**

```bash
git add .github/workflows/code-review.yml
git commit -m "feat: add CI code review GitHub Action workflow"
```

---

### Task 6: Final validation

**Files:** None (validation only)

**Step 1: Run all smoke tests**

Run: `bash tests/smoke/run-all.sh`
Expected: PASS — all suites pass

**Step 2: Verify file structure**

Run: `ls -la skills/code-review/SKILL.md commands/shipwright-submit.md .github/workflows/code-review.yml`
Expected: All three files exist

**Step 3: Review the diff**

Run: `git diff main --stat`
Expected: Changes in:
- `skills/code-review/SKILL.md` (new)
- `commands/shipwright-submit.md` (new)
- `.github/workflows/code-review.yml` (new)
- `tests/smoke/validate-structure.sh` (modified)
- `tests/smoke/validate-skills.sh` (modified)
- `tests/smoke/validate-commands.sh` (modified)

**Step 4: Final commit (if any uncommitted changes remain)**

```bash
git status
# If clean, nothing to do. If any unstaged changes, review and commit.
```
