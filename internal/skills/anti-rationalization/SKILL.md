# Anti-Rationalization

## Overview

Rationalization is the process of constructing a plausible justification for a decision you have already made. In code review and validation, rationalization means approving work without sufficient evidence that it is correct.

**Core principle:** Evidence before claims, always. If you cannot point to concrete proof, you are rationalizing.

## What Rationalization Looks Like

Rationalization rarely announces itself. It sounds reasonable. It feels pragmatic. It uses words like "obviously", "clearly", "should be fine", and "looks good". The hallmark of rationalization is a conclusion that arrives before the evidence.

Common shapes:

- **The shortcut.** "I checked the main logic, the rest follows."
- **The appeal to aesthetics.** "The code is clean, so it probably works."
- **The social pass.** "This developer is experienced, no need to dig deep."
- **The test proxy.** "Tests pass, so the implementation must be correct."
- **The fatigue excuse.** "I have reviewed enough today, this one looks fine."
- **The scope dodge.** "That edge case is out of scope for this review."

## Red Flags -- STOP Immediately

If you catch yourself thinking any of these, stop and re-examine:

| Red Flag | What It Really Means |
|----------|---------------------|
| "Looks good to me" (without specific evidence) | You have not actually verified anything. |
| "Tests pass so it is fine" | Passing tests prove tests pass, not that the change is correct. |
| "The code is clean / well-structured" | Style is not correctness. Clean code can have wrong logic. |
| "I checked the important parts" | You decided what was important before understanding the change. |
| "This is a small change, low risk" | Small changes cause production incidents. Size is not safety. |
| "The author is senior / trustworthy" | Trust is not evidence. Everyone makes mistakes. |
| "I would have written it the same way" | Agreement is not verification. |
| "Just this once, skip the deep review" | There is no "just this once." Every skip compounds. |
| "We are behind schedule, approve and move on" | Time pressure is the leading cause of escaped defects. |
| "The description says it was tested manually" | Self-reported testing is not independent verification. |
| "Previous reviewers approved it" | Approval count is not evidence quality. |
| "It compiled / linted cleanly" | Compilation checks syntax, not semantics. |

## The Self-Check: "Am I Rationalizing?"

When you are about to approve, pass, or sign off on anything, ask yourself these four questions:

1. **What specific evidence do I have?**
   Not "it looks right" -- what concrete output, test result, or trace did I examine?

2. **Could I explain my reasoning to a skeptic?**
   If your justification would not survive a "why?" from someone unfamiliar with the change, it is not solid.

3. **Did my conclusion arrive before my analysis?**
   If you felt "this is fine" before finishing your review, your analysis was confirmation, not investigation.

4. **Am I choosing comfort over rigor?**
   Approving is easier than questioning. If the easy path and your conclusion align, double-check.

If any answer is unsatisfying, you are rationalizing. Go back and do the work.

## Common Excuses and Their Rebuttals

| Excuse | Rebuttal |
|--------|----------|
| "I am confident this is correct" | Confidence is a feeling, not evidence. Run the verification. |
| "Tests pass, what more do you want?" | Tests verify what they test. Do they cover this specific change? Every edge case? |
| "The diff is trivial" | Trivial diffs have caused major outages. Verify the trivial. |
| "I already spent a lot of time reviewing" | Time spent is not rigor achieved. Did you verify the claims? |
| "Partial verification is good enough" | Partial verification proves partial correctness at best. |
| "It works on my machine / in CI" | One environment is not all environments. Check the scope of verification. |
| "The PR description explains everything" | Descriptions are claims, not evidence. Verify the claims independently. |
| "Nobody else flagged this" | Absence of objection is not presence of correctness. |
| "We can fix it in a follow-up" | Follow-ups get deprioritized. Fix it now or document the known risk explicitly. |
| "I have seen this pattern before, it is safe" | Familiarity breeds assumptions. Verify this specific instance. |

## The Evidence-Before-Claims Principle

Never state a conclusion without pointing to the evidence that supports it.

**Wrong:** "This change handles the error case correctly."
**Right:** "The test at line 47 exercises the timeout path, and the catch block at line 112 returns the expected error structure. Verified by reading both."

**Wrong:** "LGTM."
**Right:** "Verified: new validation logic rejects empty input (test on line 23 confirms), accepts valid input (test on line 31), and the error message matches the spec in the ticket."

If you cannot write the "right" version, you have not done enough review to approve.

## For Reviewers

Your job is to find problems, not to confirm the author's work. Approach every review as if the change contains a defect and your task is to find it. If you find nothing, that is a good outcome -- but only after genuine investigation.

- Read the diff line by line. Do not skim.
- Check that tests exercise the changed behavior, not just adjacent behavior.
- Verify error paths and edge cases, not just the happy path.
- If something is unclear, ask. Unclear code is a defect.

## For Validators

Your job is to confirm that acceptance criteria are met with evidence. "Tests pass" is the starting point, not the finish line.

- Run verification commands yourself. Do not trust reports.
- Compare actual output against expected output explicitly.
- Check that every requirement in the acceptance criteria has a corresponding verified result.
- If a criterion cannot be verified, escalate. Do not assume it is met.

## The Bottom Line

The moment you feel certain without evidence, that is the moment to be most suspicious of yourself. Rationalization is easiest when you are tired, pressured, or trusting. Those are exactly the conditions that produce defects.

Run the check. Read the output. Trace the logic. Then -- and only then -- state your conclusion.
