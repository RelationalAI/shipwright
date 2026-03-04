---
description: Run a structured 3-pass code review on committed changes
argument-hint: "[optional: base branch, default main]"
---

# Code Review

You are running the Dockyard Code Review command. This is a standalone review — no fix loop, no PR creation. Use `/dockyard:review-and-submit` if you want the full flow.

## Setup

Invoke the `dockyard:code-review` skill using the Skill tool. That skill defines the 3-pass review process, confidence scoring, and output format. Follow all of its rules.

## Execution

### Determine the base branch

```bash
BASE_BRANCH="${ARGUMENTS:-main}"
git diff --stat "$BASE_BRANCH"...HEAD
```

If the diff stat is empty, stop: "No committed changes found relative to $BASE_BRANCH."

Do NOT read the full diff here — that happens inside the sub-agents.

### Gather context (lightweight)

- Read `CLAUDE.md` from the project root (if it exists)
- Collect commit messages: `git log "$BASE_BRANCH"..HEAD --format="%s%n%b"`

### Run the review

Follow the skill's Orchestration section exactly. Spawn exactly **three** parallel sub-agents — one per review pass (correctness, conventions, test quality). Do not split by file or change area.

Each sub-agent runs `git diff "$BASE_BRANCH"...HEAD` itself to get the full diff. This keeps the full diff out of the main context.

After all three return, spawn one scorer sub-agent to filter findings by confidence.

Present findings to the developer in the format defined by the skill.

### After the review

Present the findings and overall recommendation (APPROVE / NEEDS_CHANGES). Do not auto-fix anything — this is review only. If the developer wants fixes and a PR, suggest `/dockyard:review-and-submit`.
