---
description: File bugs, feedback, and suggestions on Shipwright
argument-hint: [optional description]
---

You are running the Shipwright Report command. Your job is to help the user file an issue on the Shipwright repository.

## Rules
- This is a standalone command -- no orchestrator, no recovery, no .workflow/ files
- The target repo is always `RelationalAI/shipwright`
- Valid issue labels: `bug`, `feature`, `suggestion`, `feedback`
- Always confirm details with the user before creating the issue
- Use `gh issue create` to file the issue

## Mode 1: No arguments provided

If `$ARGUMENTS` is empty:

1. Ask the user to pick an issue type:
   - **bug** -- something is broken
   - **feature** -- a new capability request
   - **suggestion** -- an improvement to something that already works
   - **feedback** -- general feedback about the project
2. Ask for a short title (one line)
3. Ask for a description (can be multiple lines, or "none" to skip)
4. Show the assembled issue for confirmation:
   - Type (label)
   - Title
   - Body
5. On confirmation, create the issue (see "Creating the issue" below)

## Mode 2: Freeform text provided

If `$ARGUMENTS` contains text (e.g., `/shipwright:report clicking more details throws null pointer`):

1. Read the freeform text and auto-detect the most likely issue type:
   - Text mentioning errors, crashes, broken behavior, exceptions -> `bug`
   - Text requesting new functionality or capabilities -> `feature`
   - Text proposing improvements to existing behavior -> `suggestion`
   - General comments or opinions -> `feedback`
2. Draft a title from the text (clean it up, capitalize properly, keep it concise)
3. Use the original text as the issue body, adding any structure that helps (e.g., "Steps to reproduce" for bugs)
4. Show the assembled issue and your detected type to the user for confirmation
5. Let the user correct the type, title, or body before proceeding
6. On confirmation, create the issue (see "Creating the issue" below)

## Creating the issue

Run the following command:

```
gh issue create --repo RelationalAI/shipwright --title "<title>" --body "<body>" --label <type>
```

Where `<type>` is one of: `bug`, `feature`, `suggestion`, `feedback`.

After creation, show the user the issue URL returned by `gh`.

## Error handling

- If `gh` is not authenticated or the command fails, show the error and suggest the user run `gh auth login` first.
- If the repo is not accessible, say so clearly -- do not retry silently.
