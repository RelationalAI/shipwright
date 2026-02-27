# Pass 3: Test Quality

Evaluate whether tests accompanying the diff are adequate.

## What to Look For

- **Testing the right thing** — do tests exercise the behavior introduced or changed by the diff? A test that passes before AND after the change tests nothing relevant.
- **Determinism** — are tests deterministic? Flag: time-dependent assertions, random data without seeds, filesystem ordering assumptions, network calls without mocks.
- **Speed** — are tests unnecessarily slow? Flag: sleep/delay in tests, spinning up real servers when mocks suffice, testing large datasets when small ones prove the same thing.
- **Behavior over implementation** — do tests assert on observable behavior (output, side effects, state changes) or on implementation details (internal method calls, private state, execution order)?
- **Coverage of the changes** — are the meaningful code paths introduced by the diff exercised by tests? Are edge cases from the correctness pass covered?

## Important Scope Limitation

Only evaluate tests that are part of the diff or directly related to changed code. Do not flag pre-existing test quality issues.
