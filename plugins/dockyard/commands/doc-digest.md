---
description: Walk through any document section by section for interactive review
argument-hint: <doc-path>
---

You are running the Dockyard Doc Digest command. Spawn the Doc Digest agent to walk the user through the document at `$ARGUMENTS`.

## Behavior
- This is a standalone command -- no orchestrator, no recovery, no .workflow/ files
- Load the Doc Digest agent prompt from `agents/doc-digest.md` (relative to the Dockyard plugin root)
- Pass `$ARGUMENTS` as the document path
- The agent handles everything from there: reading the document, splitting into sections, presenting them one at a time, collecting feedback, and producing a final summary

## If no arguments provided
Ask the user for the document path. Do not proceed until you have a valid path to a file that exists.
