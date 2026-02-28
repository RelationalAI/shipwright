---
name: review-and-submit
description: Review code, auto-fix findings, generate PR description, and create a draft PR. Use when done coding and ready to submit.
---

# Submit

You are running the Shipwright Submit flow. This is the local developer flow from "done coding" to "draft PR ready."

**Review always runs.** There is no flag to skip it. After seeing results, the developer can choose to proceed past blockers, but the review itself is mandatory.

## Prerequisites

Before starting, verify:

1. You are on a feature branch (not `main` or `master`). If on main/master, stop and tell the developer: "You are on the main branch. Create a feature branch first."
2. There are committed changes on this branch relative to the base branch. If no changes, stop: "No changes to submit. Commit your changes first."
3. `gh` CLI is available and authenticated. Run `gh auth status` to check. If not authenticated, stop: "GitHub CLI is not authenticated. Run `gh auth login` first."

If any prerequisite fails, inform the developer with the specific message and stop.

### Uncommitted changes

After prerequisites pass, check for uncommitted changes (`git status`). If there are staged or unstaged changes, prompt the developer:

```
You have uncommitted changes:
<list changed files>

Would you like to commit these before proceeding? The code review only covers committed changes.
```

Wait for the developer's response. If they choose to commit, create the commit (ask for a message or suggest one), then proceed. If they decline, proceed with the review on committed changes only — but remind them the uncommitted work won't be reviewed.

## Step 1: Gather Context

### Determine the base branch and diff

```bash
# Detect the default branch
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")

# Get the diff of committed changes
git diff "$BASE_BRANCH"...HEAD
```

If the diff is empty, stop: "No committed changes found relative to $BASE_BRANCH. Commit your changes first."

### Collect rationale context

Search for context that explains the intent behind the changes. This is optional — it helps generate better PR descriptions but is not required for review.

- **Plan files** — scan `docs/plans/` for recently modified files related to this work
- **Commit messages** — `git log "$BASE_BRANCH"..HEAD --format="%s%n%b"` for the progression of changes

## Step 2: Run Code Review

You are the orchestrator described in the `shipwright:code-review` skill. Read its `SKILL.md` and `references/orchestration.md`, then execute the protocol directly — you spawn the review pass sub-agents, collect findings, and spawn the scorer.

**Provide to each review pass sub-agent:**
- The diff from Step 1
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

**Only runs if findings were reported.** If the review is APPROVE with no findings, skip to Step 4.

### Prompt developer for selection

Present all findings with numbered selection:

```
Which findings should I auto-fix? (comma-separated numbers, "all", or "none")

  [1] blocker  src/auth.ts:42    Missing null check on user lookup
  [2] blocker  src/auth.ts:87    Token expiry not validated
  [3] warning  src/api.ts:15     Error response missing status code
  [4] nit      src/api.ts:30     Inconsistent naming: userID vs userId
```

**STOP HERE.** You MUST use AskUserQuestion (or equivalent interactive prompt) to
collect the developer's selection before proceeding. Do NOT infer intent from prior
messages. Do NOT proceed without an explicit answer to this specific question.
Silence or prior broad instructions like "do everything" do not count as selection.

### Fix selected findings

**You MUST use the Task tool to spawn a single sub-agent to apply all selected fixes.** Do NOT edit files
directly in the main context. This is not optional — even for "simple" one-line fixes.

Input to the sub-agent:
- All selected findings (file, line range, description, suggested fix)
- Instruction to run tests after applying all fixes

**Why a single sub-agent:** Multiple sub-agents risk edit collisions on shared files,
and each fix may affect others. A single agent applies fixes sequentially, resolving
dependencies naturally, and runs tests once at the end.

**Why this is mandatory:** Fixing inline pollutes the main context with file reads,
edits, and test retries. This compounds across findings and degrades quality of
subsequent steps (PR description, re-review).

### Re-review

After the fix sub-agent completes:

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
## Why
<rationale — the problem being solved, decisions that led here>

## What
<concise summary of what changed — proportional to diff size>

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
