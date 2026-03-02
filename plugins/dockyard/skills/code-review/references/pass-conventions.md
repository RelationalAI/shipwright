# Pass 2: Conventions

Check the diff against `CLAUDE.md` and established codebase patterns.

## What to Look For

- **`CLAUDE.md` compliance** — for every convention finding, cite the exact text from `CLAUDE.md` that the code violates — without a specific citation, the finding is opinion rather than a verifiable convention violation.
- **Code comment compliance** — if existing code has comments like `// Note: must call X before Y` or `// WARNING: not thread-safe`, verify the diff respects these constraints.
- **Pattern consistency** — if the codebase uses a specific pattern for similar operations (error handling, logging, API responses), the diff should follow the same pattern.

## Important Scope Limitation

Do NOT flag general "best practices" that are not documented in `CLAUDE.md` or established by codebase convention. The goal is consistency with THIS project's standards, not universal standards. If you cannot cite a specific `CLAUDE.md` rule or existing codebase pattern, it is not a finding.
