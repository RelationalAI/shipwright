---
name: review-and-submit
description: Review code, auto-fix findings, generate PR description, and create a draft PR. Use when done coding and ready to submit.
---

# Submit

Local developer flow from "done coding" to "draft PR ready."

This skill runs late in a session when context is already full. Every design choice
prioritizes context efficiency — heavy work happens in sub-agents so the main context
stays focused on developer interaction and decision-making.

## Prerequisites

Check all three. If any fails, tell the developer the specific issue and stop.

1. **Feature branch** — not `main` or `master`. If on main: "Create a feature branch first."
2. **Committed changes** relative to base branch. If none: "Commit your changes first."
3. **`gh` CLI authenticated** — run `gh auth status`. If not: "Run `gh auth login` first."

### Uncommitted changes

After prerequisites pass, check `git status`. If there are uncommitted changes:

```
You have uncommitted changes:
<list changed files>

Commit these before proceeding? The review only covers committed changes.
```

Wait for response. If they commit, proceed. If not, continue but note uncommitted work won't be reviewed.

## Step 1: Gather Context

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
git diff "$BASE_BRANCH"...HEAD
git log "$BASE_BRANCH"..HEAD --format="%s%n%b"
```

If the diff is empty, stop: "No committed changes found relative to $BASE_BRANCH."

## Step 2: Code Review

Spawn a **single Task sub-agent** to run the entire code review. This is the most
context-intensive part of the flow, and it must happen outside the main context.

The sub-agent acts as the orchestrator described in `shipwright:code-review`. It reads
the code-review skill's `SKILL.md` and `references/orchestration.md`, then executes the
full protocol: spawning review passes, collecting findings, and scoring them.

**Sub-agent prompt template:**

```
You are a code review orchestrator. Read the code-review skill at
skills/code-review/SKILL.md (relative to the project root), then read its
references/orchestration.md and execute the full review protocol: spawn the
three review passes (correctness, conventions, test quality) as nested
sub-agents, collect findings, and spawn the scorer.

Diff to review:
<the diff from Step 1>

Rationale context:
<commit messages from Step 1>

After completing the review, respond with the results in this format:

RECOMMENDATION: [APPROVE or NEEDS_CHANGES]

FINDINGS:
[N] [severity] [file:line] description (confidence: XX)
    Fix: suggested fix text

SUMMARY:
[2-4 sentence summary]
```

**Why one sub-agent wrapping the whole review:** The review protocol reads 6 reference
files and spawns 4 inner sub-agents. Orchestrating this from the main context would
load all those files and results into the already-full context window. A single outer
sub-agent encapsulates that work and returns only the compact findings summary.

**Model:** Opus for the review sub-agent (it controls its own inner agents).

Present the findings to the developer exactly as returned.

## Step 3: Fix Loop

**Skip entirely if review is APPROVE with no findings.** Jump to Step 4.

Present all findings with numbered selection using AskUserQuestion:

```
Which findings should I fix? (comma-separated numbers, "all", or "none")

  [1] blocker  src/auth.ts:42    Missing null check on user lookup
  [2] warning  src/api.ts:15     Error response missing status code
  ...
```

**Wait for explicit developer selection.** Do not infer from prior messages or
broad instructions like "fix everything."

If developer selects "none", skip to Step 4.

### Apply fixes

Spawn a **single Task sub-agent** to apply all selected fixes:

```
Apply these fixes to the codebase:
<list selected findings with file, line range, description, suggested fix>

After applying all fixes:
1. Run the project's tests (look for test scripts in package.json, Makefile, or similar)
2. Commit the fixes with a descriptive message
3. Report: what you changed, whether tests pass, and any issues encountered
```

One sub-agent, not one per fix — fixes may interact (same file, adjacent lines).

### After fixes

Present the fix sub-agent's report:

```
Fixes applied and committed. [summary from fix sub-agent]

Options:
1. Proceed to PR creation (remaining findings noted in description)
2. Re-run code review on the updated diff
3. Fix more manually and start over
```

Wait for the developer to choose.

If the developer chooses option 2, get the updated diff (`git diff "$BASE_BRANCH"...HEAD`)
and repeat Step 2 with the new diff. This costs another sub-agent round-trip but gives
confidence that fixes didn't introduce new issues. **One re-review only** — if the
developer wants another after that, they should start over.

## Step 4: Generate PR Description

Synthesize from: diff analysis, commit messages, and review results.

```markdown
## Why
<the problem being solved, decisions that led here>

## What
<concise summary — proportional to diff size>

## How to review
<focus areas, ordered by importance>

## Pre-submit review
<what local review caught and fixed, remaining warnings/nits>
```

**Rules:**
- Proportional to change size — 10-line diff gets 2-3 sentences
- Never longer than the diff itself
- WHY over WHAT (the diff shows what)
- Specific review focus areas

## Step 5: Create Draft PR

```bash
git push -u origin HEAD
gh pr create --draft --title "<concise title>" --body "<description from Step 4>"
```

Present the PR URL. Remind: review the description on GitHub, then mark "Ready for Review."

## Rules

1. **Review always runs.** No skip flag.
2. **Developer chooses what to fix.** Never auto-fix without explicit selection.
3. **One fix cycle, one optional re-review.** Fix once, optionally re-review once, then hand back.
4. **Sub-agents for heavy work.** Review and fixes happen in sub-agents, not main context.
5. **Draft PR default.** Author reviews before marking ready.
6. **Description proportional to diff.** Small change = brief description.
7. **Never force-push.** Always `git push`, never `git push --force`.
