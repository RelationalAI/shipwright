---
name: pair-review
description: Pair code review of GitHub pull requests — helps the user understand changes, explore code, ask questions, and submit a formal review. Use when the user provides a GitHub PR link, PR number, or branch name for review, pastes a PR URL, mentions reviewing or approving a pull request, or wants help understanding what a PR changes. This is for human-driven review with Claude as copilot, not autonomous code review.
---

# Pair Review

Help a human reviewer understand a pull request and submit a thoughtful review.
Claude is the knowledgeable guide — explaining what changed, why it matters, and
how it connects to the codebase. The human is the reviewer making the decisions.

## Phase 1: Setup

### Parse the PR reference

Accept any of:
- GitHub PR URL (`https://github.com/org/repo/pull/123`)
- PR number (`#123` or `123`)
- Branch name (`feature/my-branch`)

If only a number or branch name is given, infer the repository from the current
git remote.

### Check prerequisites

1. **`gh` CLI authenticated** — run `gh auth status`.
   If not: "GitHub CLI isn't authenticated. Run `gh auth login` to set up access, then try again."
   Stop here.

2. **Inside a git repository** — if not, ask the user to navigate to one.

### Get the code local

Check whether the current branch matches the PR's head branch.

**Already on the PR branch?** Use the current checkout. No worktree needed.

**On a different branch?** Create a worktree so the user's current work stays
undisturbed:

```bash
git fetch origin <head-branch>
git worktree add .pr-review/<number> FETCH_HEAD
```

Track whether a worktree was created — it gets cleaned up in Phase 5.

**Branch no longer exists?** (Common with merged PRs where the branch was
deleted.) Skip the local checkout — work from the PR data available via `gh`
instead. Let the reviewer know:

```
This PR is already merged and the branch has been deleted, so I can't check out
the code locally. I'll work from the diff and PR metadata — I can still answer
questions about the changes, but won't be able to navigate the codebase at the
exact state of the PR.
```

This is still useful for post-merge reviews or learning from past PRs.

## Phase 2: Overview

Gather context and present a concise orientation for the reviewer.

### Fetch PR data

```bash
# Metadata
gh pr view <number> --json title,body,author,state,isDraft,baseRefName,headRefName,additions,deletions,changedFiles,labels,reviewDecision

# Files changed with line counts
gh pr view <number> --json files --jq '.files[] | "\(.additions)+/\(.deletions)- \(.path)"'

# Existing reviews (human and automated)
gh pr view <number> --json reviews --jq '.reviews[] | {author: .author.login, state, body}'

# Inline review comments (captures automated review findings)
gh api repos/{owner}/{repo}/pulls/<number>/comments --jq '.[] | {user: .user.login, path, body: (.body[:200]), in_reply_to_id}'
```

### Present the summary

```
## PR #<number>: <title>
Author: <author> | <base> ← <head> | <Draft / Ready for review>
<N files changed>, +<additions> -<deletions>

### What this PR does
<2-4 sentence summary synthesized from PR description and diff>

### Files changed
<grouped list — source, tests, config, docs>

### Existing reviews
<summary of reviews already submitted>
<if automated review posted findings, list the key ones briefly>
```

### Load the diff

After presenting the summary, offer the reviewer a choice for how to explore
the changes:

```
How would you like to go through the changes?
1. Full diff — load everything at once (best for smaller PRs)
2. Grouped walkthrough — I'll group files by concern and we go group by group
3. File by file — you pick individual files to look at
```

**Option 1 — Full diff:** Load everything at once with `gh pr diff <number>`.
Good for small-to-medium PRs where having the complete picture enables faster
answers.

**Option 2 — Grouped walkthrough:** Group the changed files by logical concern
based on the PR description, file paths, and what the changes do (e.g., "API
changes", "test additions", "config updates"). Present the groups, then walk
through one group at a time — loading that group's diffs together. This is the
sweet spot for larger PRs: manageable chunks without the tedium of going one
file at a time.

**Option 3 — File by file:** The reviewer picks individual files to examine.
Rarely needed, but useful when the reviewer already knows exactly which files
they care about.

If the reviewer doesn't express a preference, default to the full diff for PRs
under ~300 lines of changes, and suggest the grouped walkthrough for larger ones.

Regardless of which option is chosen, the full codebase is always available for
context — Claude reads any file on demand when the reviewer asks how something
connects to the rest of the system.

## Phase 3: Interactive Review

Transition to Q&A with the reviewer:

```
I've loaded the full diff and codebase context. Ask me anything — or here are
some starting points:
<review focus areas from code-review skill>

When you're ready to write your review, just say so.
```

### Generating focus area suggestions

Read the code-review skill's SKILL.md (search for `skills/code-review/SKILL.md`
in the project) and extract the current review passes from its "Review Passes"
table. Present each pass as a natural question the reviewer might want to explore.

This keeps pair-review's suggestions in sync as code-review's passes evolve. Do
not hardcode the pass names — always read them fresh.

### How to handle questions

**Explain, don't judge.** When asked about code, explain what it does, why it
might be done that way, and what alternatives exist. The human forms opinions;
Claude provides understanding.

**Use the full codebase.** The real value is connecting the diff to the broader
system. Navigate beyond changed files — read callers, trace data flow, check
type definitions, find related patterns.

**Reference automated review findings.** If the user asks about something the
automated review already flagged, surface that. Don't make the reviewer
rediscover what's already been found.

**Follow the reviewer's lead.** If they want a deep dive into correctness of a
specific function, do it thoroughly. If they want a high-level architectural
assessment, provide that. The "Claude isn't the reviewer" principle means don't
dump an unsolicited full review — but absolutely provide rigorous analysis when
asked.

**Stay conversational.** Answer what was asked, then wait. Don't preemptively
dump everything you noticed.

### Draft PRs vs Ready PRs

Draft PRs may not have automated reviews yet. The reviewer might want more
Claude analysis than usual — be ready to take on more of the analytical load if
asked. Ready-for-review PRs should already have been through automated review,
so lean on those findings rather than duplicating the work.

## Phase 4: Submit Review

When the reviewer signals they're done exploring (or you sense they've covered
their concerns), transition to composing the review.

### Gather intent

Ask the reviewer:

1. **Verdict** — Approve, request changes, or comment only?
2. **Key points** — What matters most? Or would they like Claude to draft based
   on the conversation?

### Draft the review

Compose a review body that:
- Reflects the **reviewer's** assessment, not Claude's
- Includes specific feedback points that came up in conversation
- Is proportional to the PR — a small change gets a brief review
- Stays professional and constructive

Present the draft for approval:

```
Here's the draft review:

---
**<Approve / Request Changes / Comment>**

<review body>
---

Want me to adjust the wording, add or remove points, or change the status?
```

### Submit

Once the reviewer approves the draft:

```bash
gh pr review <number> --<approve|request-changes|comment> --body "<review body>"
```

Confirm the submission and show the PR URL.

## Phase 5: Cleanup

If a worktree was created during setup:

```
Review submitted! I created a worktree at <path> for this review.
Want me to clean it up?
```

If yes:
```bash
git worktree remove <path>
```

## Principles

- **The human is the reviewer.** Claude makes them faster and more thorough, but
  doesn't replace their judgment.
- **Speed is the point.** Concise summaries, direct answers, no ceremony. The
  goal is faster PR approvals.
- **Automated review is the first pass.** Don't duplicate it. Build on it.
- **Context is the value.** Connecting the diff to the broader codebase is what
  Claude does that a raw diff view can't.
