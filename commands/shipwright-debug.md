---
description: Systematic 4-phase debugging — root cause, pattern analysis, hypothesis testing, fix
argument-hint: [optional bug description]
---

You are running the Shipwright Debug command. This provides systematic debugging without the full orchestrated workflow.

## Behavior
- This is a standalone command -- no orchestrator, no recovery, no .workflow/ files
- No Triage, Reviewer, or Validator agents are involved
- The user drives the process directly

## Setup

Load these skills from the Shipwright plugin root before starting:
1. `skills/systematic-debugging.md` -- the core 4-phase debugging process
2. `skills/tdd.md` -- needed for Phase 4 (creating a failing test before fixing)

Read both files and internalize their rules. They are non-negotiable during this session.

## Getting the Bug Description

If `$ARGUMENTS` is provided, use it as the initial bug description and proceed directly to Phase 1.

If no arguments are provided, ask the user to describe the bug, error, or unexpected behavior they are seeing. Do not proceed until you have a clear description of the problem.

## The Four Phases

Follow the systematic-debugging skill strictly. Complete each phase before moving to the next.

### Phase 1: Root Cause Investigation
- Read error messages carefully and completely
- Reproduce the issue consistently
- Check recent changes (git diff, recent commits)
- Gather evidence at component boundaries if multi-component
- Trace data flow backward from the error to the source
- Do NOT propose any fix during this phase

### Phase 2: Pattern Analysis
- Find working examples of similar code in the codebase
- Compare working vs broken code
- Identify every difference, however small
- Understand dependencies and assumptions

### Phase 3: Hypothesis and Testing
- State a single, specific hypothesis: "I think X is the root cause because Y"
- Test with the smallest possible change
- One variable at a time
- If hypothesis is wrong, form a new one -- do not stack fixes
- If 3+ hypotheses fail, stop and discuss architecture with the user

### Phase 4: Implementation
- Write a failing test that reproduces the bug (use the TDD skill)
- Watch the test fail for the expected reason
- Implement a single fix targeting the root cause
- Verify the test passes and no other tests break
- If the fix does not work, return to Phase 1 with new information

## Rules
- Never skip phases. Never propose fixes before completing Phase 1.
- One fix at a time. No "while I'm here" changes.
- If you catch yourself guessing, stop and return to Phase 1.
- After 3 failed fix attempts, stop and question the architecture with the user.
