# Decision Categorization

## Purpose

During triage, the developer and agent brainstorm how to approach a fix. This skill
categorizes the decisions from that conversation so the Implementer knows what is
locked, what is deferred, and where it has latitude. The output is a decisions
section in `.workflow/CONTEXT.md` that downstream agents can read without asking
the developer again.

---

## Decision Categories

Every decision from the brainstorm falls into one of three categories.

### LOCKED -- developer made an explicit choice; do not change without asking

Use LOCKED when the developer:
- Chose a specific approach ("use the existing retry logic, don't write new")
- Ruled something out ("don't touch the auth module")
- Set a constraint ("must stay backward-compatible with v2 API")
- Named a specific file, function, or pattern to use or avoid

### DEFERRED -- explicitly punted for later; do not revisit now

Use DEFERRED when the developer:
- Said "not now" or "we'll handle that separately"
- Identified a related problem but chose not to address it in this fix
- Acknowledged tech debt but scoped it out

Capture deferred items so they are not lost, but do not act on them.

### DISCRETION -- agent can decide; use best judgment

Use DISCRETION when the developer:
- Said "you decide" or "whatever makes sense"
- Did not express a preference after being asked
- The decision is purely technical (algorithm choice, variable naming, etc.)

DISCRETION does not mean "skip thinking." The agent should still make a
deliberate choice and be ready to explain it if challenged during review.

---

## Identifying Gray Areas

Before recording decisions, identify areas where multiple reasonable approaches
exist and the developer's preference matters. Good gray areas for a bug fix:
- **Fix scope** -- minimal patch vs. broader cleanup of the affected area
- **Test strategy** -- what to cover, edge cases, integration vs. unit
- **Backward compatibility** -- can the fix change observable behavior?
- **Related issues** -- nearby code smells or bugs spotted during investigation
- **Rollback risk** -- does this fix need a feature flag or safe deployment?

Generate 2-4 gray areas specific to the bug at hand. Do not use generic checklists.

---

## Scope Guardrail

The fix boundary is FIXED. Discussion clarifies HOW to implement the fix, not
WHETHER to add more scope.

If the developer suggests something beyond the bug fix:
1. Acknowledge it: "That sounds like a separate piece of work."
2. Capture it under DEFERRED with a one-line description.
3. Return to the fix.

Do not lose deferred ideas. Do not act on them.

---

## Recording Decisions in CONTEXT.md

Write decisions into `.workflow/CONTEXT.md` under a `## Decisions` section.
Each decision is a single line with its category tag.

```markdown
## Decisions

### Fix Approach
- [LOCKED] Patch the null check in `UserService.getDetails()`, do not refactor the caller chain
- [LOCKED] Keep backward compatibility with existing API consumers

### Test Strategy
- [LOCKED] Add regression test reproducing the null pointer from ticket RAI-9874
- [DISCRETION] Additional edge case coverage for the getDetails path

### Related Issues
- [DEFERRED] `UserService.getList()` has a similar unchecked null -- separate ticket
- [DEFERRED] Error logging in this module is inconsistent -- tech debt backlog

### Implementation Details
- [DISCRETION] Choice of assertion style in tests
- [DISCRETION] Whether to extract a helper method for the null guard
```

### Rules for Good Decisions

- **Concrete** -- "Patch the null check in UserService.getDetails()", not "Fix the service layer"
- **Categorized** -- every decision has exactly one tag, no ambiguity
- **Complete** -- if it was discussed, it is recorded; if not discussed and non-obvious,
  ask before defaulting to DISCRETION

---

## How It Fits in the Workflow

The Triage agent uses this skill after brainstorming with the developer:

1. Triage identifies gray areas based on the bug and codebase context.
2. Triage presents gray areas and asks which the developer wants to discuss.
3. For each selected area, Triage asks focused questions until satisfied.
4. Triage categorizes all decisions and writes them to `.workflow/CONTEXT.md`.

Downstream agents then consume these decisions:
- **Implementer**: Follows LOCKED exactly. Uses judgment on DISCRETION. Ignores DEFERRED.
- **Reviewer**: Checks LOCKED was followed. Flags questionable DISCRETION choices.
  Confirms nothing DEFERRED leaked in.
- **Validator**: Confirms the fix matches the recorded scope. No more, no less.
