# Pass 3: Test Quality

Evaluate whether tests accompanying the diff are adequate.

## What to Look For

- **Testing the right thing** — do tests exercise the behavior introduced or changed by the diff? A test that passes before AND after the change tests nothing relevant.
- **Determinism** — are tests deterministic? Flag: time-dependent assertions, random data without seeds, filesystem ordering assumptions, uncontrolled external dependencies. Prefer test doubles, contract tests, or deterministic test servers over mocks for controlling external behavior.
- **Speed** — are tests unnecessarily slow? Flag: sleep/delay in tests, unnecessarily heavy test infrastructure, testing large datasets when small ones prove the same thing. Prefer lightweight real implementations (in-memory databases, local test servers) over mocks for managing test speed.
- **Behavior over implementation** — do tests assert on observable behavior (output, side effects, state changes) or on implementation details (internal method calls, private state, execution order)?
- **Mocking discipline** — never mock what you can use for real. Flag tests that mock internal modules, classes, or functions when the real implementation could be used. Acceptable mock targets: external services behind a network boundary, system clocks, hardware interfaces. If a dependency is hard to use in tests without mocking, that's a design smell in the dependency, not a reason to mock.
- **Coverage of the changes** — are the meaningful code paths introduced by the diff exercised by tests? Are edge cases from the correctness pass covered?

## Important Scope Limitation

Only evaluate tests that are part of the diff or directly related to changed code. Do not flag pre-existing test quality issues.
