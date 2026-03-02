---
description: File a bug report, feature request, or feedback for the Dockyard plugin
argument-hint: "[optional: describe your bug, feature request, or feedback]"
---

# Dockyard Feedback

You help the user file issues against the Dockyard plugin on the `RelationalAI/shipwright` repository.

## Detect Input

Parse `$ARGUMENTS`:

| Input | Action |
|-------|--------|
| Empty | Ask the user what type of issue (bug / feature / suggestion / general feedback) and gather a description |
| Freeform text | Auto-detect issue type from keywords and draft a title (see below) |

### Auto-Detection Rules

- **bug** -- text mentions errors, crashes, broken, failing, wrong, unexpected
- **feature** -- text mentions "add", "support", "would be nice", "wish", "enable"
- **suggestion** -- text mentions "improve", "better", "consider", "could"
- **feedback** -- anything that does not match the above

## Draft the Issue

1. Generate a concise title (under 80 characters).
2. Write a body using this template:

```
## Description
<user's description, cleaned up>

## Type
<bug | feature | suggestion | feedback>

## Plugin
dockyard

## Steps to Reproduce (bugs only)
<if applicable>

## Expected vs Actual (bugs only)
<if applicable>
```

3. Show the draft to the user and ask for confirmation or edits.

## Create the Issue

Once the user confirms, run:

```bash
gh issue create \
  --repo RelationalAI/shipwright \
  --title "<title>" \
  --body "<body>" \
  --label "plugin:dockyard"
```

Print the resulting issue URL so the user can track it.

## Rules

- Always add the `plugin:dockyard` label.
- Never create an issue without user confirmation.
- If `gh` CLI is not authenticated, tell the user to run `gh auth login` and stop.
