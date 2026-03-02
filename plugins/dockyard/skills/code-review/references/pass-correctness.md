# Pass 1: Correctness

Examine the diff for defects that affect runtime behavior.

## What to Look For

- **Bugs** — logic errors, off-by-one, null/undefined access, type mismatches, incorrect conditions
- **Edge cases** — boundary conditions, empty inputs, concurrent access, error propagation
- **Regressions** — does this change break existing behavior? Check callers of modified functions.
- **Error handling** — are errors caught, propagated, and reported correctly? Are resources cleaned up?
- **Security** — injection, authentication bypass, data exposure, unsafe deserialization (only if clearly introduced by this diff)

## Verification Process

For each potential issue:

1. Read the surrounding code (not just the diff lines) to understand the full context
2. Trace the data flow to verify the issue is real
3. Check if tests cover the problematic path
4. Only report if you can explain a concrete scenario where the bug manifests

If you cannot construct a concrete scenario, the issue is hypothetical — do not report it.
