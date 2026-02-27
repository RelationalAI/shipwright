---
description: Review code, auto-fix findings, generate PR description, and create a draft PR
argument-hint: "[optional: base branch, default main]"
---

# Review and Submit

You are running the Dockyard Review and Submit command. This is the local developer flow from "done coding" to "draft PR ready."

## Setup

Read the review-and-submit skill from `skills/review-and-submit/SKILL.md` in the Dockyard plugin directory. That skill defines the full 5-step flow: gather context, run code review, fix loop, generate PR description, and create draft PR. Follow all of its rules.

## Execution

Follow the skill exactly. There are no overrides or shortcuts.

### Base branch

If `$ARGUMENTS` is provided, treat it as the base branch name (e.g., "develop", "release/v2"). Otherwise default to "main".
