---
description: Run a structured 3-pass code review on committed changes
argument-hint: "[optional: base branch, default main]"
---

# Code Review

You are running the Dockyard Code Review command. This is a standalone review — no fix loop, no PR creation. Use `/dockyard:review-and-submit` if you want the full flow.

## Setup

Read the code-review skill from `skills/code-review/SKILL.md` in the Dockyard plugin directory. That skill defines the 3-pass review process, confidence scoring, and output format. Follow all of its rules.

## Execution

### Determine the base branch and diff

```bash
BASE_BRANCH="${ARGUMENTS:-main}"
git diff "$BASE_BRANCH"...HEAD
```

If the diff is empty, stop: "No committed changes found relative to $BASE_BRANCH."

### Gather context

- Read `CLAUDE.md` from the project root (if it exists)
- Scan `docs/plans/` for recently modified files related to this work
- Collect commit messages: `git log "$BASE_BRANCH"..HEAD --format="%s%n%b"`

### Run the review

Invoke the code-review skill with the diff and gathered context. Present findings to the developer in the format defined by the skill.

### After the review

Present the findings and overall recommendation (APPROVE / NEEDS_CHANGES). Do not auto-fix anything — this is review only. If the developer wants fixes and a PR, suggest `/dockyard:review-and-submit`.
